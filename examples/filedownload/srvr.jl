using JuliaWebAPI
using Base64
using GZip

const CONTENT_DISPOSITION_TEMPLATE = "attachment; filename="
const FILE_DOWNLOAD_HDR = Dict{String,String}("Content-Type" => "application/octet-stream", "Content-Disposition" => "")

function filebytes(filename)
    open(filename, "r") do fp
        buff = Array{UInt8}(filesize(filename))
        return read!(fp, buff)
    end
end

function servefile(filename; zipped=false)
    zipped = (zipped == "true")
    FILE_DOWNLOAD_HDR["Content-Disposition"] = string(CONTENT_DISPOSITION_TEMPLATE, filename, zipped?".gz":"")
    open(filename, "r") do fp
        buff = filebytes(filename)
        zipped || return buff

        # gzip file before returning
        gzfname = tempname()
        gzfile = GZip.open(gzfname, "w")
        try
            write(gzfile, buff)
        catch ex
            rethrow(ex)
        finally
            close(gzfile)
            buff = filebytes(gzfname)
            rm(gzfname)
        end
        buff
    end
end

function listfiles()
    iob = IOBuffer()
    println(iob, """<html><body>
                    Upload a file:
                    <form method="POST" enctype="multipart/form-data" action="/savefile">
                        File: <input type="file" name="upfile"><br/>
                        Name: <input type="text" name="filename"><br/>
                        <input type="submit" value="Submit">
                    </form>
                    <hr/>
                    Click on a file to download:<br/>
                    <ul>""")
    for fname in readdir()
        println(iob, "<li><a href=\"/servefile/$fname\">$fname</a> | <a href=\"/servefile/$fname?zipped=true\">zipped</a></li>")
    end
    println(iob, "</ul></body></html>")
    String(take!(iob))
end

function savefile(; upfile=nothing, filename=nothing)
    fname = String(base64decode(filename))
    data = base64decode(upfile)
    savefile(fname, data)
end

function savefile(filename::String, upfile::Vector{UInt8})
    filename = joinpath(pwd(), String(filename))
    open(filename, "w") do f
        write(f, upfile)
    end
    listfiles()
end

const REGISTERED_APIS = [
        (listfiles, false),
        (servefile, false, FILE_DOWNLOAD_HDR),
        (savefile, false),
    ]

process(JuliaWebAPI.create_responder(REGISTERED_APIS, "tcp://127.0.0.1:9999", true, ""))
