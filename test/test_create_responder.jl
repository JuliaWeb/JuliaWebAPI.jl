# Tests a shortcut api to create ZMQ responder with JSON msg format
using JuliaWebAPI
using Test

include("srvr.jl")

function test_create_responder()
    println("testing create_responder api...")
    APIS = [
        (testfn1, true, JSON_RESP_HDRS),
        (testfn2, false),
        (testbinary, false, BINARY_RESP_HDRS),
        (testArray, false),
        (testFile, true, JSON_RESP_HDRS),
        (testException, true, JSON_RESP_HDRS)
    ]

    responder = JuliaWebAPI.create_responder(APIS, SRVR_ADDR, true, "testresponder")
    @test isa(responder, APIResponder{ZMQTransport,JSONMsgFormat})
    @test responder.id == "testresponder"
    @test responder.open == false
    @test length(responder.endpoints) == length(APIS)
end

# run tests if invoked with run flag
!isempty(ARGS) && (ARGS[1] == "--runcreateresponder") && test_create_responder()
