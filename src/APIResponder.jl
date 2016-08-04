type APISpec
    fn::Function
    resp_json::Bool
    resp_headers::Dict
end

type APIResponder
    ctx::Context
    sock::Socket
    endpoints::Dict{AbstractString, APISpec}
    nid::AbstractString

    function APIResponder(addr::AbstractString, ctx::Context=Context(), bind::Bool=true, nid::AbstractString="")
        a = new()
        a.ctx = ctx
        a.nid = nid
        a.sock = Socket(ctx, REP)
        a.endpoints = Dict{AbstractString, APISpec}()
        if bind
            ZMQ.bind(a.sock, addr)
        else
            ZMQ.connect(a.sock, addr)
        end
        a
    end
    APIResponder(ip::IPv4, port::Int, ctx::Context=Context()) = APIResponder("tcp://$ip:$port", ctx)
end

function Base.show(io::IO, x::APIResponder)
    println(io, "JuliaWebAPI.APIResponder with endpoints:")
    Base.show_comma_array(STDOUT, keys(x.endpoints), "","")
end

function default_endpoint(f::Function)
    endpt = string(f)
    # separate the module (more natural URL, assumes 'using Module')
    if '.' in endpt
        endpt = rsplit(endpt, '.', limit=2)[2]
    end
    endpt
end

# register a function as API call
# TODO: validate method belongs to module?
function register(conn::APIResponder, f::Function;
                  resp_json::Bool=false,
                  resp_headers::Dict=Dict{AbstractString,AbstractString}(), endpt=default_endpoint(f))
    Logging.debug("registering endpoint [$endpt]")
    conn.endpoints[endpt] = APISpec(f, resp_json, resp_headers)
    return conn #make fluent api possible
end

function respond(conn::APIResponder, code::Int, headers::Dict, resp::Any)
    msg = Dict{AbstractString,Any}()

    isempty(conn.nid) || (msg["nid"] = conn.nid)

    if !isempty(headers)
        msg["hdrs"] = headers
        Logging.debug("sending headers [$headers]")
    end

    msg["code"] = code
    msg["data"] = resp

    msgstr = JSON.json(msg)
    Logging.debug("sending response [$msgstr]")
    ZMQ.send(conn.sock, Message(msgstr))
end

respond(conn::APIResponder, api::Nullable{APISpec}, status::Symbol, resp::Any=nothing) =
    respond(conn, ERR_CODES[status][1], get_hdrs(api), get_resp(api, status, resp))

function call_api(api::APISpec, conn::APIResponder, args::Array, data::Dict{Symbol,Any})
    try
        if !applicable(api.fn, args...)
            narrow_args!(args)
        end
        result = api.fn(args...; data...)
        respond(conn, Nullable(api), :success, result)
    catch ex
        Logging.error("api_exception: $ex")
        respond(conn, Nullable(api), :api_exception)
    end
end


###
#    over JSON to a properly typed and dimensioned Julia array. Arrays
#    serialised from JSON are stored as an Array{Any}, even if all the elements
#    are members of the same concrete type, eg, Float64. This function will
#    transform such an array to an Array{Float64} type.
#
#    Further, since JSON does not have true multidimensional arrays, they are
#    transmitted as arrays containing arrays. This function will convert them to
#    a true multidimensional array in Julia.
###
if VERSION < v"0.5.0-dev+3294"
    promote_arr(x) = Base.map_promote(identity, x)
else
    promote_arr(x) = Base.collect_to!(similar(x, typeof(x[1])), x, 1, 1)
end

function narrow_args!(x)
    for (i, v) in enumerate(x)
        if (typeof(v) <: AbstractArray)
            if (length(v) > 0 && typeof(v[1]) <: Array)
                x[i] = hcat(x[i]...)
            end
            x[i] = promote_arr(x[i])
        end
    end
end

function get_resp(api::Nullable{APISpec}, status::Symbol, resp::Any=nothing)
    st = ERR_CODES[status]
    stcode = st[2]
    stresp = ((stcode != 0) && (resp === nothing)) ? "$(st[3]) : $(st[2])" : resp

    if !isnull(api) && get(api).resp_json
        return @compat Dict{AbstractString, Any}("code" => stcode, "data" => stresp)
    else
        return stresp
    end
end

