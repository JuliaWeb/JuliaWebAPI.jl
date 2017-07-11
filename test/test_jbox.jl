using JuliaWebAPI
using Base.Test

jb_test_val = false

function jb_test()
    global jb_test_val = true
end

ENV["JBAPI_CMD"] = "Main.jb_test()"
ENV["JBAPI_QUEUE"] = "inproc://jboxtest"
process()
@test jb_test_val == true

fib(n::AbstractString) = fib(parse(Int, n));
fib(n::Int) = (n < 2) ? n : (fib(n-1) + fib(n-2));
responder = process([(fib, false)]; bind=true, async=true);
@test isa(responder, APIResponder)
