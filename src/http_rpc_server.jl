
function make_vargs(vargs)
    arr = Tuple[]
    for (n,v) in vargs
        push!(arr, (Symbol(n),v))
    end
    arr
end

function isvalidcmd(cmd)
    isempty(cmd) && return false
    ((cmd[1] == ':') || Base.is_id_start_char(cmd[1])) || return false
    for c in cmd
        Base.is_id_char(c) || return false
    end
    true
end

function parsepostdata(req, query)
    post_data = ""
    req_body = getfield(req, :body)

    if !isempty(req_body)
        idx = findfirst(isequal(UInt8('\0'), req_body))
        idx = (idx == nothing) ? lastindex(req_body) : (idx - 1)
        post_data = (idx == 0) ? String(req_body) : String(req_body[1:(idx-1)])
    end

    ('=' in post_data) || (return query)
    merge(query, HTTP.queryparams(post_data))
end

"""
Handles multipart form data.
Transfers all content as String.
Binary files can be uplaoded by encoding them with base64 first.
"""
const LFLF = UInt8['\n', '\n']
const CRLFCRLF = UInt8['\r', '\n', '\r', '\n']
function searcharr(haystack, needle, startpos)
    @static if VERSION < v"0.7.0-"
        search(haystack, needle, startpos)
    else
        Lh = length(haystack)
        Ln = length(needle)
        if Lh > Ln
            for idx in startpos:(Lh-Ln+1)
                r = idx:(idx+Ln-1)
                (view(haystack, r) == needle) && (return r)
            end
        end
        0:-1
    end
end
function parsepostdata(req, data_dict, multipart_boundary)
    data = getfield(req, :body)
    boundary_end = "--" * multipart_boundary * "--"
    boundary = "--" * multipart_boundary * "\r\n"
    Lbound = length(boundary)
    Ldata = length(data)

    boundbytes = convert(Vector{UInt8}, codeunits(boundary))
    boundbytes_end = convert(Vector{UInt8}, codeunits(boundary_end))

    boundloc = searcharr(data, boundbytes, 1)
    endpos = startpos = last(boundloc) + 1
    parts = Vector{Vector{UInt8}}()
    isend = false

    while !isend && ((startpos + Lbound) < Ldata)
        boundloc = searcharr(data, boundbytes, startpos)
        if isempty(boundloc)
            boundloc = searcharr(data, boundbytes_end, startpos)
            isend = true
        end
        if !isempty(boundloc)
            endpos = first(boundloc) - 3 # skip \r\n too

            part = data[startpos:endpos]
            push!(parts, part)

            startpos = last(boundloc) + 1
        end
    end

    for part in parts
        hdrloc1 = searcharr(part, LFLF, 1)
        hdrloc2 = searcharr(part, CRLFCRLF, 1)

        if length(hdrloc1) == 0
            hdrloc = hdrloc2
        elseif length(hdrloc2) == 0
            hdrloc = hdrloc1
        else
            hdrloc = (first(hdrloc1) < first(hdrloc2)) ? hdrloc1 : hdrloc2
        end

        parthdr = String(part[1:(first(hdrloc)-1)])
        partdata = part[(last(hdrloc)+1):end]

        collect_part_data(data_dict, parthdr, partdata)
    end
    data_dict
end

function collect_part_data(data_dict, parthdr, partdata)
    hdrdict = parse_part_headers(parthdr)

    # convert all to base64 for now
    #content_type = header(hdrdict, "Content-Type", "application/octet-stream")
    #istext = startswith(content_type, "text")

    content_disposition = header(hdrdict, "Content-Disposition")
    (isempty(content_disposition) || !startswith(content_disposition, "form-data;")) && return
    for attr in split(content_disposition, ';')
        ('=' in attr) || continue
        attr = strip(attr)
        (n,v) = split(attr, '='; limit=2)
        if n == "name"
            startswith(v, '"') && endswith(v, '"') && (v = v[2:(end-1)])
            data_dict[v] = base64encode(partdata)
        end
    end
end

