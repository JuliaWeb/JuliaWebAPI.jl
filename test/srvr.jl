using JuliaWebAPI
using Compat
using Logging

function testfn1(arg1, arg2; narg1=1, narg2=2)
    a1 = isa(arg1, Int) ? arg1 : parse(Int, arg1)
    a2 = isa(arg2, Int) ? arg2 : parse(Int, arg2)
    na1 = isa(narg1, Int) ? narg1 : parse(Int, narg1)
    na2 = isa(narg2, Int) ? narg2 : parse(Int, narg2)
    return (a1 * na1) + (a2 * na2)
end
testfn2(arg1, arg2; narg1=1, narg2=2) = testfn1(arg1, arg2; narg1=narg1, narg2=narg2)

testbinary(datalen::AbstractString) = testbinary(@compat(parse(Int,datalen)))
testbinary(datalen::Int) = rand(UInt8, datalen)

const JSON_RESP_HDRS = @compat Dict{AbstractString,AbstractString}("Content-Type" => "application/json; charset=utf-8")
const BINARY_RESP_HDRS = @compat Dict{AbstractString,AbstractString}("Content-Type" => "application/octet-stream")

const REGISTERED_APIS = [
        (testfn1, true, JSON_RESP_HDRS),
        (testfn2, false),
        (testbinary, false, BINARY_RESP_HDRS)
    ]

process(REGISTERED_APIS, "tcp://127.0.0.1:9999"; bind=true, log_level=INFO)
