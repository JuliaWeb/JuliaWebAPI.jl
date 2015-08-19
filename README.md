# JuliaWebAPI.jl

[![Build Status](https://travis-ci.org/tanmaykm/JuliaWebAPI.jl.png)](https://travis-ci.org/tanmaykm/JuliaWebAPI.jl)

Facilitates wrapping Julia functions into a remote callable API via ZMQ and HTTP.

##Usage

Example usage to create a simple wrapper. 

Assume a file `srvr.jl` that contains the definition of the following code

```julia
#load package
using JuliaWebAPI
using Compat

#define function testfn1
function testfn1(arg1, arg2; narg1=1, narg2=2)
    return (parse(Int, arg1) * parse(Int, narg1)) + (parse(Int, arg2) * parse(Int, narg2))
end

#define function testfn2
testfn2(arg1, arg2; narg1=1, narg2=2) = testfn1(arg1, arg2; narg1=narg1, narg2=narg2)

#Export testfn1 and testfn2 via a ZMQ listener
process([(testfn1, true), (testfn2, false)], "tcp://127.0.0.1:9999"; bind=true)
```

Start the server process in the background. This process will run the ZMQ listener.
````
julia srvr.jl &
````

Then, in a Julia REPL, run the following code
```julia
julia> using JuliaWebAPI   #Load package

#Create the ZMQ client that talks to the ZMQ listener above
julia> const apiclnt = APIInvoker("tcp://127.0.0.1:9999")
APIInvoker(Context(Ptr{Void} @0x00007f8f62539d70,[Socket(Ptr{Void} @0x00007f8f6366a800)]),Socket(Ptr{Void} @0x00007f8f6366a800))

julia> run_rest(apiclnt, 8888)         #Starts the HTTP server in current process
19-Dec 22:56:29:INFO:root:listening on port 8888...
```

Then, in your browser, navigate to `http://localhost:8888/testfn1/4/5?narg1=6&narg2=4`

This will return the following JSON response to your browser, which is the result of running the `testfn1` function defined above:
`{"data"=>44,"code"=>0}`

