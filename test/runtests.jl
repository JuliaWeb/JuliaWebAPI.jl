using JuliaWebAPI
using Test

const opts = Base.JLOptions()
const inline_flag = opts.can_inline == 1 ? `` : `--inline=no`
const cov_flag = (opts.code_coverage == 1) ? `--code-coverage=user` :
                 (opts.code_coverage == 2) ? `--code-coverage=all` :
                 ``

function run_test(script, flags)
    srvrscript = joinpath(dirname(@__FILE__), script)
    srvrcmd = `$(joinpath(Sys.BINDIR, "julia")) $cov_flag $inline_flag $script $flags`
    println("Running tests from ", script, "\n", "="^60)
    ret = withenv("JULIA_DEPOT_PATH"=>join(DEPOT_PATH, Sys.iswindows() ? ';' : ':')) do
        run(srvrcmd)
    end
    println("Finished ", script, "\n", "="^60)
    nothing
end

run_test("test_asyncsrvr.jl", "--runasyncsrvr")
run_test("test_clntsrvr.jl", "--runclntsrvr")
run_test("test_remotecall.jl", "--runremotecall")
run_test("test_plugins.jl", "--runsermsgformat")
run_test("test_plugins.jl", "--runinproctransport")
run_test("test_httprpc.jl", "--runhttptests")
run_test("test_create_responder.jl", "--runcreateresponder")
