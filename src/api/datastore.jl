"""
Google Cloud Datastore API
"""
module _datastore

export datastore, DatastoreValueType

using ..api
using ...root

@enum(DatastoreValueType,
    nullValue,
    booleanValue,
    integerValue,
    doubleValue,
    timestampValue,
    keyValue,
    stringValue,
    blobValue,
    geoPointValue,
    entityValue,
    arrayValue
)
value_type_map = Dict(string(x) => x for x in instances(DatastoreValueType))
Base.convert(::Type{DatastoreValueType}, x::AbstractString) = haskey(value_type_map, x) ? value_type_map[x] : Base.error("Unknown Datastore value type")

"""
Google Cloud Datastore API root.
"""
datastore = APIRoot(
    "https://datastore.googleapis.com/v1/projects/{project}",
    Dict(
        "cloud-platform" => "Full access to all resources and services in the specified Cloud Platform project.",
        "datastore" => "View and manage your Google Cloud Datastore data",
    );
    Project=APIResource("";
        allocateIds=APIMethod(:DELETE, ":allocateIds", "Allocates IDs for the given keys, which is useful for referencing an entity before it is inserted."),
        beginTransaction=APIMethod(:POST, ":beginTransaction", "Begins a new transaction."),
        commit=APIMethod(:POST, ":commit", "Commits a transaction, optionally creating, deleting or modifying some entities."),
        lookup=APIMethod(:POST, ":lookup", "Looks up entities by key."),
        rollback=APIMethod(:POST, ":rollback", "Rolls back a transaction."),
        runQuery=APIMethod(:POST, ":runQuery", "Queries for entities."),
    ),
)

end