function parse_part_headers(parthdr)
    hdrdict = Dict{String,String}()
    for hdr in split(parthdr, "\n")
        (':' in hdr) || continue
        (n,v) = split(hdr, ':'; limit=2)
        hdrdict[String(strip(n))] = String(strip(v))
    end
    hdrdict
end

header(req::HTTP.Request, name, default="") = HTTP.header(req, name, default)
function header(hdrdict::Dict, name, default="")
    for (n,v) in hdrdict
        (lowercase(n) == lowercase(name)) && (return v)
    end
    default
end

function get_multipart_form_boundary(req::HTTP.Request)
    content_type = header(req, "Content-Type")
    isempty(content_type) && (return nothing)
    parts = split(content_type, ";")
    (length(parts) < 2) && (return nothing)
    (lowercase(strip(parts[1])) == "multipart/form-data") || (return nothing)
    parts = split(strip(parts[2]), "=")
    (length(parts) < 2) && (return nothing)
    (lowercase(strip(parts[1])) == "boundary") || (return nothing)
    parts[2]
end

function http_handler(apis::Channel{APIInvoker{T,F}}, preproc::Function, req::HTTP.Request) where {T,F}
    @info("processing", target=getfield(req, :target))
    res = HTTP.Response(500)

    try
        comps = split(getfield(req, :target), '?', limit=2, keepempty=false)
        if isempty(comps)
            res = HTTP.Response(404)
        else
            res = preproc(req)
            if res === nothing
                comps = split(getfield(req, :target), '?', limit=2, keepempty=false)
                path = popfirst!(comps)
                data_dict = isempty(comps) ? Dict{String,String}() : HTTP.queryparams(comps[1])
                multipart_boundary = get_multipart_form_boundary(req)
                if multipart_boundary === nothing
                    data_dict = parsepostdata(req, data_dict)
                else
                    data_dict = parsepostdata(req, data_dict, multipart_boundary)
                end
                args = map(String, split(path, '/', keepempty=false))

                if isempty(args) || !isvalidcmd(args[1])
                    res = HTTP.Response(404)
                else
                    cmd = popfirst!(args)
                    @info("waiting for a handler")
                    api = take!(apis)
                    try
                        if isempty(data_dict)
                            @debug("calling", cmd, args)
                            res = httpresponse(api.format, apicall(api, cmd, args...))
                        else
                            vargs = make_vargs(data_dict)
                            @debug("calling", cmd, args, vargs)
                            res = httpresponse(api.format, apicall(api, cmd, args...; vargs...))
                        end
                    finally
                        put!(apis, api)
                    end
                end
            end
        end
    catch e
        @error("Exception in handler: ", exception=(e, catch_backtrace()))
        res = HTTP.Response(500)
    end
    @debug("response", res)
    return res
end

default_preproc(req::HTTP.Request) = nothing

# add a multipart form handler, provide default
struct HttpRpcServer{T,F}
    api::Channel{APIInvoker{T,F}}
    handler::HTTP.RequestHandlerFunction
end

HttpRpcServer(api::APIInvoker{T,F}, preproc::Function=default_preproc) where {T,F} = HttpRpcServer([api], preproc)
function HttpRpcServer(apis::Vector{APIInvoker{T,F}}, preproc::Function=default_preproc) where {T,F}
    api = Channel{APIInvoker{T,F}}(length(apis))
    for member in apis
        put!(api, member)
    end

    handler_fn = (req)->JuliaWebAPI.http_handler(api, preproc, req)
    handler = HTTP.RequestHandlerFunction(handler_fn)
    HttpRpcServer{T,F}(api, handler)
end

run_http(api::Union{Vector{APIInvoker{T,F}},APIInvoker{T,F}}, port::Int, preproc::Function=default_preproc; kwargs...) where {T,F} = run_http(HttpRpcServer(api, preproc), port; kwargs...)
function run_http(httprpc::HttpRpcServer{T,F}, port::Int; kwargs...) where {T,F}
    @info("running HTTP RPC server...")
    HTTP.listen(ip"0.0.0.0", port; kwargs...) do req
        HTTP.handle(httprpc.handler, req)
    end
end
