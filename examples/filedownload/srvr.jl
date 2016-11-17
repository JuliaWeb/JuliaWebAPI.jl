using JuliaWebAPI
using Compat
using Logging
using GZip

const CONTENT_DISPOSITION_TEMPLATE = "attachment; filename="
const FILE_DOWNLOAD_HDR = Dict{String,String}("Content-Type" => "application/octet-stream", "Content-Disposition" => "")

function filebytes(filename::String)
    open(filename, "r") do fp
        buff = Array(UInt8, filesize(filename))
        return read!(fp, buff)
    end
end

function servefile(filename::String; zipped=false)
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
    println(iob, "<html><body>")
    println(iob, "Click on a file to download:<br/>")
    println(iob, "<ul>")
    for fname in readdir()
        println(iob, "<li><a href=\"/servefile/$fname\">$fname</a> | <a href=\"/servefile/$fname?zipped=true\">zipped</a></li>")
    end
    println(iob, "</ul>")
    println(iob, "</body></html>")
    takebuf_string(iob)
end

const REGISTERED_APIS = [
        (listfiles, false),
        (servefile, false, FILE_DOWNLOAD_HDR)
    ]

process(REGISTERED_APIS, "tcp://127.0.0.1:9999"; bind=true, log_level=INFO)
