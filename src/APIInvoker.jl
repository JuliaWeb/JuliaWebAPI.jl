
type APIInvoker
    ctx::Context
    sock::Socket

    function APIInvoker(addr::String, ctx::Context=Context())
        a = new()
        a.ctx = ctx
        a.sock = Socket(ctx, REQ)
        ZMQ.connect(a.sock, addr)
        a
    end
    APIInvoker(ip::IPv4, port::Int, ctx::Context=Context()) = APIInvoker("tcp://$ip:$port", ctx)
end

function data_dict(data::Array)
    d = Dict{Symbol,Any}()
    for (n,v) in data
        d[n] = v
    end
    d
end

# call a remote api
function apicall(conn::APIInvoker, cmd::String, args...; data...)
    req = Dict{String,Any}()

    req["cmd"] = cmd
    isempty(args) || (req["args"] = args)
    isempty(data) || (req["vargs"] = data_dict(data))

    msgstr = JSON.json(req)
    debug("sending request: $msgstr")
    ZMQ.send(conn.sock, Message(JSON.json(req)))

    respstr = bytestring(ZMQ.recv(conn.sock))
    debug("received response $respstr")
    JSON.parse(respstr)
end

# construct an HTTP Response object from the API response
function httpresponse(resp::Dict)
    hdrs = merge(HttpCommon.headers(), get(resp, "hdrs", Dict{String,String}()))
    data = get(resp, "data", "")
    if isa(data, Array)
        Response(resp["code"], hdrs, convert(Array{Uint8}, data))
    else
        Response(resp["code"], hdrs, string(data))
    end
end

# extract and return the response data as a direct function call would have returned
# but throw error if the call was not successful.
function fnresponse(resp::Dict)
    data = get(resp, "data", "")
    (resp["code"] == ERR_CODES[:success][1]) || error("API error: " * data)
    data
end

