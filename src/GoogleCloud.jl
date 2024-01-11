"""
Google Cloud APIs
"""
module GoogleCloud

export
    JSONCredentials, MetadataCredentials, GoogleSession, authorize,
    set_session!, get_session
export
    iam, storage, compute, container, pubsub, logging, datastore, text_service
export
    BISON_TEXT_MODEL_NAME, GEKKO_EMBEDDING_MODEL_NAME
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
    _datastore.datastore,
    _text_service.text_service

using .api._text_service: BISON_TEXT_MODEL_NAME, GEKKO_EMBEDDING_MODEL_NAME

end
