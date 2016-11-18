# Tests async mode operation.
# Both server and client run in the same process.
# In this mode the transport can be in-memory.
include("srvr.jl")
include("clnt.jl")

function test_asyncsrvr()
    run_srvr(true)
    run_clnt()
end

# run tests if invoked with run flag
!isempty(ARGS) && (ARGS[1] == "--runasyncsrvr") && test_asyncsrvr()
