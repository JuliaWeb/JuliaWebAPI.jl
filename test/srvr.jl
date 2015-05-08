using JuliaWebAPI
using Compat

function testfn1(arg1, arg2; narg1=1, narg2=2)
    return (@compat(Int(arg1)) * @compat(Int(narg1))) + (@compat(Int(arg2)) * @compat(Int(narg2)))
end
testfn2(arg1, arg2; narg1=1, narg2=2) = testfn1(arg1, arg2; narg1=narg1, narg2=narg2)

process([(testfn1, true), (testfn2, false)], "tcp://127.0.0.1:9999"; bind=true)
