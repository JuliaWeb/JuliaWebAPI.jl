using JuliaWebAPI
using Logging
using Compat

import Base.run

type MultiplexServer
    apiclnt::APIInvoker
    httpport::Int
    processors::Array
    mplexsrvr::Tuple
    resttask::Task

    function MultiplexServer(maxprocessors, httpport=8888, addr="tcp://127.0.0.1:9999")
        apiclnt = APIInvoker(addr, maxprocessors)
        srvr = new()
        srvr.apiclnt = apiclnt
        srvr.httpport = httpport
        srvr.processors = Any[]
        srvr
    end
end

#function launchprocessor(srvr::MultiplexServer)
#    (pout,pc) = open(`julia processor.jl`, "r")
#    pid = @compat parse(Int, strip(readline(pout)))
#    push!(srvr.processors, (pid,pout,pc))
#    pid
#end

#function terminateprocessor(srvr::MultiplexServer)
#    (pid,pout,pc) = pop!(srvr.processors)
#
#    println("terminating pid: $pid")
#    run(`kill -15 $pid`)
#    sleep(5)
#    run(`kill -9 $pid`)
#
#    #pid = apicall(srvr.apiclnt, ":terminate_tell_who")
#    pid
#end

function launchprocessor(srvr::MultiplexServer)
    pid = addprocs(1)[1]
    @spawnat pid include("processor.jl")
    push!(srvr.processors, pid)
    pid
end

function terminateprocessor(srvr::MultiplexServer)
    println("requested process to terminate")
    pidresp = apicall(srvr.apiclnt, ":terminate_tell_who")
    println("got terminate response: $pidresp")
    pid = 0
    if get(pidresp, "code", -1) == 200
        pid = get(pidresp, "data", 0)
        if pid > 0
            println("terminated pid: $pid")
            splice!(srvr.processors, findin(srvr.processors, pid)[1])
            println("processors: $(srvr.processors)")
        end
    end
    pid
end

#function terminateprocessor(srvr::MultiplexServer)
#    (pid,) = pop!(srvr.processors)
#
#    try
#        println("terminating pid: $pid")
#        interrupt(pid)
#        kill(pid)
#    catch
#        println("error interrupting $pid")
#    end
#    pid
#end

function launchmplex(srvr::MultiplexServer)
    # being a blocking zmq call, the multiplexer can't be scheduled as a task
    (pout,pc) = open(`julia mplex.jl`, "r")
    pid = @compat parse(Int, strip(readline(pout)))
    srvr.mplexsrvr = (pid,pout,pc)
    pid
end

function launchrest(srvr::MultiplexServer)
    resttask = @schedule run_rest(srvr.apiclnt, srvr.httpport)
    srvr.resttask = resttask
    nothing
end

function run(srvr::MultiplexServer)
    Logging.configure(level=DEBUG)

    launchrest(srvr)
    println("apiclnt task scheduled...")

    mplexpid = launchmplex(srvr)
    println("multiplexer running with pid $mplexpid...")

    reqnprocs = 1

    while true
        nused = JuliaWebAPI.inuse(srvr.apiclnt)
        nfree = JuliaWebAPI.infree(srvr.apiclnt)

        newreqnprocs = min(srvr.apiclnt.maxconn, max(1, nused))
        reqnprocs = max(Int(floor((2*reqnprocs + newreqnprocs)/3)), 1)
        havenprocs = length(srvr.processors)
        println("connections used $nused/$nfree/$(srvr.apiclnt.maxconn), have processors $havenprocs/$reqnprocs/$newreqnprocs")

        if havenprocs < reqnprocs
            diffnprocs = reqnprocs - havenprocs
            println("\tadding $diffnprocs processors...")
            for procid in 1:diffnprocs
                pid = launchprocessor(srvr)
                println("\t\tspawned processor at $pid")
            end
            #procids = addprocs(diffnprocs)
            #for procid in procids
            #    println("\t\tspawning processor at $procid")
            #    @spawnat procid include("processor.jl")
            #end
        elseif havenprocs > reqnprocs
            diffnprocs = havenprocs - reqnprocs
            println("\treducing $diffnprocs processors")
            for procid in 1:diffnprocs
                terminateprocessor(srvr)
            end
        end
        sleep(5)
    end
end

Logging.configure(level=DEBUG)

srvr = MultiplexServer(10)
run(srvr)
#run_rest(srvr.apiclnt, srvr.httpport)
