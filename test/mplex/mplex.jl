using JuliaWebAPI
using Logging

Logging.configure(level=DEBUG)

const mplex = Multiplexer("tcp://127.0.0.1:9999", "tcp://127.0.0.1:9998", ()->include("processor.jl"), 2)

#addprocessors(mplex)

run(mplex)
