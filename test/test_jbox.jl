using JuliaWebAPI
using Base.Test

jb_test_val = false

function jb_test()
    global jb_test_val = true
end

ENV["JBAPI_CMD"] = "Main.jb_test()"
process()
@test jb_test_val == true
