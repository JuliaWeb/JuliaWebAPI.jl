
type APIInvoker
    addr::AbstractString
    ctx::Context
    sockpool::Array{Socket,1}
    usedpool::Array{Socket,1}
    maxconn::Int
    connwaitq::Array{RemoteRef,1}

    function APIInvoker(addr::AbstractString, maxconn::Int, ctx::Context=Context())
        a = new()
        a.addr = addr
        a.ctx = ctx
        a.sockpool = Socket[]
        a.usedpool = Socket[]
        a.maxconn = maxconn
        a.connwaitq = RemoteRef[]
        a
    end
    APIInvoker(ip::IPv4, port::Int, maxconn::Int, ctx::Context=Context()) = APIInvoker("tcp://$ip:$port", maxconn, ctx)
end

function inuse(conn::APIInvoker)
    nused = length(conn.usedpool)
    Logging.debug("$nused connections in use")
    nused
end

function infree(conn::APIInvoker)
    nfree = length(conn.sockpool)
    Logging.debug("$nfree connections free")
    nfree
end

function getsock(conn::APIInvoker)
    if isempty(conn.sockpool)
        if length(conn.usedpool) == conn.maxconn
            Logging.debug("all connections used. waiting...")
            r = RemoteRef()
            push!(conn.connwaitq, r)
            sock = take!(r)
            Logging.debug("out of wait...")
        else
            Logging.debug("creating new socket")
            sock = Socket(conn.ctx, REQ)
            ZMQ.connect(sock, conn.addr)
        end
    else
        Logging.debug("getting cached socket")
        sock = pop!(conn.sockpool)
    end
    push!(conn.usedpool, sock)
    Logging.debug("getsock usedpool size: $(length(conn.usedpool)) objid: $(object_id(conn))")
    sock
end

function putsock(conn::APIInvoker, sock::Socket)
    splice!(conn.usedpool, findin(conn.usedpool, [sock])[1])
    if isempty(conn.connwaitq)
        push!(conn.sockpool, sock)
    else
        r = pop!(conn.connwaitq)
        put!(r, sock)
    end
    Logging.debug("putsock usedpool size: $(length(conn.usedpool)) objid: $(object_id(conn))")
    nothing
end

function data_dict(data::Array)
    d = Dict{Symbol,Any}()
    for (n,v) in data
        d[n] = v
    end
    d
end

# call a remote api
function apicall(conn::APIInvoker, cmd::AbstractString, args...; data...)
    req = Dict{AbstractString,Any}()

    req["cmd"] = cmd
    isempty(args) || (req["args"] = args)
    isempty(data) || (req["vargs"] = data_dict(data))

    msgstr = JSON.json(req)
    Logging.debug("sending request: $msgstr")
    sock = getsock(conn)
    Logging.debug("sock: $sock")
    ZMQ.send(sock, Message(JSON.json(req)))

    respstr = bytestring(ZMQ.recv(sock))
    Logging.debug("received response $respstr")
    putsock(conn, sock)
    JSON.parse(respstr)
end

# construct an HTTP Response object from the API response
function httpresponse(resp::Dict)
    hdrs = HttpCommon.headers()
    if "hdrs" in keys(resp)
        for (k,v) in resp["hdrs"]
            hdrs[k] = v
        end
    end
    data = get(resp, "data", "")
    respdata = isa(data, Array) ? convert(Array{UInt8}, data) :
               isa(data, Dict) ? JSON.json(data) :
               string(data)
    Response(resp["code"], hdrs, respdata)
end

# extract and return the response data as a direct function call would have returned
# but throw error if the call was not successful.
function fnresponse(resp::Dict)
    data = get(resp, "data", "")
    (resp["code"] == ERR_CODES[:success][1]) || error("API error: " * data)
    data
end

