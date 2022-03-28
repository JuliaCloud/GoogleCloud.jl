module collection

export
    KeyStore, connect!, destroy!, watch, unwatch

using Dates
using Printf

using HTTP

import JSON
import MsgPack

using ..session
using ..api
using ..api._storage

function _serialize_bytes(x)
    io = IOBuffer()
    serialize(io, x)
    take!(io)
end
_deserialize_bytes(x) = deserialize(IOBuffer(x))

# key serialiser/deserialiser pairs
const KEY_FORMAT_MAP = Dict{Symbol, Tuple{Function, Function}}(
    :json => (JSON.json, JSON.parse),
    :string => (string, identity)
)

# value serialiser/deserialiser pairs
const VAL_FORMAT_MAP = Dict{Symbol, Tuple{Function, Function}}(
    :json => (JSON.json, JSON.parse),
    :string => (string, identity),
    :data => (identity, identity),
    :julia => (_serialize_bytes, _deserialize_bytes),
    :msgpack => (MsgPack.pack, MsgPack.unpack)
)

"""
High-level container wrapping a Google Storage bucket
"""
struct KeyStore{K, V} <: AbstractDict{K, V}
    bucket_name::String
    session::GoogleSession
    key_decoder::Function
    key_encoder::Function
    reader::Function
    writer::Function
    gzip::Bool
    channel::Dict{Symbol, Any}
end

function KeyStore{K,V}(bucket_name::AbstractString; session::GoogleSession=get_session(storage),
                location::AbstractString="US", empty::Bool=false, gzip::Bool=true,
                key_format::Union{Symbol, AbstractString}=K <: String ? :string : :json,
                val_format::Union{Symbol, AbstractString}=V <: String ? :string : :json,
                debug=false) where {K,V}

    key_encoder, key_decoder = try KEY_FORMAT_MAP[Symbol(key_format)] catch
        error("Unknown key format: $key_format")
    end
    writer, reader = try VAL_FORMAT_MAP[Symbol(val_format)] catch
        error("Unknown value format: $val_format")
    end

    store = KeyStore{K,V}(bucket_name, session,
        (x) -> convert(K, key_decoder(x)), key_encoder,
        reader, writer,
        gzip, Dict{Symbol, Any}()
    )
    # establish availability of bucket
    connect!(store; location=location, empty=empty, debug=debug)
    store
end

function connect!(store::KeyStore; location::AbstractString="US",
                  empty::Bool=false, debug=false)
    response = storage(:Bucket, :get, store.bucket_name;
                       session=store.session, fields="", debug=debug)
    if iserror(response)
        code = response[:error][:code]
        if code == 404  # not found (available)
            response = storage(:Bucket, :insert; session=store.session,
                               data=Dict(:name => store.bucket_name, :location => location),
                               fields="", debug=debug)
            if iserror(response)
                error("Unable to create bucket: $(response[:error][:message])")
            end
        elseif code == 403  # forbidden (not available)
            error("Authorization failure or bucket name already taken: ",
                  response[:error][:message])
        else
            error("Error checking bucket: $(response[:error][:message])")
        end
    elseif empty
        empty!(store)
    end
    store
end

function destroy!(store::KeyStore{K, V}) where {K, V}
    response = storage(:Bucket, :delete, store.bucket_name; session=store.session, fields="")
    if iserror(response)
        error("Unable to delete bucket: $(response[:error][:message])")
    end
    nothing
end

function Base.print(io::IO, store::KeyStore{K, V}) where {K, V}
    print(io, @sprintf("""KeyStore{%s, %s}("%s")""", K, V, store.bucket_name))
end
Base.show(io::IO, store::KeyStore) = print(io, store)

function Base.setindex!(store::KeyStore{K, V}, val::V, key::K) where {K, V}
    name = store.key_encoder(key)
    data = store.writer(val)
    response = storage(:Object, :insert, store.bucket_name; session=store.session,
        name=name, data=data, gzip=store.gzip, content_type="application/octet-stream", fields=""
    )
    if iserror(response)
        error("Unable to set key '$key': $(response[:error][:message])")
    end
    store
end

function Base.getindex(store::KeyStore{K, V}, key::K) where {K, V}
    name = store.key_encoder(key)
    data = storage(:Object, :get, store.bucket_name, name; session=store.session)
    if iserror(data)
        throw(KeyError(key))
    end
    val = store.reader(String(data))
    convert(V, val)
