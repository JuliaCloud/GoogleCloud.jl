module Storage

export isgspath, gspath2bkt_key, gsupload, gsdownload

"""
setup credential session
"""
function __init__()
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
    return String(Bkt), String(key)
end

"""
    upload(path::AbstractString, data::AbstractString; content_type = "text/html")

Upload String data to Google Cloud Storage
"""
function gsupload(path::AbstractString, data::AbstractString; content_type = "text/html")
    bkt, key = gspath2bkt_key( configFile )
    storage(:Object, :insert, bkt; name = key, data=data, content_type=content_type)
end

function gsdownload(path::AbstractString)
    bkt, key = gspath2bkt_key( configFile )
    storage(:Object, :get, bkt, key)
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
