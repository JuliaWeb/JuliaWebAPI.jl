@compat abstract type AbstractMsgFormat end

"""
Intermediate format based on JSON.
A JSON object with `cmd` (string), `args` (array), `vargs` (dict).
"""
immutable JSONMsgFormat <: AbstractMsgFormat
end

wireformat(fmt::JSONMsgFormat, cmd::Compat.String, args...; data...) = JSON.json(_dict_fmt(cmd, args...; data...))
wireformat(fmt::JSONMsgFormat, code::Int, headers::Dict{Compat.UTF8String,Compat.UTF8String}, resp, id=nothing) = JSON.json(_dict_fmt(code, headers, resp, id))
juliaformat(fmt::JSONMsgFormat, msgstr) = JSON.parse(msgstr)

"""
Intermediate format based on Julia serialization.
A dict with `cmd` (string), `args` (array), `vargs` (dict).
"""
immutable SerializedMsgFormat <: AbstractMsgFormat
end

wireformat(fmt::SerializedMsgFormat, cmd::Compat.String, args...; data...) = _dict_ser(_dict_fmt(cmd, args...; data...))
wireformat(fmt::SerializedMsgFormat, code::Int, headers::Dict{Compat.UTF8String,Compat.UTF8String}, resp, id=nothing) = _dict_ser(_dict_fmt(code, headers, resp, id))
juliaformat(fmt::SerializedMsgFormat, msgstr) = _dict_dser(msgstr)

"""
Intermediate format that is just a Dict. No serialization.
A Dict with `cmd` (string), `args` (array), `vargs` (dict).
"""
immutable DictMsgFormat <: AbstractMsgFormat
end

wireformat(fmt::DictMsgFormat, cmd::Compat.String, args...; data...) = _dict_fmt(cmd, args...; data...)
wireformat(fmt::DictMsgFormat, code::Int, headers::Dict{Compat.UTF8String,Compat.UTF8String}, resp, id=nothing) = _dict_fmt(code, headers, resp, id)
juliaformat(fmt::DictMsgFormat, msg) = msg

##############################################
# common interface methods for message formats
##############################################
cmd(fmt::AbstractMsgFormat, msg) = get(msg, "cmd", "")
args(fmt::AbstractMsgFormat, msg) = get(msg, "args", [])
data(fmt::AbstractMsgFormat, msg) = convert(Dict{Symbol,Any}, get(msg, "vargs", Dict{Symbol,Any}()))

"""
extract and return the response data as a direct function call would have returned
but throw error if the call was not successful.
"""
fnresponse(fmt::AbstractMsgFormat, resp) = _dict_fnresponse(resp)

"""construct an HTTP Response object from the API response"""
httpresponse(fmt::AbstractMsgFormat, resp) = _dict_httpresponse(resp)

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
    take!(io)
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
