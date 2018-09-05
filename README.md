# JuliaWebAPI.jl

[![Build Status](https://travis-ci.org/JuliaWeb/JuliaWebAPI.jl.svg?branch=master)](https://travis-ci.org/JuliaWeb/JuliaWebAPI.jl)
[![Coverage Status](https://coveralls.io/repos/github/JuliaWeb/JuliaWebAPI.jl/badge.svg?branch=master)](https://coveralls.io/github/JuliaWeb/JuliaWebAPI.jl?branch=master)

Facilitates wrapping Julia functions into a remote callable API via message queues (e.g. ZMQ, RabbitMQ) and HTTP.

It can plug in to a different messaging infrastructure through an implementation of transport (`AbstractTransport`) and message format (`AbstractMsgFormat`).
Multiple instances of the front (HTTP API) and back (Julia methods) end can help scale an application.
Bundled with the package are implementations for:
- ZMQTransport: use ZMQ for transport
- InProcTransport: use Julia `Channel` for transport within the same process
- JSONMsgFormat: JSON as message format
- SerializedMsgFormat: Julia serialization as message format
- DictMsgFormat: Julia `Dict` as message format, for use within the same process

Combined with a HTTP/Messaging frontend (like [JuliaBox](https://github.com/JuliaCloud/JuliaBox)), it helps deploy Julia packages and code snippets as hosted, auto-scaling HTTP APIs.

Some amount of basic request filtering and pre-processing is possible by registering a pre-processor with the HTTP frontend.
The pre-processor is run at the HTTP server side, where it has access to the complete request. It can examine headers and data and take decision
whether to allow calling the service or respond directly and immediately. It can also rewrite the request before passing it on to the service.

A pre-processor can be used to implement features like authentication, request rewriting and such. See example below.


## Example Usage

Create a file `srvr.jl` with the following code

```julia
# Load required packages
using JuliaWebAPI

# Define functions testfn1 and testfn2 that we shall expose
function testfn1(arg1, arg2; narg1="1", narg2="2")
    return (parse(Int, arg1) * parse(Int, narg1)) + (parse(Int, arg2) * parse(Int, narg2))
end

testfn2(arg1, arg2; narg1="1", narg2="2") = testfn1(arg1, arg2; narg1=narg1, narg2=narg2)

# Expose testfn1 and testfn2 via a ZMQ listener
process([(testfn1, true), (testfn2, false)], "tcp://127.0.0.1:9999"; bind=true)
```

Start the server process in the background. This process will run the ZMQ listener.
````
julia srvr.jl &
````

Then, on a Julia REPL, run the following code
```julia
using JuliaWebAPI   #Load package

#Create the ZMQ client that talks to the ZMQ listener above
const apiclnt = APIInvoker("tcp://127.0.0.1:9999");

#Starts the HTTP server in current process
run_http(apiclnt, 8888)
```

Then, on your browser, navigate to `http://localhost:8888/testfn1/4/5?narg1=6&narg2=4`

This will return the following JSON response to your browser, which is the result of running the `testfn1` function defined above:
`{"data"=>44,"code"=>0}`


Example of an authentication filter implemented using a pre-processor:

````
function auth_preproc(req::Request, res::Response)
    if !validate(req)
        res.status = 401
        return false
    end
    return true
end
run_http(apiclnt, 8888, auth_preproc)
````
