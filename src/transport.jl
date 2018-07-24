abstract type AbstractTransport end


"""Transport layer over ZMQ sockets"""
struct ZMQTransport <: AbstractTransport
    ctx::Context
    sock::Socket
    mode::Int # REQ/REP
    bound::Bool

    function ZMQTransport(addr::String, mode::Int, bound::Bool, ctx::Context=Context())
        sock = Socket(ctx, mode)
        if bound
            ZMQ.bind(sock, addr)
        else
            ZMQ.connect(sock, addr)
        end
        new(ctx, sock, mode, bound)
    end
    ZMQTransport(ip, port, mode::Int, bound::Bool, ctx::Context=Context()) = ZMQTransport("tcp://$ip:$port", mode, bound, ctx)
end

function sendrecv(conn::ZMQTransport, msgstr)
    @static if isdefined(Base, Symbol("@debug"))
        @debug("sending request", msgstr)
    else
        Logging.debug("sending request: ", msgstr)
    end
    ZMQ.send(conn.sock, ZMQ.Message(msgstr))
    respstr = unsafe_string(ZMQ.recv(conn.sock))
    @static if isdefined(Base, Symbol("@debug"))
        @debug("received response", respstr)
    else
        Logging.debug("received response: ", respstr)
    end
    respstr
end

function sendresp(conn::ZMQTransport, msgstr)
    @static if isdefined(Base, Symbol("@debug"))
        @debug("sending response", msgstr)
    else
        Logging.debug("sending response: ", msgstr)
    end
    ZMQ.send(conn.sock, ZMQ.Message(msgstr))
end

function recvreq(conn::ZMQTransport)
    reqstr = unsafe_string(ZMQ.recv(conn.sock))
    @static if isdefined(Base, Symbol("@debug"))
        @debug("received request", reqstr)
    else
        Logging.debug("received request: ", reqstr)
    end
    reqstr
end

function close(conn::ZMQTransport)
    close(conn.sock)
    # close(conn.ctx)
end


"""Transport layer over in-process Channels"""
struct InProcTransport <: AbstractTransport
    name::Symbol

    function InProcTransport(name::Symbol)
        if !(name in keys(InProcChannels))
            InProcChannels[name] = (Channel{Any}(1), Channel{Any}(1))
        end
        new(name)
    end
end

const InProcChannels = Dict{Symbol,Tuple{Channel{Any},Channel{Any}}}()

function sendrecv(conn::InProcTransport, msg)
    clntq,srvrq = InProcChannels[conn.name]

    @static if isdefined(Base, Symbol("@debug"))
        @debug("sending request", msg)
    else
        Logging.debug("sending request: ", msg)
    end
    put!(srvrq, msg)
    resp = take!(clntq)
    @static if isdefined(Base, Symbol("@debug"))
        @debug("received response", resp)
    else
        Logging.debug("received response: ", resp)
    end
    resp
end

function sendresp(conn::InProcTransport, msg)
    clntq,srvrq = InProcChannels[conn.name]
    @static if isdefined(Base, Symbol("@debug"))
        @debug("sending response", msg)
    else
        Logging.debug("sending response: ", msg)
    end
    put!(clntq, msg)
    nothing
end

function recvreq(conn::InProcTransport)
    clntq,srvrq = InProcChannels[conn.name]
    req = take!(srvrq)
    @static if isdefined(Base, Symbol("@debug"))
        @debug("received request", req)
    else
        Logging.debug("received request: ", req)
    end
    req
end

function close(conn::InProcTransport)
    if conn.name in keys(InProcChannels)
        delete!(InProcChannels, conn.name)
    end
    nothing
end
