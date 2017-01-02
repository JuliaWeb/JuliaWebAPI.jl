
function make_vargs(vargs)
    arr = Tuple[]
    for (n,v) in vargs
        push!(arr, (Symbol(n),v))
    end
    arr
end

function isvalidcmd(cmd)
    isempty(cmd) && return false
    Base.is_id_start_char(cmd[1]) || return false
    for c in cmd
        Base.is_id_char(c) || return false
    end
    true
end

function parsepostdata(req, query)
    post_data = ""
    if isa(req.data, Vector{UInt8})
        if !isempty(req.data)
            idx = findfirst(req.data, UInt8('\0'))
            idx = (idx == 0) ? endof(req.data) : (idx - 1)
            post_data = Compat.String(req.data[1:idx])
        end
    elseif isa(req.data, Compat.UTF8String)
        post_data = req.data
    end
    
    ('=' in post_data) || (return query)
    merge(query, parsequerystring(post_data))
end

"""
Handles multipart form data.
Transfers all content as String.
Binary files can be uplaoded by encoding them with base64 first.
"""
const LFLF = UInt8['\n', '\n']
const CRLFCRLF = UInt8['\r', '\n', '\r', '\n']
function parsepostdata(req, data_dict, multipart_boundary)
    data = req.data
    boundary_end = "--" * multipart_boundary * "--"
    boundary = "--" * multipart_boundary * "\r\n"
    Lbound = length(boundary)
    Ldata = length(data)

    boundbytes = convert(Vector{UInt8}, boundary)
    boundbytes_end = convert(Vector{UInt8}, boundary_end)

    boundloc = search(data, boundbytes, 1)
    endpos = startpos = last(boundloc) + 1
    parts = Vector{Vector{UInt8}}()
    isend = false

    while !isend && ((startpos + Lbound) < Ldata)
        boundloc = search(data, boundbytes, startpos)
        if isempty(boundloc)
            boundloc = search(data, boundbytes_end, startpos)
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
        hdrloc1 = search(part, LFLF, 1)
        hdrloc2 = search(part, CRLFCRLF, 1)

        if length(hdrloc1) == 0
            hdrloc = hdrloc2
        elseif length(hdrloc2) == 0
            hdrloc = hdrloc1
        else
            hdrloc = (first(hdrloc1) < first(hdrloc2)) ? hdrloc1 : hdrloc2
        end

        parthdr = Compat.String(part[1:(first(hdrloc)-1)])
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

    content_disposition = header(hdrdict, "Content-Disposition", "")
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
    hdrdict = Headers()
    for hdr in split(parthdr, "\n")
        (':' in hdr) || continue
        (n,v) = split(hdr, ':'; limit=2)
        hdrdict[strip(n)] = strip(v)
    end
    hdrdict
end

header(req::Request, name, default=nothing) = header(req.headers, name, default)
function header(headers::Headers, name, default=nothing)
    for (n,v) in headers
        (lowercase(n) == lowercase(name)) && (return headers[n])
    end
    default
end

function get_multipart_form_boundary(req::Request)
    content_type = header(req, "Content-Type")
    (content_type === nothing) && (return nothing)
    parts = split(content_type, ";")
    (length(parts) < 2) && (return nothing)
    (lowercase(strip(parts[1])) == "multipart/form-data") || (return false)
    parts = split(strip(parts[2]), "=")
    (length(parts) < 2) && (return nothing)
    (lowercase(strip(parts[1])) == "boundary") || (return nothing)
    parts[2]
end

# take a multipart handler
function http_handler(api::APIInvoker, req::Request, res::Response)
    Logging.info("processing request ", req)
    
    try
        comps = split(req.resource, '?', limit=2, keep=false)
        if isempty(comps)
            res = Response(404)
        else
            path = shift!(comps)
            data_dict = isempty(comps) ? Dict{Compat.UTF8String,Compat.UTF8String}() : parsequerystring(comps[1])
            multipart_boundary = get_multipart_form_boundary(req)
            if multipart_boundary === nothing
                data_dict = parsepostdata(req, data_dict)
            else
                data_dict = parsepostdata(req, data_dict, multipart_boundary)
            end
            args = split(path, '/', keep=false)

            if isempty(args) || !isvalidcmd(args[1])
                res = Response(404)
            else
                cmd = shift!(args)
                if isempty(data_dict)
                    Logging.debug("calling cmd ", cmd, ", with args ", args)
                    res = httpresponse(api.format, apicall(api, cmd, args...))
                else
                    vargs = make_vargs(data_dict)
                    Logging.debug("calling cmd ", cmd, ", with args ", args, ", vargs ", vargs)
                    res = httpresponse(api.format, apicall(api, cmd, args...; vargs...))
                end
            end
        end
    catch e
        res = Response(500)
        Base.showerror(STDERR, e, catch_backtrace())
        err("Exception in handler: ", e)
    end
    Logging.debug("\tresponse ", res)
    return res
end

on_error(client, e) = err("HTTP error: ", e)
on_listen(port) = Logging.info("listening on port ", port, "...")

# add a multipart form handler, provide default
type HttpRpcServer
    api::APIInvoker
    handler::HttpHandler
    server::Server

    function HttpRpcServer(api::APIInvoker)
        r = new()

        function handler(req::Request, res::Response)
            return http_handler(api, req, res)
        end

        r.api = api
        r.handler = HttpHandler(handler)
        r.handler.events["error"] = on_error
        r.handler.events["listen"] = on_listen
        r.server = Server(r.handler)
        r
    end
end

run_http(api::APIInvoker, port::Int) = run_http(api; port=port)
function run_http(api::APIInvoker; kwargs...)
    Logging.debug("running HTTP RPC server...")
    httprpc = HttpRpcServer(api)
    run(httprpc.server; kwargs...)
end

# for backward compatibility
@deprecate run_rest(args...; kwargs...) run_http(args...; kwargs...)
