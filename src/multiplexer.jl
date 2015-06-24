type Multiplexer
    frontend::Socket
    backend::Socket
    frontaddr::AbstractString
    backaddr::AbstractString
    ctx::Context

    function Multiplexer(frontport::Integer, backport::Integer, ctx::Context=Context(1))
        Multiplexer("tcp://*:$frontport", "tcp://*:$backport", ctx)
    end

    function Multiplexer(frontaddr::AbstractString, backaddr::AbstractString, ctx::Context=Context(1))
        frontsock = Socket(ctx, XREP)
        backsock = Socket(ctx, XREQ)
        ZMQ.bind(frontsock, frontaddr)
        ZMQ.bind(backsock, backaddr)
        new(frontsock, backsock, frontaddr, backaddr, ctx)
    end
end

function run(mplex::Multiplexer)
    Logging.info("Running multiplexer $(mplex.frontaddr) -> $(mplex.backaddr)...")
    ccall((:zmq_proxy, ZMQ.zmq), Cint, (Ptr{Void}, Ptr{Void}, Ptr{Void}),
            mplex.frontend.data,
            mplex.backend.data,
            C_NULL)
    Logging.info("Terminated multiplexer $(mplex.frontaddr) -> $(mplex.backaddr).")
    ZMQ.close(mplex.frontend)
    ZMQ.close(mplex.backend)
    nothing
end

function close(mplex::Multiplexer)
    Logging.info("Closing multiplexer $(mplex.frontaddr) -> $(mplex.backaddr)...")
    ZMQ.close(mplex.frontend)
    ZMQ.close(mplex.backend)
end

multi_front_conn(frontport::Integer, ctx::Context=Context(1)) = multi_front_conn(frontaddr, ctx)
function multi_front_conn(frontaddr::AbstractString, ctx::Context=Context(1))
    frontconn = Socket(ctx, REQ)
    ZMQ.connect(frontconn, frontaddr)
    Logging.info("Connected to multiplexer frontend at $frontaddr")
    frontconn
end

multi_back_conn(backport::Integer, ctx::Context=Context(1)) = multi_back_conn(backaddr, ctx)
function multi_back_conn(backaddr::AbstractString, ctx::Context=Context(1))
    backconn = Socket(ctx, REQ)
    ZMQ.connect(backconn, backaddr)
    Logging.info("Connected to multiplexer backend at $backaddr")
    backconn
end
