module collection

export
    KeyStore, commit!, fetch!, sync!, clearcache!, clearpending!, destroy!, connect!, watch, unwatch

using Base.Dates

using ..session
using ..api
using ..api._storage

# higher-level access to API
import Base:
    print, show, display, getindex, setindex!, merge!, empty!, delete!, pop!, get, haskey, in,
    keys, values, start, next, done, iteratorsize, SizeUnknown,
    fetch

type Box{T}
    value::Union{T, Void}
end
Base.convert{T}(::Type{Box{T}}, x::Union{T, Void}) = Box{T}(x)
Base.isnull(box::Box) = box.value == nothing
Base.get(box::Box) = box.value

@enum Action SET=1 DELETE=2

"""
High-level container wrapping a Google Storage bucket
"""
immutable KeyStore{K, V} <: Associative{K, V}
    bucket_name::String
    session::Box{GoogleSession}
    key_reader::Function
    key_writer::Function
    val_reader::Function
    val_writer::Function
    gzip::Bool
    use_remote::Bool
    use_cache::Bool
    grace::Second
    cache::Dict{K, V}
    pending::Dict{K, Action}
    age::Dict{K, DateTime}
    channel::Dict{Symbol, Any}
    function KeyStore(bucket_name::AbstractString;
        session::Union{GoogleSession, Void}=get_session(storage),
        empty::Bool=false,
        location::AbstractString="US",
        gzip::Bool=true,
        use_remote::Bool=session != nothing, use_cache::Bool=true,
        grace::Second=Second(5),
        key_reader::Function=identity, key_writer::Function=string,
        val_reader::Function=identity, val_writer::Function=string
    )
        if !(use_remote || use_cache)
            error("Must use remote and/or cache but not neither")
        end
        if session == nothing && use_remote
            error("Cannot use remote without a session")
        end

        store = new(bucket_name, session,
            key_reader, key_writer,
            val_reader, val_writer,
            gzip, use_remote, use_cache, grace,
            Dict{K, V}(), Dict{K, Action}(), Dict{K, DateTime}(),
            Dict{Symbol, Any}()
        )

        # establish availability of bucket
        if session != nothing
            connect!(store, session; location=location, empty=empty)
        end
        store
    end
end

function connect!(store::KeyStore, session::GoogleSession; location::AbstractString="US", empty::Bool=false)
    response = storage(:Bucket, :get, store.bucket_name; session=session, fields="")
    if iserror(response)
        code = response[:error][:code]
        if code == 404  # not found (available)
            response = storage(:Bucket, :insert; session=session, data=Dict(:name => store.bucket_name, :location => location), fields="")
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
    store.session.value = session
    store
end

function print(io::IO, store::KeyStore)
    items = length(store.cache)
    print(io, @sprintf("""KeyStore("%s"; use_remote=%s, use_cache=%s) [cached: %d item%s]""",
        store.bucket_name, store.use_remote, store.use_cache, items, items != 1 ? "s" : ""
    ))
end
show(io::IO, store::KeyStore) = print(io, store)
display(store::KeyStore) = print(store)

# getting values
function getindex{K, V}(store::KeyStore{K, V}, key::K, use_remote::Bool=store.use_remote, use_cache::Bool=store.use_cache)
    if !use_remote
        return store.cache[key]
    end
    name = store.key_writer(key)
    if use_cache
        if haskey(store.cache, key)
            val, timestamp = store.cache[key], store.age[key]
            response = storage(:Object, :get, store.bucket_name, name; session=get(store.session), alt="", fields="updated")
            if iserror(response)
                return val
            else
                if timestamp + store.grace > DateTime(response[:updated], "yyyy-mm-ddTHH:MM:SS.sssZ")
                    return val
                end
            end
        end
    end

    timestamp = now(UTC)
    data = storage(:Object, :get, store.bucket_name, name; session=get(store.session))
    if iserror(data)
        throw(KeyError(key))
    end
    val = store.val_reader(data)
    if !isa(val, V)
        throw(TypeError(:getindex, "$(store.bucket_name):$name", V, val))
    end
    if use_cache
        store.cache[key], store.age[key] = val, timestamp
    end
    val
