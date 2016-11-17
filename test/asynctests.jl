using JuliaWebAPI
using Compat
using Logging

include("srvrfn.jl")

const JSON_RESP_HDRS = Dict{String,String}("Content-Type" => "application/json; charset=utf-8")
const BINARY_RESP_HDRS = Dict{String,String}("Content-Type" => "application/octet-stream")

const REGISTERED_APIS = [
        (testfn1, true, JSON_RESP_HDRS),
        (testfn2, false),
        (testbinary, false, BINARY_RESP_HDRS)
    ]

api = process_async(REGISTERED_APIS, "tcp://127.0.0.1:9999"; bind=true, log_level=INFO)

include("clnt.jl")