end

function Base.get(store::KeyStore{K, V}, key::K, default) where {K, V}
    try
        return getindex(store, key)
    catch e
        if isa(e, KeyError)
            return default
        else
            throw(e)
        end
    end
end

function Base.haskey(store::KeyStore{K, V}, key::K) where {K, V}
    try
        name = store.key_encoder(key)
        response = storage(:Object, :get, store.bucket_name, name; session=store.session, alt="", fields="")
        !iserror(response)
    catch e
        if typeof(e) == HTTP.ExceptionRequest.StatusError
            false
        else
            rethrow(e)
        end
    end
end

# WARNING: potential for race condition. don't zip keys with values... use collect instead
function Base.keys(store::KeyStore{K, V}) where {K, V}
    result = K[]
    for response in storage(:Object, :list, store.bucket_name; session=store.session, fields="items(name)")
        name = response[:name]
        key = store.key_decoder(name)
        if !isa(key, K)
            throw(TypeError(:keys, "$(store.bucket_name):$name", K, key))
        end
        push!(result, key)
    end
    result
end

# avoiding race condition where values might have been deleted after keys were generated
@inline function Base.values(store::KeyStore{K, V}) where {K, V}
    (x for x in (get(store, key, Nothing) for key in keys(store)) if !isnothing(x))
end

function Base.delete!(store::KeyStore{K, V}, key::K) where {K, V}
    name = store.key_encoder(key)
    response = storage(:Object, :delete, store.bucket_name, name; session=store.session, fields="")
    if iserror(response)
        error("Unable to delete object: $(response[:error][:message])")
    end
    store
end

function Base.pop!(store::KeyStore{K, V}, key::K) where {K, V}
    val = getindex(store, key)
    delete!(store, key)
    val
end

function Base.pop!(store::KeyStore{K, V}, key::K, default) where {K, V}
    val = get(store, key, default)
    delete!(store, key)
    val
end

function Base.merge!(store::KeyStore{K, V}, d::AbstractDict{K, V}) where {K, V}
    for (k, v) in d
        store[k] = v
    end
end

Base.length(store::KeyStore) = length(collect(keys(store)))

Base.isempty(store::KeyStore) = length(store) == 0

function Base.empty!(store::KeyStore{K, V}) where {K, V}
    for object in storage(:Object, :list, store.bucket_name; session=store.session, fields="items(name)")
        response = storage(:Object, :delete, store.bucket_name, object[:name]; session=store.session, fields="")
        if iserror(response)
            error("Unable to delete object: $(response[:error][:message])")
        end
    end
    store
end

"""Skip over missing keys if any deleted since key list was geenrated"""
function fast_forward(store::KeyStore{K, V}, key_list) where {K, V}
    while !isempty(key_list)
        key = pop!(key_list)
        val = get(store, key, Nothing)
        if val !== Nothing
            return Pair{K, V}(key, val)
        end
    end
    nothing
end


#function Base.iterate(store::KeyStore{K, V}) where {K, V}
#
#end
#function Base.start(store::KeyStore{K, V}) where {K, V}
#    key_list = collect(keys(store))
#    return (fast_forward(store, key_list), key_list)
#end
#
#function Base.next(store::KeyStore{K, V}, state) where {K, V}
#    pair, key_list = state
#    return pair, (fast_forward(store, key_list), key_list)
#end
#
#function Base.done(store::KeyStore{K, V}, state) where {K, V}
#    pair, key_list = state
#    pair === nothing
#end
#
@inline function Base.IteratorSize(::Type{KeyStore{K, V}}) where {K, V}
    Base.SizeUnknown()
end

# notifications
function watch(store::KeyStore{K, V}, channel_id::AbstractString,
               address::AbstractString) where {K, V}
    if !isempty(store.channel)
        error("Already watching: $store.channel")
    end
    channel = storage(:Object, :watchAll, store.bucket_name;
        data=Dict(:type => "WEBHOOK", :address => address, :id => channel_id),
        session=store.session
    )
    if iserror(channel)
        error("Unable to watch bucket: $(channel[:error][:message])")
    end
    store.channel = channel
end

function unwatch(store::KeyStore{K, V}) where {K, V}
    response = storage(:Channel, :stop; data=store.channel, session=store.session)
    if iserror(response)
        error("Unable to unwatch bucket: $(response[:error][:message])")
    end
    empty!(store.channel)
    store
end

end
