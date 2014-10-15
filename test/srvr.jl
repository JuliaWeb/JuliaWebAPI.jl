using JuliaBox
using Logging
using Base.Test

Logging.configure(level=INFO)

function testfn1(arg1, arg2; narg1=1, narg2=2)
    return (int(arg1) * int(narg1)) + (int(arg2) * int(narg2))
end
testfn2(arg1, arg2; narg1=1, narg2=2) = testfn1(arg1, arg2; narg1=narg1, narg2=narg2)

api = APIResponder("tcp://127.0.0.1:9999")
register(api, Main, testfn1, resp_json=true)
register(api, Main, testfn2, resp_json=false)

println("processing...")
process(api)

