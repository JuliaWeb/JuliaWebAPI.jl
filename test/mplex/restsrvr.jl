using JuliaWebAPI
using Logging

Logging.configure(level=DEBUG)

const apiclnt = APIInvoker("tcp://127.0.0.1:9999")

run_rest(apiclnt, 8888)

