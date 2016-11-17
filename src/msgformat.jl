abstract AbstractMsgFormat

"""
Intermediate format based on JSON.
A JSON object with `cmd` (string), `args` (array), `vargs` (dict).
"""
immutable JSONMsgFormat <: AbstractMsgFormat
end

function data_dict(data)
    d = Dict{Symbol,Any}()
    for (n,v) in data
        d[n] = v
    end
    d
end

function wireformat(fmt::JSONMsgFormat, cmd::Compat.String, args...; data...)
    req = Dict{Compat.UTF8String,Any}()

    req["cmd"] = cmd
    isempty(args) || (req["args"] = args)
    isempty(data) || (req["vargs"] = data_dict(data))

    msgstr = JSON.json(req)
    msgstr
end

function wireformat(fmt::JSONMsgFormat, code::Int, headers::Dict{Compat.UTF8String,Compat.UTF8String}, resp, id=nothing)
    msg = Dict{Compat.UTF8String,Any}()

    (id == nothing) || (msg["nid"] = id)

    if !isempty(headers)
        msg["hdrs"] = headers
        Logging.debug("sending headers: ", headers)
    end

    msg["code"] = code
    msg["data"] = resp

    msgstr = JSON.json(msg)
    msgstr
end

juliaformat(fmt::JSONMsgFormat, msgstr) = JSON.parse(msgstr)

cmd(fmt::JSONMsgFormat, msg) = get(msg, "cmd", "")
args(fmt::JSONMsgFormat, msg) = get(msg, "args", [])
data(fmt::JSONMsgFormat, msg) = convert(Dict{Symbol,Any}, get(msg, "vargs", Dict{Symbol,Any}()))

"""construct an HTTP Response object from the API response"""
function httpresponse(fmt::JSONMsgFormat, resp)
    hdrs = HttpCommon.headers()
    if "hdrs" in keys(resp)
        for (k,v) in resp["hdrs"]
            hdrs[k] = v
        end
    end
    data = get(resp, "data", "")
    respdata = isa(data, Array) ? convert(Array{UInt8}, data) :
               isa(data, Dict) ? JSON.json(data) :
               string(data)
    Response(resp["code"], hdrs, respdata)
end

"""
extract and return the response data as a direct function call would have returned
but throw error if the call was not successful.
"""
function fnresponse(fmt::JSONMsgFormat, resp)
    data = get(resp, "data", "")
    (resp["code"] == ERR_CODES[:success][1]) || error("API error: $data")
    data
end

