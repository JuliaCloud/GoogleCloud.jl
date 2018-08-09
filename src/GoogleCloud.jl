"""
Google Cloud APIs
"""
module GoogleCloud

export
    JSONCredentials, MetadataCredentials, GoogleSession, authorize,
    set_session!, get_session
export
    iam, storage, compute, container, pubsub, logging, datastore
export
    KeyStore, commit!, fetch!, sync!, clearcache!, clearpending!, destroy!, connect!, watch, unwatch

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
import .api:
    _iam.iam,
    _storage.storage,
    _compute.compute,
    _container.container,
    _pubsub.pubsub,
    _logging.logging,
    _datastore.datastore

end
