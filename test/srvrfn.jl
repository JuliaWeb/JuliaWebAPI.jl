using Compat

function testfn1(arg1, arg2; narg1=1, narg2=2)
    a1 = isa(arg1, Int) ? arg1 : parse(Int, arg1)
    a2 = isa(arg2, Int) ? arg2 : parse(Int, arg2)
    na1 = isa(narg1, Int) ? narg1 : parse(Int, narg1)
    na2 = isa(narg2, Int) ? narg2 : parse(Int, narg2)
    return (a1 * na1) + (a2 * na2)
end
testfn2(arg1, arg2; narg1=1, narg2=2) = testfn1(arg1, arg2; narg1=narg1, narg2=narg2)

testbinary(datalen::String) = testbinary(parse(Int,datalen))
testbinary(datalen::Int) = rand(UInt8, datalen)

testArray(x::Array{Float64, 2}) = sum(x) + x[1,2]

function testFile(;filename=nothing, filedata=nothing)
    filename = base64decode(filename)
    filedata = base64decode(filedata)
    #println("[", String(filename), "]")
    #println("[", String(filedata), "]")
    string(length(filename)) * "," * string(length(filedata))
end
