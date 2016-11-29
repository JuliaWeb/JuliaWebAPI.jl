# Tests SerializedMsgFormat in async mode operation.
# Both server and client run in the same process.
# In this mode the transport can be in-memory.
include("srvr.jl")
include("clnt.jl")

function test_serialized_msgformat()
    run_srvr(:serialized, true)
    run_clnt(:serialized)
end

# run tests if invoked with run flag
!isempty(ARGS) && (ARGS[1] == "--runsermsgformat") && test_serialized_msgformat()
