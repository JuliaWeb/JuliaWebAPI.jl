# print the pid out for the monitor process
println(getpid())

using JuliaWebAPI
using Logging

Logging.configure(level=DEBUG)

function sayhello(name)
    println("in sayhello")
    sleep(10)
    println("out of sayhello")
    return "Processor $(getpid())-$(myid()): Hello $(name)!"
end

const REGISTERED_APIS = [
        (sayhello, false)
    ]

process(REGISTERED_APIS, "tcp://127.0.0.1:9998"; bind=false, log_level=DEBUG)
