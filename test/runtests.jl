using JuliaWebAPI
using Logging
using Base.Test
using Compat

inline_flag = Base.JLOptions().can_inline == 1 ? `` : `--inline=no`
cov_flag = ``
if Base.JLOptions().code_coverage == 1
    cov_flag = `--code-coverage=user`
elseif Base.JLOptions().code_coverage == 2
    cov_flag = `--code-coverage=all`
end

srvrscript = joinpath(dirname(@__FILE__), "srvr.jl")
srvrcmd = `$(joinpath(JULIA_HOME, "julia")) $cov_flag $inline_flag $srvrscript`
println("spawining $srvrcmd")
srvrproc = spawn(srvrcmd)

include("clnt.jl")
println("stopping server process")
kill(srvrproc)

addprocs(1; exeflags=`$cov_flag $inline_flag`)
@spawnat 2 include("srvrfn.jl")

tic()
for idx in 1:NCALLS
    arg1,arg2,narg1,narg2 = APIARGS[(4*idx-3):(4*idx)]
    @test remotecall_fetch((a1,a2,a3,a4)->(a1*a3 + a2*a4), 2, arg1, arg2, narg1, narg2) == (arg1 * narg1) + (arg2 * narg2)
end
t = toc()
println("time for $NCALLS calls with remotecall_fetch: $t secs @ $(t/NCALLS) per call")
rmprocs(workers())
println("stopped all workers")