get_hdrs(api::Nullable{APISpec}) = !isnull(api) ? get(api).resp_headers : Dict{AbstractString,AbstractString}()

args(msg::Dict) = get(msg, "args", [])
data(msg::Dict) = convert(Dict{Symbol,Any}, get(msg, "vargs", Dict{Symbol,Any}()))

# start processing as a server
function process(conn::APIResponder)
    Logging.debug("processing...")
    while true
        msg = JSON.parse(bytestring(ZMQ.recv(conn.sock)))

        cmd = get(msg, "cmd", "")
        Logging.info("received request [$cmd]")

        if startswith(cmd, ':')    # is a control command
            ctrlcmd = symbol(cmd[2:end])
            if ctrlcmd === :terminate
                respond(conn, Nullable{APISpec}(), :terminate, "")
                break
            else
                err("invalid control command $cmd")
                continue
            end
        end

        if !haskey(conn.endpoints, cmd)
            respond(conn, Nullable{APISpec}(), :invalid_api)
            continue
        end

        try
            call_api(conn.endpoints[cmd], conn, args(msg), data(msg))
        catch e
            err("exception $e")
            respond(conn, Nullable(conn.endpoints[cmd]), :invalid_data)
        end
    end
    close(conn.sock)
    #close(conn.ctx)
    Logging.info("stopped processing.")
    conn
end

function setup_logging(;log_level=INFO, nid::AbstractString=get(ENV,"JBAPI_CID",""))
    api_name = get(ENV,"JBAPI_NAME", "noname")
    logfile = "apisrvr_$(api_name)_$(nid).log"
    Logging.configure(level=log_level, filename=logfile)
end

function process_async(apispecs::Array, addr::AbstractString=get(ENV,"JBAPI_QUEUE",""); log_level=INFO, bind::Bool=false, nid::AbstractString=get(ENV,"JBAPI_CID",""))
    process(apispecs, addr; log_level=log_level, bind=bind, nid=nid, async=true)
end

function process(apispecs::Array, addr::AbstractString=get(ENV,"JBAPI_QUEUE",""); log_level=Logging.LogLevel(@compat(parse(Int32,get(ENV, "JBAPI_LOGLEVEL", "1")))),
                bind::Bool=false, nid::AbstractString=get(ENV,"JBAPI_CID",""), async::Bool=false)
    setup_logging(;log_level=log_level)
    Logging.debug("queue is at $addr")
    api = create_responder(apispecs, addr, bind, nid)

    if async
        Logging.debug("processing async...")
        @async process(api)
    else
        Logging.debug("processing...")
        process(api)
    end
    api
end

_add_spec(fn::Function, api::APIResponder) = register(api, fn, resp_json=false, resp_headers=Dict{AbstractString,AbstractString}())

function _add_spec(spec::Tuple, api::APIResponder)
    fn = spec[1]
    resp_json = (length(spec) > 1) ? spec[2] : false
    resp_headers = (length(spec) > 2) ? spec[3] : Dict{AbstractString,AbstractString}()
    api_name = (length(spec) > 3) ? spec[4] : default_endpoint(fn)
    register(api, fn, resp_json=resp_json, resp_headers=resp_headers, endpt=api_name)
end

function create_responder(apispecs::Array, addr, bind, nid)
    api = APIResponder(addr, Context(), bind, nid)
    for spec in apispecs
        _add_spec(spec, api)
    end
    api
end

function process()
    log_level = Logging.LogLevel(@compat(parse(Int32,get(ENV, "JBAPI_LOGLEVEL", "1"))))
    setup_logging(;log_level=log_level)

    Logging.info("Reading api server configuration from environment...")
    Logging.info("JBAPI_NAME=" * get(ENV,"JBAPI_NAME",""))
    Logging.info("JBAPI_QUEUE=" * get(ENV,"JBAPI_QUEUE",""))
    Logging.info("JBAPI_CMD=" * get(ENV,"JBAPI_CMD",""))
    Logging.info("JBAPI_CID=" * get(ENV,"JBAPI_CID",""))
    Logging.info("JBAPI_LOGLEVEL=" * get(ENV,"JBAPI_LOGLEVEL","") * " as " * string(log_level))

    cmd = get(ENV,"JBAPI_CMD","")
    eval(parse(cmd))
    nothing
end
