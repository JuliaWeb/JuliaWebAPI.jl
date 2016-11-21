using JuliaWebAPI
using Logging
using Base.Test

Logging.configure(level=INFO)

const apiclnt = APIInvoker("tcp://127.0.0.1:9999")

Logging.info("Open http://localhost:12000/listfiles with a web browser to download files")
run_http(apiclnt, 12000)
