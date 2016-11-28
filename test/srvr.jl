# The API server serving functions from srvrfn.jl.
# Runs server in blocking mode when invoked directly with "--runsrvr" argument.
# Call `run_srvr` to start server otherwise.
using JuliaWebAPI
using Logging
using Compat
using ZMQ

include("srvrfn.jl")

const SRVR_ADDR = "tcp://127.0.0.1:9999"
const JSON_RESP_HDRS = Dict{Compat.UTF8String,Compat.UTF8String}("Content-Type" => "application/json; charset=utf-8")
const BINARY_RESP_HDRS = Dict{Compat.UTF8String,Compat.UTF8String}("Content-Type" => "application/octet-stream")

function run_srvr(async=false)
    Logging.configure(level=INFO, filename="apisrvr_test.log")
    Logging.info("queue is at $SRVR_ADDR")

    api = APIResponder(ZMQTransport(SRVR_ADDR, REP, true), JSONMsgFormat())

    register(api, testfn1; resp_json=true, resp_headers=JSON_RESP_HDRS)
    register(api, testfn2)
    register(api, testbinary; resp_headers=BINARY_RESP_HDRS)
    register(api, testArray)

    process(api; async=async)
end

function run_httprpcsrvr(async=false)
    run_srvr(true)
    apiclnt = APIInvoker(ZMQTransport(SRVR_ADDR, REQ, false), JSONMsgFormat())
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
