__precompile__()

module JuliaWebAPI

using ZMQ
using JSON
using Logging
using HttpCommon
using HttpServer
using Compat

import Base: close

export AbstractMsgFormat, JSONMsgFormat, SerializedMsgFormat
export AbstractTransport, ZMQTransport, close
export AbstractAPIResponder, APIResponder, EndPts, APISpec, register, process, process_async
export AbstractAPIInvoker, APIInvoker, apicall, httpresponse, fnresponse, run_rest, run_http

const ERR_CODES = @compat Dict{Symbol, Array}(:success            => [200,  0, ""],
                        :invalid_api        => [404, -1, "invalid api"],
                        :api_exception      => [500, -2, "api exception"],
                        :invalid_data       => [500, -3, "invalid data"],
                        :terminate          => [200, 0,  ""],
                        :dummy              => []
                    )

const CONTROL_CMDS = @compat Dict{Symbol, Array}(:terminate => ["terminate"])

include("msgformat.jl")
include("transport.jl")
include("APIResponder.jl")
include("APIInvoker.jl")
include("http_rpc_server.jl")

end # module
