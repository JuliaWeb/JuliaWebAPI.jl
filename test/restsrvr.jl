using JuliaWebAPI
using Logging
using Base.Test

Logging.configure(level=INFO)

addprocs(1)

@spawnat 2 include("srvr.jl")

const apiclnt = APIInvoker("tcp://127.0.0.1:9999")

run_rest(apiclnt, 8888)

