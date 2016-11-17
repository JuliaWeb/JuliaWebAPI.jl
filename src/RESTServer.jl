
function make_vargs(vargs::Dict{Compat.UTF8String,Compat.UTF8String})
    arr = Tuple[]
    for (n,v) in vargs
        push!(arr, (Symbol(n),v))
    end
    arr
end

function isvalidcmd(cmd::Compat.String)
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
            idx = findfirs(req.data, '\0')
            idx = (idx == 0) ? endof(req.data) : (idx - 1)
            post_data = byt2str(req.data[1:idx])
        end
    elseif isa(req.data, Compat.UTF8String)
        post_data = req.data
    end
    
    ('=' in post_data) || (return query)
    merge(query, parsequerystring(post_data))
end

function rest_handler(api::APIInvoker, req::Request, res::Response)
    Logging.info("processing request ", req)
    
    try
        comps = split(req.resource, '?', limit=2, keep=false)
        if isempty(comps)
            res = Response(404)
        else
            path = shift!(comps)
            data_dict = isempty(comps) ? Dict{Compat.UTF8String,Compat.UTF8String}() : parsequerystring(comps[1])
            data_dict = parsepostdata(req, data_dict)
            args = split(path, '/', keep=false)

            if isempty(args) || !isvalidcmd(args[1])
                res = Response(404)
            else
                cmd = shift!(args)
                if isempty(data_dict)
                    Logging.debug("calling cmd ", cmd, ", with args ", args)
                    res = httpresponse(apicall(api, cmd, args...))
                else
                    vargs = make_vargs(data_dict)
                    Logging.debug("calling cmd ", cmd, ", with args ", args, ", vargs ", vargs)
                    res = httpresponse(apicall(api, cmd, args...; vargs...))
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

type RESTServer
    api::APIInvoker
    handler::HttpHandler
    server::Server

    function RESTServer(api::APIInvoker)
        r = new()

        function handler(req::Request, res::Response)
            return rest_handler(api, req, res)
        end

        r.api = api
        r.handler = HttpHandler(handler)
        r.handler.events["error"] = on_error
        r.handler.events["listen"] = on_listen
        r.server = Server(r.handler)
        r
    end
end

run_rest(api::APIInvoker, port::Int) = run_rest(api; port=port)
function run_rest(api::APIInvoker; kwargs...)
    Logging.debug("running rest server...")
    rest = RESTServer(api)
    run(rest.server; kwargs...)
end
