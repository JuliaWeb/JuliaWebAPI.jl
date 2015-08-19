srvrscript = joinpath(dirname(@__FILE__), "srvr.jl")
srvrcmd = `$(joinpath(JULIA_HOME, "julia")) $(srvrscript)`
println("spawining $srvrcmd")
srvrproc = spawn(srvrcmd)

include("clnt.jl")
println("stopping server process")
kill(srvrproc)

addprocs(1)
@spawnat 2 include("srvrfn.jl")

tic()
for idx in 1:NCALLS
    arg1,arg2,narg1,narg2 = APIARGS[(4*idx-3):(4*idx)]
    @test remotecall_fetch(2, (a1,a2,a3,a4)->(a1*a3 + a2*a4), arg1, arg2, narg1, narg2) == (arg1 * narg1) + (arg2 * narg2)
end
t = toc()
println("time for $NCALLS calls with remotecall_fetch: $t secs @ $(t/NCALLS) per call")

