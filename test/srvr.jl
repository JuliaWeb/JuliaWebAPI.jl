# The API server serving functions from srvrfn.jl.
# Runs server in blocking mode when invoked directly with "--runsrvr" argument.
# Call `run_srvr` to start server otherwise.
using JuliaWebAPI
using Logging
using Compat

include("srvrfn.jl")

const JSON_RESP_HDRS = Dict{Compat.UTF8String,Compat.UTF8String}("Content-Type" => "application/json; charset=utf-8")
const BINARY_RESP_HDRS = Dict{Compat.UTF8String,Compat.UTF8String}("Content-Type" => "application/octet-stream")

const REGISTERED_APIS = [
        (testfn1, true, JSON_RESP_HDRS),
        (testfn2, false),
        (testbinary, false, BINARY_RESP_HDRS),
        (testArray, false)
    ]

function run_srvr(async=false)
    modefn = async ? process_async : process
    modefn(REGISTERED_APIS, "tcp://127.0.0.1:9999"; bind=true, log_level=INFO)
end

function run_httprpcsrvr(async=false)
    run_srvr(true)
    apiclnt = APIInvoker("tcp://127.0.0.1:9999")
    if async
        @async run_http(apiclnt, 8888)
    else
        run_http(apiclnt, 8888)
    end
end

# run in blocking mode if invoked with run flag
!isempty(ARGS) && (ARGS[1] == "--runsrvr") && run_srvr()

# run http rpc server if invoked with flag
!isempty(ARGS) && (ARGS[1] == "--runhttprpcsrvr") && run_httprpcsrvr()
