# The API server serving functions from srvrfn.jl.
# Runs server in blocking mode when invoked directly with "--runsrvr" argument.
# Call `run_srvr` to start server otherwise.
using JuliaWebAPI
using HttpCommon
using Logging
using Compat
using ZMQ

include("srvrfn.jl")

const SRVR_ADDR = "tcp://127.0.0.1:9999"
const JSON_RESP_HDRS = Dict{Compat.UTF8String,Compat.UTF8String}("Content-Type" => "application/json; charset=utf-8")
const BINARY_RESP_HDRS = Dict{Compat.UTF8String,Compat.UTF8String}("Content-Type" => "application/octet-stream")

function run_srvr(fmt, tport, async=false)
    Logging.configure(level=INFO, filename="apisrvr_test.log")
    Logging.info("queue is at $SRVR_ADDR")

    api = APIResponder(tport, fmt)
    Logging.info("responding with: $api")

    register(api, testfn1; resp_json=true, resp_headers=JSON_RESP_HDRS)
    register(api, testfn2)
    register(api, testbinary; resp_headers=BINARY_RESP_HDRS)
    register(api, testArray)
    register(api, testFile; resp_json=true, resp_headers=JSON_RESP_HDRS)

    process(api; async=async)
end

function test_preproc(req::Request, res::Response)
    for (n,v) in req.headers
        if lowercase(n) == "juliawebapi"
            res.status = parse(Int, v)
            return false
        end
    end
    JuliaWebAPI.default_preproc(req, res)
end

function run_httprpcsrvr(fmt, tport, async=false)
    run_srvr(fmt, tport, true)
    apiclnt = APIInvoker(ZMQTransport(SRVR_ADDR, REQ, false), fmt)
    if async
        @async run_http(apiclnt, 8888, test_preproc)
    else
        run_http(apiclnt, 8888, test_preproc)
    end
end

# run in blocking mode if invoked with run flag
!isempty(ARGS) && (ARGS[1] == "--runsrvr") && run_srvr(JuliaWebAPI.JSONMsgFormat(), JuliaWebAPI.ZMQTransport(SRVR_ADDR, ZMQ.REP, true), false)

# run http rpc server if invoked with flag
!isempty(ARGS) && (ARGS[1] == "--runhttprpcsrvr") && run_httprpcsrvr(JuliaWebAPI.JSONMsgFormat(), JuliaWebAPI.ZMQTransport(SRVR_ADDR, ZMQ.REP, true), false)
