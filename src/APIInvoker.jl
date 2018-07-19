"""
APIInvoker holds the transport and format used for a remote api call.
"""
struct APIInvoker{T<:AbstractTransport,F<:AbstractMsgFormat}
    transport::T
    format::F
end

"""
APIInvoker holds the transport and format used for a remote api call.
This method creates an APIInvoker over ZMQ transport using JSON message format.
(provided for backward compatibility)
"""
APIInvoker(addr::String, ctx::Context=Context()) = APIInvoker(ZMQTransport(addr, REQ, false, ctx), JSONMsgFormat())
APIInvoker(ip::IPv4, port::Int, ctx::Context=Context()) = APIInvoker(ZMQTransport(ip, port, REQ, false, ctx), JSONMsgFormat())

"""
Calls a remote api `cmd` with `args...` and `data...`.
The response is formatted as specified by the formatter specified in `conn`.
"""
function apicall(conn::APIInvoker{T,F}, cmd, args...; data...) where {T<:AbstractTransport, F<:AbstractMsgFormat}
    req = wireformat(conn.format, String(cmd), args...; data...)
    resp = sendrecv(conn.transport, req)
    juliaformat(conn.format, resp)
end
