using JuliaWebAPI
using Test

include("clnt.jl")

const opts = Base.JLOptions()
const inline_flag = opts.can_inline == 1 ? `` : `--inline=no`
const cov_flag = (opts.code_coverage == 1) ? `--code-coverage=user` :
                 (opts.code_coverage == 2) ? `--code-coverage=all` :
                 ``
const startup_flag = `--startup-file=no`

function spawn_srvr()
    srvrscript = joinpath(dirname(@__FILE__), "srvr.jl")
    srvrcmd = `$(joinpath(Sys.BINDIR, "julia")) $startup_flag $cov_flag $inline_flag $srvrscript --runsrvr`
    println("spawining $srvrcmd")
    srvrproc = withenv("JULIA_DEPOT_PATH"=>join(DEPOT_PATH, Sys.iswindows() ? ';' : ':')) do
        run(srvrcmd, wait=false)
    end
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
