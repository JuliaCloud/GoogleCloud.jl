"""
Google API URL roots.
"""
module root

export API_ROOT, SCOPE_ROOT, AUD_ROOT, METADATA_ROOT, isurl

"""
    isurl(path)

Return true if `path` is a URL and false a path fragment.
"""
isurl(path::AbstractString) = occursin(r"^https?://", path)

const API_ROOT = "https://www.googleapis.com"
const SCOPE_ROOT = "$API_ROOT/auth"
const AUD_ROOT = "$API_ROOT/oauth2/v4/token"
const METADATA_ROOT = "http://metadata.google.internal/computeMetadata/v1"

end
