
function make_vargs(vargs::Dict{AbstractString,AbstractString})
    arr = Tuple[]
    for (n,v) in vargs
        push!(arr, (symbol(n),v))
    end
    arr
end

function isvalidcmd(cmd::AbstractString)
    isempty(cmd) && return false
    Base.is_id_start_char(cmd[1]) || return false
    for c in cmd
        Base.is_id_char(c) || return false
    end
    true
end

function rest_handler(api::APIInvoker, req::Request, res::Response)
    Logging.debug("processing request $req")

    try
        comps = @compat split(req.resource, '?', limit=2, keep=false)
        if isempty(comps)
            res = Response(404)
        else
            path = shift!(comps)
            query = isempty(comps) ? Dict{AbstractString,AbstractString}() : parsequerystring(comps[1])
            args = @compat split(path, '/', keep=false)
            ## Handling for POST data
            if( typeof(req.data) == Array{Uint8, 1} )
                if( sizeof(req.data) > 0 )
                    idx  = findfirst(req.data, '\0')
                    actual_data = bytestring(req.data[1:(idx == 0 ? endof(req.data) : idx-1)])
                else
                    actual_data = ""
                end
            else
                actual_data = req.data
            end
            Logging.debug("actual_data is :::: $actual_data")

            data_dict = null
            if( contains(actual_data, "=") )
                ## Logging.debug("parsequerystring is :::: $(parsequerystring(actual_data))")
                data_dict = isempty(actual_data) ? query : merge(query, parsequerystring(actual_data))
            else
                data_dict = Dict{String,String}()
            end
            Logging.debug("The data_dict is ::: $data_dict")

            if isempty(args) || !isvalidcmd(args[1])
                res = Response(404)
            else
                cmd = shift!(args)
                if isempty(data_dict)
                    Logging.debug("calling cmd $cmd with args $args")
                    res = httpresponse(apicall(api, cmd, args...))
                else
                    vargs = make_vargs(data_dict)
                    Logging.debug("calling cmd $cmd with args $args, vargs $vargs")
                    res = httpresponse(apicall(api, cmd, args...; vargs...))
                end
            end
        end
    catch e
        res = Response(500)
        Base.error_show(STDERR, e, catch_backtrace())
        err("Exception in handler: $e")
    end
    Logging.debug("\tresponse $res")
    return res
end

on_error(client, err) = err("HTTP error: $err")
on_listen(port) = Logging.info("listening on port $(port)...")

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

function run_rest(api::APIInvoker, port::Int) 
    Logging.debug("running rest server...")
    rest = RESTServer(api)
    run(rest.server, port)
end


