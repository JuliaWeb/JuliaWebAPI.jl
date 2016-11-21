# The API client calling functions hosted by the server.
# Runs client when invoked directly with "--runclnt" argument.
# Call `run_clnt` otherwise.
using JuliaWebAPI
using Logging
using ZMQ
using Base.Test
using Requests

Logging.configure(level=INFO)

const ctx = Context()

const apiclnt = APIInvoker("tcp://127.0.0.1:9999", ctx)

const NCALLS = 100

const APIARGS = randperm(NCALLS*4)

function printresp(testname, resp)
    hresp = httpresponse(apiclnt.format, resp)
    println("\t$(testname): $(hresp)")
    println("\t\tdata: $(hresp.data)")
    println("\t\thdrs: $(hresp.headers)")
end

function run_clnt()
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
        @test fnresponse(apiclnt.format, resp)["data"] == (arg1 * narg1) + (arg2 * narg2)
    end
    t = toc();
    println("time for $NCALLS calls to testfn1: $t secs @ $(t/NCALLS) per call")

    tic()
    for idx in 1:100
        arg1,arg2,narg1,narg2 = APIARGS[(4*idx-3):(4*idx)]
        resp = apicall(apiclnt, "testfn2", arg1, arg2; narg1=narg1, narg2=narg2)
        @test fnresponse(apiclnt.format, resp) == (arg1 * narg1) + (arg2 * narg2)
    end
    t = toc();
    println("time for $NCALLS calls to testfn2: $t secs @ $(t/NCALLS) per call")

    tic()
    for idx in 1:100
        arrlen = APIARGS[idx]
        resp = apicall(apiclnt, "testbinary", arrlen)
        @test isa(fnresponse(apiclnt.format, resp), Array)
    end
    t = toc();
    println("time for $NCALLS calls to testbinary: $t secs @ $(t/NCALLS) per call")

    #Test Array invocation

    resp = apicall(apiclnt, "testArray", Float64[1.0 2.0; 3.0 4.0])
    @test fnresponse(apiclnt.format, resp) == 12

    close(ctx)
end

function run_httpclnt()
    println("starting http rpc tests.")
    resp = JSON.parse(readall(get("http://localhost:8888/testfn1/1/2")))
    @test resp["code"] == 0
    @test resp["data"] == 5

    resp = JSON.parse(readall(get("http://localhost:8888/testfn1/1/2"; data=Dict(:narg1=>3, :narg2=>4))))
    @test resp["code"] == 0
    @test resp["data"] == 11
    println("finished http rpc tests.")
end

# run client if invoked with run flag
!isempty(ARGS) && (ARGS[1] == "--runclnt") && run_clnt()
!isempty(ARGS) && (ARGS[1] == "--runhttpclnt") && run_httpclnt()
