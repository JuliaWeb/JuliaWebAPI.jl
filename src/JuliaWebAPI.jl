__precompile__()

module JuliaWebAPI

using ZMQ
using JSON
using Logging
using HttpCommon
using HttpServer
using Compat

export APIResponder, register, process, process_async
export APIInvoker, apicall, httpresponse, fnresponse, run_rest

const ERR_CODES = @compat Dict{Symbol, Array}(:success            => [200,  0, ""],
                        :invalid_api        => [404, -1, "invalid api"],
                        :api_exception      => [500, -2, "api exception"],
                        :invalid_data       => [500, -3, "invalid data"],
                        :terminate          => [200, 0,  ""],
                        :dummy              => []
                    )

const CONTROL_CMDS = @compat Dict{Symbol, Array}(:terminate => ["terminate"])

if VERSION < v"0.5.0-dev+4612"
byte2str(x) = bytestring(x)
else
byte2str(x) = String(x)
end

include("APIResponder.jl")
include("APIInvoker.jl")
include("RESTServer.jl")

end # module
