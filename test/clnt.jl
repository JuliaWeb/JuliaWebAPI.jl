# The API client calling functions hosted by the server.
# Runs client when invoked directly with "--runclnt" argument.
# Call `run_clnt` otherwise.
using JuliaWebAPI
using Logging
using ZMQ
using Base.Test
using Requests

Logging.configure(level=INFO)

const NCALLS = 100
const APIARGS = randperm(NCALLS*4)

function printresp(apiclnt, testname, resp)
    hresp = httpresponse(apiclnt.format, resp)
    println("\t$(testname): $(hresp)")
    println("\t\tdata: $(hresp.data)")
    println("\t\thdrs: $(hresp.headers)")
end

function run_clnt(fmt, tport)
    ctx = Context()
    apiclnt = APIInvoker(tport, fmt)

    println("testing httpresponse...")
    resp = apicall(apiclnt, "testfn1", 1, 2, narg1=3, narg2=4)
    printresp(apiclnt, "testfn1", resp)

    resp = apicall(apiclnt, "testfn2", 1, 2, narg1=3, narg2=4)
    printresp(apiclnt, "testfn1", resp)

    resp = apicall(apiclnt, "testbinary", 10)
    printresp(apiclnt, "testbinary", resp)

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
    close(tport)
end

function run_httpclnt()
    println("starting http rpc tests.")

    resp = get("http://localhost:8888/")
    @test resp.status == 404

    resp = get("http://localhost:8888/invalidapi")
    @test resp.status == 404

    resp = JSON.parse(readstring(get("http://localhost:8888/testfn1/1/2")))
    @test resp["code"] == 0
    @test resp["data"] == 5

    resp = JSON.parse(readstring(get("http://localhost:8888/testfn1/1/2"; data=Dict(:narg1=>3, :narg2=>4))))
    @test resp["code"] == 0
    @test resp["data"] == 11

    println("testing file upload...")
    filename = "a.txt"
    postdata = """------WebKitFormBoundaryIabcPsAlNKQmowCx\r\nContent-Disposition: form-data; name="filedata"; filename="a.txt"\r\nContent-Type: text/plain\r\n\r\nLorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n\r\n------WebKitFormBoundaryIabcPsAlNKQmowCx\r\nContent-Disposition: form-data; name="filename"\r\n\r\na.txt\r\n------WebKitFormBoundaryIabcPsAlNKQmowCx--\r\n"""
    headers = Dict("Content-Type"=>"multipart/form-data; boundary=----WebKitFormBoundaryIabcPsAlNKQmowCx")
    resp = JSON.parse(readstring(post("http://localhost:8888/testFile"; headers=headers, data=postdata)))
    @test resp["code"] == 0
    @test resp["data"] == "5,446"

    println("testing preprocessor...")
    resp = get("http://localhost:8888/testfn1/1/2"; headers = Dict("juliawebapi"=>"404"))
    @test resp.status == 404
    println("finished http rpc tests.")
end

# run client if invoked with run flag
!isempty(ARGS) && (ARGS[1] == "--runclnt") && run_clnt(JuliaWebAPI.JSONMsgFormat(), JuliaWebAPI.ZMQTransport("127.0.0.1", 9999, ZMQ.REQ, false, ctx))
!isempty(ARGS) && (ARGS[1] == "--runhttpclnt") && run_httpclnt()
