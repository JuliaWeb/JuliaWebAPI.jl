using JuliaWebAPI
using Logging
using Base.Test
using Compat

const opts = Base.JLOptions()
const inline_flag = opts.can_inline == 1 ? `` : `--inline=no`
const cov_flag = (opts.code_coverage == 1) ? `--code-coverage=user` :
                 (opts.code_coverage == 2) ? `--code-coverage=all` :
                 ``

function run_test(script, flags)
    srvrscript = joinpath(dirname(@__FILE__), script)
    srvrcmd = `$(joinpath(JULIA_HOME, "julia")) $cov_flag $inline_flag $script $flags`
    println("Running tests from ", script, "\n", "="^60)
    ret = run(srvrcmd)
    println("Finished ", script, "\n", "="^60)
    nothing
end

run_test("test_asyncsrvr.jl", "--runasyncsrvr")
run_test("test_clntsrvr.jl", "--runclntsrvr")
run_test("test_remotecall.jl", "--runremotecall")
run_test("test_httprpc.jl", "--runhttptests")
run_test("test_serialized_msgformat.jl", "--runsermsgformat")
run_test("test_jbox.jl", "")
