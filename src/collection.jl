module collection

export
    KeyStore, connect!, destroy!, watch, unwatch

using Base.Dates

using ..session
using ..api
using ..api._storage

import JSON
import MsgPack

function _serialize_bytes(x)
    io = IOBuffer()
    serialize(io, x)
    takebuf_array(io)
end
_deserialize_bytes(x) = deserialize(IOBuffer(x))

# key serialiser/deserialiser pairs
key_format_map = Dict{Symbol, Tuple{Function, Function}}(
    :json => (JSON.json, JSON.parse),
    :string => (string, identity)
)

# value serialiser/deserialiser pairs
val_format_map = Dict{Symbol, Tuple{Function, Function}}(
    :string => (string, identity),
    :json => (JSON.json, JSON.parse),
    :julia => (_serialize_bytes, _deserialize_bytes),
    :msgpack => (MsgPack.pack, MsgPack.unpack)
)

"""
High-level container wrapping a Google Storage bucket
"""
immutable KeyStore{K, V} <: Associative{K, V}
    bucket_name::String
    session::GoogleSession
    key_decoder::Function
    key_encoder::Function
    reader::Function
    writer::Function
    gzip::Bool
    channel::Dict{Symbol, Any}
    function KeyStore(bucket_name::AbstractString, session::GoogleSession=get_session(storage);
        location::AbstractString="US", empty::Bool=false, gzip::Bool=true,
        key_format::Union{Symbol, AbstractString}=K <: String ? :string : :json,
        val_format::Union{Symbol, AbstractString}=V <: String ? :string : :json
    )
        key_encoder, key_decoder = try key_format_map[Symbol(key_format)] catch
            error("Unknown key format: $key_format")
        end
        writer, reader = try val_format_map[Symbol(val_format)] catch
            error("Unknown value format: $val_format")
        end
        store = new(bucket_name, session,
            (x) -> convert(K, key_decoder(x)), key_encoder,
            reader, writer,
            gzip, Dict{Symbol, Any}()
        )
        # establish availability of bucket
        connect!(store; location=location, empty=empty)
        store
    end
end

function connect!(store::KeyStore; location::AbstractString="US", empty::Bool=false)
    response = storage(:Bucket, :get, store.bucket_name; session=store.session, fields="")
    if iserror(response)
        code = response[:error][:code]
        if code == 404  # not found (available)
            response = storage(:Bucket, :insert; session=store.session, data=Dict(:name => store.bucket_name, :location => location), fields="")
            if iserror(response)
                error("Unable to create bucket: $(response[:error][:message])")
            end
        elseif code == 403  # forbidden (not available)
            error("Bucket name already taken: $bucket_name")
        else
            error("Error checking bucket: $(response[:error][:message])")
        end
    elseif empty
        empty!(store)
    end
    store
end

function destroy!{K, V}(store::KeyStore{K, V})
    response = storage(:Bucket, :delete, store.bucket_name; session=store.session, fields="")
    if iserror(response)
        error("Unable to delete bucket: $(response[:error][:message])")
    end
    nothing
end

function Base.print{K, V}(io::IO, store::KeyStore{K, V})
    print(io, @sprintf("""KeyStore{%s, %s}("%s")""", K, V, store.bucket_name))
end
Base.show(io::IO, store::KeyStore) = print(io, store)
Base.display(store::KeyStore) = print(store)

function Base.setindex!{K, V}(store::KeyStore{K, V}, val::V, key::K)
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

function Base.getindex{K, V}(store::KeyStore{K, V}, key::K)
    name = store.key_encoder(key)
    data = storage(:Object, :get, store.bucket_name, name; session=store.session)
    if iserror(data)
        throw(KeyError(key))
    end
    val = store.reader(data)
    convert(V, val)
end

function Base.get{K, V}(store::KeyStore{K, V}, key::K, default)
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

function Base.haskey{K, V}(store::KeyStore{K, V}, key::K)
    name = store.key_encoder(key)
    response = storage(:Object, :get, store.bucket_name, name; session=store.session, alt="", fields="")
    !iserror(response)
end

# WARNING: potential for race condition. don't zip keys with values... use collect instead
function Base.keys{K, V}(store::KeyStore{K, V})
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
Base.values{K, V}(store::KeyStore{K, V}) = (x for x in (get(store, key, Void) for key in keys(store)) if x !== Void)

function Base.delete!{K, V}(store::KeyStore{K, V}, key::K)
    name = store.key_encoder(key)
    response = storage(:Object, :delete, store.bucket_name, name; session=store.session, fields="")
    if iserror(response)
        error("Unable to delete object: $(response[:error][:message])")
    end
    store
end

function Base.pop!{K, V}(store::KeyStore{K, V}, key::K)
    val = getindex(store, key)
    delete!(store, key)
    val
end

function Base.pop!{K, V}(store::KeyStore{K, V}, key::K, default)
    val = get(store, key, default)
    delete!(store, key)
    val
end

function Base.merge!{K, V}(store::KeyStore{K, V}, d::Associative{K, V})
    for (k, v) in d
        store[k] = v
    end
end

Base.length(store::KeyStore) = length(collect(keys(store)))

Base.isempty(store::KeyStore) = length(store) == 0

function Base.empty!{K, V}(store::KeyStore{K, V})
    for object in storage(:Object, :list, store.bucket_name; session=store.session, fields="items(name)")
        response = storage(:Object, :delete, store.bucket_name, object[:name]; session=store.session, fields="")
        if iserror(response)
            error("Unable to delete object: $(response[:error][:message])")
        end
    end
    store
end

"""Skip over missing keys if any deleted since key list was geenrated"""
function fast_forward{K, V}(store::KeyStore{K, V}, key_list)
    while !isempty(key_list)
        key = pop!(key_list)
        val = get(store, key, Void)
        if val !== Void
            return Pair{K, V}(key, val)
        end
    end
    nothing
end

function Base.start{K, V}(store::KeyStore{K, V})
    key_list = collect(keys(store))
    return (fast_forward(store, key_list), key_list)
end

function Base.next{K, V}(store::KeyStore{K, V}, state)
    pair, key_list = state
    return pair, (fast_forward(store, key_list), key_list)
end

function Base.done{K, V}(store::KeyStore{K, V}, state)
    pair, key_list = state
    pair === nothing
end

Base.iteratorsize{K, V}(::Type{KeyStore{K, V}}) = SizeUnknown()

# notifications
function watch{K, V}(store::KeyStore{K, V}, channel_id::AbstractString, address::AbstractString)
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

function unwatch{K, V}(store::KeyStore{K, V})
    response = storage(:Channel, :stop; data=store.channel, session=store.session)
    if iserror(response)
        error("Unable to unwatch bucket: $(response[:error][:message])")
    end
    empty!(store.channel)
    store
end

end
