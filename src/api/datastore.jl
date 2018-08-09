"""
Google Cloud Datastore API
"""
module _datastore

using Base64

export datastore

using ..api
using ...root

"""Enumerations"""
module types
    export ValueType, OperatorType, wrap, unwrap

    using Dates

    import JSON

    """Datastore value types"""
    @enum(ValueType,
        nullValue,
        booleanValue, integerValue, doubleValue, timestampValue,
        keyValue, stringValue, blobValue,
        geoPointValue, entityValue, arrayValue
    )
    value_type_map = Dict(Symbol(x) => x for x in instances(ValueType))
    Base.convert(::Type{ValueType}, x::Symbol) = haskey(value_type_map, x) ? value_type_map[x] : error("Unknown Datastore value type: $x")
    JSON.lower(x::ValueType) = string(x)
    for s in instances(ValueType)
        @eval export $(Symbol(s))
    end

    """Datastore comparison operator types"""
    @enum(OperatorType, LESS_THAN, LESS_THAN_OR_EQUAL, GREATER_THAN, GREATER_THAN_OR_EQUAL, EQUAL, HAS_ANCESTOR)
    operator_type_map = Dict(Symbol(x) => x for x in instances(OperatorType))
    Base.convert(::Type{OperatorType}, x::Symbol) = haskey(operator_type_map, x) ? operator_type_map[x] : error("Unknown Datastore comparison operator type: $x")
    JSON.lower(x::OperatorType) = string(x)
    for s in instances(OperatorType)
        @eval export $(Symbol(s))
    end

    value_types = Dict{Type, ValueType}(
        Bool => booleanValue,
        Integer => integerValue,
        AbstractFloat => doubleValue,
        TimeType => timestampValue,
        AbstractString => stringValue,
        Char => stringValue,
        Enum => stringValue,
        Nothing => nullValue,
    )
    function wrap(x)
        T = typeof(x)
        if T <: AbstractArray
            return Dict(arrayValue => Dict(:values => map(wrap, x)))
        end
        # move up type hierarchy until we get a hit
        while T !== Any
            if haskey(value_types, T)
                return Dict(value_types[T] => x)
            end
            T = supertype(T)
        end
        Dict(blobValue => base64encode(JSON.json(x)))
    end
    function unwrap(x)
        value_type, value = first(x)
        value_type = convert(ValueType, value_type)
        if value_type == timestampValue
            DateTime(chop(value), ISODateTimeFormat)
        elseif value_type == integerValue
            parse(Int64, value)
        elseif value_type == arrayValue
            map(unwrap, value[:values])
        elseif value_type == blobValue
            JSON.parse(String(base64decode(value)))
        else
            value
        end
    end
end

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