end

function get{K, V}(store::KeyStore{K, V}, key::K, default; use_remote::Bool=store.use_remote, use_cache::Bool=store.use_cache)
    try
        return getindex(store, key, use_remote, use_cache)
    catch e
        if isa(e, KeyError)
            return default
        else
            throw(e)
        end
    end
end

function haskey{K, V}(store::KeyStore{K, V}, key::K; use_remote::Bool=store.use_remote, use_cache::Bool=store.use_cache)
    if !use_remote
        return haskey(store.cache, key)
    end
    if use_cache
        if haskey(store.cache, key)
            return true
        end
    end
    name = store.key_writer(key)
    response = storage(:Object, :get, store.bucket_name, name; session=get(store.session), alt="", fields="")
    if !iserror(response)
        return true
    end
    false
end

function in{K, V}(store::KeyStore{K, V}, key::K; use_remote::Bool=store.use_remote, use_cache::Bool=store.use_cache)
    haskey(store, key; use_remote=use_remote, use_cache=use_cache)
end

# WARNING: potential for race condition. don't zip keys with values... use collect instead
function keys{K, V}(store::KeyStore{K, V}; use_remote::Bool=store.use_remote, use_cache::Bool=store.use_cache)
    if !use_remote
        return keys(store.cache)
    end
    result = use_cache ? collect(keys(store.cache)) : K[]
    for response in storage(:Object, :list, store.bucket_name; session=get(store.session), fields="items(name)")
        name = response[:name]
        key = store.key_reader(name)
        if !isa(key, K)
            throw(TypeError(:keys, "$(store.bucket_name):$name", K, key))
        end
        push!(result, key)
    end
    unique(result)
end

function values{K, V}(store::KeyStore{K, V}; use_remote::Bool=store.use_remote, use_cache::Bool=store.use_cache)
    if !use_remote
        return values(store.cache)
    end

    # avoiding race condition where values might have been deleted after keys were generated
    V[
        x for x in (
            get(store, key, nothing; use_remote=use_remote, use_cache=use_cache)
            for key in keys(store; use_remote=use_remote, use_cache=use_cache)
        ) if x != nothing
    ]
end

# setting values (commit)
function setindex!{K, V}(store::KeyStore{K, V}, val::V, key::K, use_remote::Bool=store.use_remote, use_cache::Bool=store.use_cache)
    if !use_remote
        store.cache[key] = val
        if session != nothing
            store.pending[key] = SET
        end
        return store
    end

    if use_cache
        store.cache[key], store.age[key] = val, now(UTC)
    end
    if use_remote
        name = store.key_writer(key)
        data = store.val_writer(val)
        response = storage(:Object, :insert, store.bucket_name; session=get(store.session),
            name=name, data=data, gzip=store.gzip, content_type="application/octet-stream", fields=""
        )
        if iserror(response)
            error("Unable to set key '$key': $(response[:error][:message])")
        end
    end
    store
end

function delete!{K, V}(store::KeyStore{K, V}, key::K; use_remote::Bool=store.use_remote, use_cache::Bool=store.use_cache)
    if use_cache
        delete!(store.cache, key)
        delete!(store.age, key)
    end
    if use_remote
        name = store.key_writer(key)
        response = storage(:Object, :delete, store.bucket_name, name; session=get(store.session), fields="")
        if iserror(response)
            error("Unable to delete object: $(response[:error][:message])")
        end
    else
        store.pending[key] = DELETE
    end
    store
end

function pop!{K, V}(store::KeyStore{K, V}, key::K; use_remote::Bool=store.use_remote, use_cache::Bool=store.use_cache)
    val = getindex(store, key, use_remote, use_cache)
    delete!(store, key; use_remote=use_remote, use_cache=use_cache)
    val
end

function pop!{K, V}(store::KeyStore{K, V}, key::K, default; use_remote::Bool=store.use_remote, use_cache::Bool=store.use_cache)
    val = get(store, key, default; use_remote=use_remote, use_cache=use_cache)
    delete!(store, key; use_remote=use_remote, use_cache=use_cache)
    val
end

