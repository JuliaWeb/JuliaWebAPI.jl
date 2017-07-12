using JuliaWebAPI
using Logging
using Base.Test
using Compat

include("srvr.jl")
include("clnt.jl")

function run_httprpctests()
    println("starting httpserver in async mode...")
    run_httprpcsrvr(JuliaWebAPI.JSONMsgFormat(), JuliaWebAPI.ZMQTransport(SRVR_ADDR, ZMQ.REP, true), true)
    wait_for_httpsrvr()
    println("starting client...")
    run_httpclnt()
end

!isempty(ARGS) && (ARGS[1] == "--runhttptests") && run_httprpctests()
