# Tests SerializedMsgFormat in async mode operation.
# Both server and client run in the same process.
# In this mode the transport can be in-memory.
include("srvr.jl")
include("clnt.jl")

function test_serialized_msgformat()
    run_srvr(JuliaWebAPI.SerializedMsgFormat(), JuliaWebAPI.ZMQTransport(SRVR_ADDR, ZMQ.REP, true), true)
    run_clnt(JuliaWebAPI.SerializedMsgFormat(), JuliaWebAPI.ZMQTransport("127.0.0.1", 9999, ZMQ.REQ, false))
end

# run tests if invoked with run flag
!isempty(ARGS) && (ARGS[1] == "--runsermsgformat") && test_serialized_msgformat()
