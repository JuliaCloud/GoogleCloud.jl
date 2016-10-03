"""
Google Cloud APIs
"""
module GoogleCloud

export
    GoogleCredentials, GoogleSession, authorize,
    set_session!, get_session,
    storage, KeyStore, Mode

# submodules
include("root.jl")
include("error.jl")
include("credentials.jl")
include("session.jl")
include("api/api.jl")

using .error
using .credentials
using .session
using .api

# API bindings
import .api.storage_api: storage, KeyStore, Mode

end
