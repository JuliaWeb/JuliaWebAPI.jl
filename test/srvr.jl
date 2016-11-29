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

function run_srvr(format=:json, async=false)
    if (format == :json) && async
        # test the default convenience function
        REGISTERED_APIS = [
            (testfn1, true, JSON_RESP_HDRS),
            (testfn2, false),
            (testbinary, false, BINARY_RESP_HDRS),
            (testArray, false)
        ]
        process_async(REGISTERED_APIS, SRVR_ADDR, ; bind=true, log_level=INFO)
    else
        fmt = (format == :json) ? JSONMsgFormat() : SerializedMsgFormat()

        Logging.configure(level=INFO, filename="apisrvr_test.log")
        Logging.info("queue is at $SRVR_ADDR")

        api = APIResponder(ZMQTransport(SRVR_ADDR, REP, true), fmt)

        register(api, testfn1; resp_json=true, resp_headers=JSON_RESP_HDRS)
        register(api, testfn2)
        register(api, testbinary; resp_headers=BINARY_RESP_HDRS)
        register(api, testArray)

        process(api; async=async)
    end
end

function run_httprpcsrvr(format=:json, async=false)
    fmt = (format == :json) ? JSONMsgFormat() : SerializedMsgFormat()

    run_srvr(format, true)
    apiclnt = APIInvoker(ZMQTransport(SRVR_ADDR, REQ, false), fmt)
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
