"""
Google Cloud Datastore API
"""
module _datastore

export datastore

using ..api
using ...root

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
