module Storage
using GoogleCloud
using Blosc

export create_bucket, delete_bucket
export delete_object
export isgspath, gspath2bkt_key, gsread, gssave

"""
setup credential session
"""
function __init__()
    Blosc.set_num_threads(Sys.CPU_CORES)
    creds = GoogleCredentials(expanduser("~/.google_credentials.json"))
    session = GoogleSession(creds, ["devstorage.full_control"])
    set_session!(storage, session)    # storage is the API root, exported from GoogleCloud.jl
end

function isgspath( path::AbstractString )
    return ismatch(r"^gs://*", path)
end

function create_bucket( bucketName::AbstractString )
    bucketName = replace(bucketName, "gs://", "")
    storage(:Bucket, :insert; data=Dict(:name => bucketName))
end

function delete_bucket( bucketName::AbstractString )
    bucketName = replace(bucketName, "gs://", "")
    storage(:Bucket, :delete, bucketName)
end

function delete_object( path::AbstractString )
    bkt, key = gspath2bkt_key( path )
    storage(:Object, :delete, bkt, key)
end

"""
    gspath2bkt_key( path::AbstractString )

find bucket and key from a gs path
"""
function gspath2bkt_key( path::AbstractString )
    s = replace(path, "gs://", "")
    bkt, key = (split(s, "/"; limit=2) ...)
    return String(bkt), String(key)
end

function serialize_to_bytes(x)
    io = IOBuffer()
    serialize(io, x)
    takebuf_array(io)
end
deserialize_bytes(x) = deserialize(IOBuffer(x))

"""
    upload(path::AbstractString, data::AbstractString; content_type = "text/html")

Upload String data to Google Cloud Storage
"""
function gssave{T,N}(path::AbstractString, data::Array{T,N};
                        content_type = "image/jpeg", compression=:none)
    s = serialize_to_bytes(data)
    if compression == :blosc
        s = compress(s; level=5, shuffle=true, itemsize=sizeof(UInt8))
    end
    bkt, key = gspath2bkt_key( path )
    storage(:Object, :insert, bkt; name = key,
                data=s, content_type=content_type)
end

function gssave(path::AbstractString, data::AbstractString;
                                        content_type = "text/html")
    bkt, key = gspath2bkt_key( path )
    storage(:Object, :insert, bkt; name = key, data=data, content_type=content_type)
end

function gsread(    path::AbstractString;
                    compression::Symbol = :none)
    bkt, key = gspath2bkt_key( path )
    data = storage(:Object, :get, bkt, key)

    # decompress and then deserialize_bytes
    if compression == :blosc
        data = serialize_to_bytes(data)
        data = decompress(UInt8, data)
    end
    return deserialize_bytes(data)
end

"""
    isgcsfile( path::AbstractString )

whether this file is in Google Cloud Storage or not
"""
function isgsfile( path::AbstractString )
    if !isgspath(path)
        return false
    else
        bkt, key = gspath2bkt_key(path)
        error("not implemented yet...")
    end
end


end # end of module Storage
