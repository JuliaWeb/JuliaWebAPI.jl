abstract AbstractMsgFormat

"""
Intermediate format based on JSON.
A JSON object with `cmd` (string), `args` (array), `vargs` (dict).
"""
immutable JSONMsgFormat <: AbstractMsgFormat
end

wireformat(fmt::JSONMsgFormat, cmd::Compat.String, args...; data...) = JSON.json(_dict_fmt(cmd, args...; data...))
wireformat(fmt::JSONMsgFormat, code::Int, headers::Dict{Compat.UTF8String,Compat.UTF8String}, resp, id=nothing) = JSON.json(_dict_fmt(code, headers, resp, id))
juliaformat(fmt::JSONMsgFormat, msgstr) = JSON.parse(msgstr)
cmd(fmt::JSONMsgFormat, msg) = get(msg, "cmd", "")
args(fmt::JSONMsgFormat, msg) = get(msg, "args", [])
data(fmt::JSONMsgFormat, msg) = convert(Dict{Symbol,Any}, get(msg, "vargs", Dict{Symbol,Any}()))

"""construct an HTTP Response object from the API response"""
httpresponse(fmt::JSONMsgFormat, resp) = _dict_httpresponse(resp)

"""
extract and return the response data as a direct function call would have returned
but throw error if the call was not successful.
"""
fnresponse(fmt::JSONMsgFormat, resp) = _dict_fnresponse(resp)

"""
Intermediate format based on Julia serialization.
A dict with `cmd` (string), `args` (array), `vargs` (dict).
"""
immutable SerializedMsgFormat <: AbstractMsgFormat
end

wireformat(fmt::SerializedMsgFormat, cmd::Compat.String, args...; data...) = _dict_ser(_dict_fmt(cmd, args...; data...))
wireformat(fmt::SerializedMsgFormat, code::Int, headers::Dict{Compat.UTF8String,Compat.UTF8String}, resp, id=nothing) = _dict_ser(_dict_fmt(code, headers, resp, id))
juliaformat(fmt::SerializedMsgFormat, msgstr) = _dict_dser(msgstr)
cmd(fmt::SerializedMsgFormat, msg) = get(msg, "cmd", "")
args(fmt::SerializedMsgFormat, msg) = get(msg, "args", [])
data(fmt::SerializedMsgFormat, msg) = convert(Dict{Symbol,Any}, get(msg, "vargs", Dict{Symbol,Any}()))

"""construct an HTTP Response object from the API response"""
httpresponse(fmt::SerializedMsgFormat, resp) = _dict_httpresponse(resp)

"""
extract and return the response data as a direct function call would have returned
but throw error if the call was not successful.
"""
fnresponse(fmt::SerializedMsgFormat, resp) = _dict_fnresponse(resp)

##############################################
# common utility methods for message formats
##############################################
function data_dict(data)
    d = Dict{Symbol,Any}()
    for (n,v) in data
        d[n] = v
    end
    d
end

function _dict_ser(d)
    io = IOBuffer()
    serialize(io, d)
    takebuf_array(io)
end
_dict_dser(b) = deserialize(IOBuffer(b))

function _dict_fmt(cmd::Compat.String, args...; data...)
    req = Dict{Compat.UTF8String,Any}()

    req["cmd"] = cmd
    isempty(args) || (req["args"] = args)
    isempty(data) || (req["vargs"] = data_dict(data))
    req
end

function _dict_fmt(code::Int, headers::Dict{Compat.UTF8String,Compat.UTF8String}, resp, id=nothing)
    msg = Dict{Compat.UTF8String,Any}()

    (id == nothing) || (msg["nid"] = id)

    if !isempty(headers)
        msg["hdrs"] = headers
        Logging.debug("sending headers: ", headers)
    end

    msg["code"] = code
    msg["data"] = resp
    msg
end

function _dict_httpresponse(resp)
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

function _dict_fnresponse(resp)
    data = get(resp, "data", "")
    (resp["code"] == ERR_CODES[:success][1]) || error("API error: $data")
    data
end
