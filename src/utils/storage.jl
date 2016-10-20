module Storage
using GoogleCloud
using Blosc

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

"""
    gspath2bkt_key( path::AbstractString )

find bucket and key from a gs path
"""
function gspath2bkt_key( path::AbstractString )
    s = replace(path, "gs://", "")
    bkt, key = (split(s, "/"; limit=2) ...)
    return String(bkt), String(key)
end

"""
    upload(path::AbstractString, data::AbstractString; content_type = "text/html")

Upload String data to Google Cloud Storage
"""
function gssave{T,N}(path::AbstractString, data::Array{T,N};
                        content_type = "image/jpeg", compression=:none)
    if compression == :blosc
        d = compress(data; level=5, shuffle=true, itemize=sizeof(T))
    else
        d = reinterpret(UInt8, data[:])
    end
    gssave(path, d; content_type = content_type)
end

function gssave(path::AbstractString, data::Vector{UInt8};
                    content_type = "image/jpeg", compression = :none)
    if compression == :none
        d = string(data)
    else
        error("unsupported compression methods: $(compression)")
    end
    gssave(path, d; content_type = content_type)
end

function gssave(path::AbstractString, data::AbstractString;
                                        content_type = "text/html")
    bkt, key = gspath2bkt_key( path )
    storage(:Object, :insert, bkt; name = key, data=data, content_type=content_type)
end

function gsread(    path::AbstractString;
                    eltype::Type = String,
                    shape::Tuple = (0,0),
                    compression::Symbol = :none)
    bkt, key = gspath2bkt_key( path )
    data = storage(:Object, :get, bkt, key)
    if compression == :blosc
        data = decompress(eltype, Vector{UInt8}(data))
    else
        data = reinterpret(eltype, data)
    end
    if shape != (0,0)
        data = reshape(data, shape)
    end
    data
end

# """
#     isgcsfile( path::AbstractString )
#
# whether this file is in Google Cloud Storage or not
# """
# function isgcsfile( path::AbstractString )
#     if !isgcspath(path)
#         return false
#     else
#         bkt, key = gspath2bkt_key(path)
#
#     end
# end


end # end of module Storage
