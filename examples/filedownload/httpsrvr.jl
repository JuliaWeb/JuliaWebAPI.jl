using JuliaWebAPI
using Test

const apiclnt = APIInvoker("tcp://127.0.0.1:9999")

@info("Open http://localhost:12000/listfiles with a web browser to download files")
run_http(apiclnt, 12000)
