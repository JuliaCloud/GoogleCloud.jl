"""
Google API URL roots.
"""
module root

export API_ROOT, SCOPE_ROOT, AUD_ROOT, isurl

"""
    isurl(path)

Return true if `path` is a URL and false a path fragment.
"""
isurl(path::String) = ismatch(r"^https?://", path)

const API_ROOT = "https://www.googleapis.com"
const SCOPE_ROOT = "$API_ROOT/auth"
const AUD_ROOT = "$API_ROOT/oauth2/v4/token"

end
