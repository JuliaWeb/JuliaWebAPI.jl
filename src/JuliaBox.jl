module JuliaBox

using ZMQ
using JSON
using Logging
using HttpCommon
using HttpServer
using Compat

export APIResponder, register, process
export APIInvoker, apicall, httpresponse, fnresponse, run_rest

const ERR_CODES = Dict{Symbol, Array}([
                        :success            => [200,  0, ""],
                        :invalid_api        => [404, -1, "invalid api"],
                        :api_exception      => [500, -2, "api exception"],
                        :invalid_data       => [500, -3, "invalid data"],
                        :dummy              => []
                    ])

const CONTROL_CMDS = Dict{Symbol, Array}([
                        :terminate => ["terminate"]
                    ])
if isless(Base.VERSION, v"0.4.0-")
    include("nullable.jl")
end

include("APIResponder.jl")
include("APIInvoker.jl")
include("RESTServer.jl")


end # module
