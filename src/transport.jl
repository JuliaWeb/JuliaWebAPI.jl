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
    Logging.debug("sending request: ", msgstr)
    ZMQ.send(conn.sock, ZMQ.Message(msgstr))
    respstr = unsafe_string(ZMQ.recv(conn.sock))
    Logging.debug("received response: ", respstr)
    respstr
end

function sendresp(conn::ZMQTransport, msgstr)
    Logging.debug("sending response: ", msgstr)
    ZMQ.send(conn.sock, ZMQ.Message(msgstr))
end

function recvreq(conn::ZMQTransport)
    reqstr = unsafe_string(ZMQ.recv(conn.sock))
    Logging.debug("received request: ", reqstr)
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

    Logging.debug("sending request: ", msg)
    put!(srvrq, msg)
    resp = take!(clntq)
    Logging.debug("received response: ", resp)
    resp
end

function sendresp(conn::InProcTransport, msg)
    clntq,srvrq = InProcChannels[conn.name]
    Logging.debug("sending response: ", msg)
    put!(clntq, msg)
    nothing
end

function recvreq(conn::InProcTransport)
    clntq,srvrq = InProcChannels[conn.name]
    req = take!(srvrq)
    Logging.debug("received request: ", req)
    req
end

function close(conn::InProcTransport)
    if conn.name in keys(InProcChannels)
        delete!(InProcChannels, conn.name)
    end
    nothing
end
