using JuliaWebAPI
using Logging
using ZMQ
using Base.Test

Logging.configure(level=INFO)

const ctx = Context()

const apiclnt = APIInvoker("tcp://127.0.0.1:9999", ctx)

const NCALLS = 100

const APIARGS = randperm(NCALLS*4)

function printresp(testname, resp)
    hresp = httpresponse(resp)
    println("\t$(testname): $(hresp)")
    println("\t\tdata: $(hresp.data)")
    println("\t\thdrs: $(hresp.headers)")
end

println("testing httpresponse...")
resp = apicall(apiclnt, "testfn1", 1, 2, narg1=3, narg2=4)
printresp("testfn1", resp)

resp = apicall(apiclnt, "testfn2", 1, 2, narg1=3, narg2=4)
printresp("testfn1", resp)

resp = apicall(apiclnt, "testbinary", 10)
printresp("testbinary", resp)

tic()
for idx in 1:100
    arg1,arg2,narg1,narg2 = APIARGS[(4*idx-3):(4*idx)]
    resp = apicall(apiclnt, "testfn1", arg1, arg2; narg1=narg1, narg2=narg2)
    @test fnresponse(resp)["data"] == (arg1 * narg1) + (arg2 * narg2)
end
t = toc();
println("time for $NCALLS calls to testfn1: $t secs @ $(t/NCALLS) per call")

tic()
for idx in 1:100
    arg1,arg2,narg1,narg2 = APIARGS[(4*idx-3):(4*idx)]
    resp = apicall(apiclnt, "testfn2", arg1, arg2; narg1=narg1, narg2=narg2)
    @test fnresponse(resp) == (arg1 * narg1) + (arg2 * narg2)
end
t = toc();
println("time for $NCALLS calls to testfn2: $t secs @ $(t/NCALLS) per call")

tic()
for idx in 1:100
    arrlen = APIARGS[idx]
    resp = apicall(apiclnt, "testbinary", arrlen)
    @test isa(fnresponse(resp), Array)
end
t = toc();
println("time for $NCALLS calls to testbinary: $t secs @ $(t/NCALLS) per call")

#Test Array invocation

resp = apicall(apiclnt, "testArray", Float64[1.0 2.0; 3.0 4.0])
@test fnresponse(resp) == 10

close(ctx)
