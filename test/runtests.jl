addprocs(1)

@spawnat 2 include("srvr.jl")
include("clnt.jl")

tic()
for idx in 1:NCALLS
    arg1,arg2,narg1,narg2 = APIARGS[(4*idx-3):(4*idx)]
    @test remotecall_fetch(2, (a1,a2,a3,a4)->(a1*a3 + a2*a4), arg1, arg2, narg1, narg2) == (arg1 * narg1) + (arg2 * narg2)
end
t = toc()
println("time for $NCALLS with remotecall_fetch: $t secs @ $(t/NCALLS) per call")