# iteration
function fast_forward{K, V}(store::KeyStore{K, V}, key_list)
    while !isempty(key_list)
        key = pop!(key_list)
        val = get(store, key, nothing)
        if val != nothing
            return Pair{K, V}(key, val)
        end
    end
    nothing
end

function start{K, V}(store::KeyStore{K, V})
    key_list = collect(keys(store))
    return (fast_forward(store, key_list), key_list)
end

function next{K, V}(store::KeyStore{K, V}, state)
    pair, key_list = state
    return pair, (fast_forward(store, key_list), key_list)
end

function done{K, V}(store::KeyStore{K, V}, state)
    pair, key_list = state
    pair == nothing
end

iteratorsize{K, V}(::Type{KeyStore{K, V}}) = SizeUnknown()

# notifications
function watch{K, V}(store::KeyStore{K, V}, channel_id::AbstractString, address::AbstractString)
    if isnull(store.session)
        warn("No session.")
        return Dict{Symbol, Any}()
    end
    if !isempty(store.channel)
        error("Already watching: $store.channel")
    end
    channel = storage(:Object, :watchAll, store.bucket_name;
        data=Dict(:type => "WEBHOOK", :address => address, :id => channel_id),
        session=get(store.session)
    )
    if iserror(channel)
        error("Unable to watch bucket: $(channel[:error][:message])")
    end
    merge!(store.channel, channel)
    return channel
end

function unwatch{K, V}(store::KeyStore{K, V})
    if isnull(store.session)
        warn("No session.")
        return store
    end
    response = storage(:Channel, :stop; data=store.channel, session=get(store.session))
    if iserror(response)
        error("Unable to unwatch bucket: $(response[:error][:message])")
    end
    empty!(store.channel)
    store
end

# committing
function merge!{K, V}(store::KeyStore{K, V}, d::Associative{K, V})
    for (k, v) in d
        store[k] = v
    end
end

function commit!{K, V}(store::KeyStore{K, V})
    if isnull(store.session)
        warn("No session.")
        return store
    end
    use_remote, use_cache = true, false
    for key in collect(keys(store.pending))
        action = pop!(store.pending, key)
        if action == SET
            store.age[key] = now(UTC)
            val = store.cache[key]
            setindex!(store, val, key, use_remote, use_cache)
        elseif action == DELETE
            delete!(store, key; use_remote=use_remote, use_cache=use_cache)
        end
    end
    store
end

function fetch!{K, V}(store::KeyStore{K, V}, key_list::K...)
    if isnull(store.session)
        warn("No session.")
        return store
    end
    if !isempty(store.pending)
        error("Pending actions must be committed or cleared before fetching.")
    end
    if isempty(key_list)
        key_list = keys(store; use_remote=true, use_cache=false)
    end
    for key in key_list
        val = get(store, key, nothing; use_remote=true, use_cache=false)
        if val != nothing
            store.cache[key], store.age[key] = val, now(UTC)
        end
    end
    store
end

function sync!{K, V}(store::KeyStore{K, V})
    commit!(store)
    fetch!(store)
    store
end

function clearpending!{K, V}(store::KeyStore{K, V})
    empty!(store.pending)
    store
end

function clearcache!{K, V}(store::KeyStore{K, V})
    clearpending!(store)
    empty!(store.cache)
    empty!(store.age)
    store
end

function empty!{K, V}(store::KeyStore{K, V})
    if isnull(store.session)
        warn("No session.")
        return store
    end
    for object in storage(:Object, :list, store.bucket_name; session=get(store.session), fields="items(name)")
        response = storage(:Object, :delete, store.bucket_name, object[:name]; session=get(store.session), fields="")
        if iserror(response)
            error("Unable to delete object: $(response[:error][:message])")
        end
    end
    store
end

function destroy!{K, V}(store::KeyStore{K, V})
    if isnull(store.session)
        warn("No session.")
        return store
    end
    response = storage(:Bucket, :delete, store.bucket_name; session=get(store.session), fields="")
    if iserror(response)
        error("Unable to delete bucket: $(response[:error][:message])")
    end
    store.session.value = nothing
    store
end

end
