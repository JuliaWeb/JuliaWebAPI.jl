using JuliaWebAPI
using Test
using Distributed

include("clnt.jl")

const opts = Base.JLOptions()
const inline_flag = opts.can_inline == 1 ? `` : `--inline=no`
const cov_flag = (opts.code_coverage == 1) ? `--code-coverage=user` :
                 (opts.code_coverage == 2) ? `--code-coverage=all` :
                 ``

function addproc_srvr()
    addprocs(1; exeflags=`$cov_flag $inline_flag`)
end

function rmproc_srvr()
    rmprocs(workers())
end

function time_remotecall()
    addproc_srvr()

    t1 = time()
    for idx in 1:NCALLS
        arg1,arg2,narg1,narg2 = APIARGS[(4*idx-3):(4*idx)]
        @test remotecall_fetch((a1,a2,a3,a4)->(a1*a3 + a2*a4), 2, arg1, arg2, narg1, narg2) == (arg1 * narg1) + (arg2 * narg2)
    end
    t = time() - t1
    println("time for $NCALLS calls with remotecall_fetch: $t secs @ $(t/NCALLS) per call")
    rmproc_srvr()

    println("stopped all workers")
end

# run tests if invoked with run flag
!isempty(ARGS) && (ARGS[1] == "--runremotecall") && time_remotecall()
