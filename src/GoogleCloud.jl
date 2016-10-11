"""
Google Cloud APIs
"""
module GoogleCloud

export
    GoogleCredentials, GoogleSession, authorize,
    set_session!, get_session
export
    storage, compute
export
    KeyStore, commit!, fetch!, sync!, clearcache!, clearpending!, reset!, watch, unwatch

# submodules
include("root.jl")
include("error.jl")
include("credentials.jl")
include("session.jl")
include("api/api.jl")
include("collection.jl")

using .error
using .credentials
using .session
using .api
using .collection

# API bindings
import .api: _storage.storage, _compute.compute

end
