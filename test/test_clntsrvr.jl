using JuliaWebAPI
using Logging
using Compat
using Compat.Test

include("clnt.jl")

const opts = Base.JLOptions()
const inline_flag = opts.can_inline == 1 ? `` : `--inline=no`
const cov_flag = (opts.code_coverage == 1) ? `--code-coverage=user` :
                 (opts.code_coverage == 2) ? `--code-coverage=all` :
                 ``

function spawn_srvr()
    srvrscript = joinpath(dirname(@__FILE__), "srvr.jl")
    srvrcmd = `$(joinpath(Compat.Sys.BINDIR, "julia")) $cov_flag $inline_flag $srvrscript --runsrvr`
    println("spawining $srvrcmd")
    srvrproc = @static (VERSION < v"0.7.0-") ? spawn(srvrcmd) : run(srvrcmd, wait=false)
end

function kill_spawned_srvr(srvrproc)
    kill(srvrproc)
end

function test_remotesrvr()
    srvrproc = spawn_srvr()
    println("started server process, running client")
    run_clnt(JuliaWebAPI.JSONMsgFormat(), JuliaWebAPI.ZMQTransport("127.0.0.1", 9999, ZMQ.REQ, false))
    println("stopping server process")
    kill_spawned_srvr(srvrproc)
end

# run tests if invoked with run flag
!isempty(ARGS) && (ARGS[1] == "--runclntsrvr") && test_remotesrvr()
