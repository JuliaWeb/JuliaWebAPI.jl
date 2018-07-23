__precompile__()

module JuliaWebAPI

using ZMQ
using JSON
using Logging
using HTTP
using Compat
using Compat.Sockets

import Base: close

export AbstractMsgFormat, JSONMsgFormat, SerializedMsgFormat, DictMsgFormat
export AbstractTransport, ZMQTransport, InProcTransport, close
export AbstractAPIResponder, APIResponder, EndPts, APISpec, register, process, process_async
export AbstractAPIInvoker, APIInvoker, apicall, httpresponse, fnresponse, run_rest, run_http

const ERR_CODES = Dict{Symbol, Array}(
    :success       => [200,  0, ""],
    :invalid_api   => [404, -1, "invalid api"],
    :api_exception => [500, -2, "api exception"],
    :invalid_data  => [500, -3, "invalid data"],
    :terminate     => [200, 0,  ""],
    :dummy         => []
)

const CONTROL_CMDS = Dict{Symbol, Array}(
    :terminate => ["terminate"]
)

include("msgformat.jl")
include("transport.jl")
include("APIResponder.jl")
include("APIInvoker.jl")
include("http_rpc_server.jl")

end # module
