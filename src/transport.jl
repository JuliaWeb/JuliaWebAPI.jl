abstract AbstractTransport

"""Transport layer over ZMQ sockets"""
immutable ZMQTransport <: AbstractTransport
    ctx::Context
    sock::Socket
    mode::Int # REQ/REP
    bound::Bool

    function ZMQTransport(addr::Compat.String, mode::Int, bound::Bool, ctx::Context=Context())
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
    ZMQ.send(conn.sock, Message(msgstr))
    respstr = unsafe_string(ZMQ.recv(conn.sock))
    Logging.debug("received response: ", respstr)
    respstr
end

function sendresp(conn::ZMQTransport, msgstr)
    Logging.debug("sending response: ", msgstr)
    ZMQ.send(conn.sock, Message(msgstr))
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
