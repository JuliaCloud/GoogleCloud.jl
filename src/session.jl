"""
OAuth 2.0 Google Sessions
"""
module session

export GoogleSession, authorize

import Base: string, print, show
using Base.Dates
using Requests
import JSON
import MbedTLS

using ..error
using ..credentials
using ..root

"""
    SHA256withRSA(message, key)

Sign message using private key with RSASSA-PKCS1-V1_5-SIGN algorithm.
"""
function SHA256withRSA(message, key)
    # load up the key context
    ctx = MbedTLS.PKContext()
    #MbedTLS.parse_key!(ctx, key)
    ccall((:mbedtls_pk_parse_key, MbedTLS.MBED_CRYPTO), Cint,
        (Ptr{Void}, Ptr{Cuchar}, Csize_t, Ptr{Cuchar}, Csize_t),
        ctx.data, key, sizeof(key) + 1, C_NULL, 0
    )

    # sign the message digest
    output = Vector{UInt8}(Int64(ceil(MbedTLS.bitlength(ctx) / 8)))
    MbedTLS.sign!(ctx, MbedTLS.MD_SHA256,
        MbedTLS.digest(MbedTLS.MD_SHA256, message),
        output, MbedTLS.MersenneTwister(0)
    )

    String(output)
end

"""
GoogleSession(...)

OAuth 2.0 session for Google using provided credentials.

Caches authorisation tokens up to expiry.

```julia
sess = GoogleSession(GoogleCredentials(expanduser("~/auth.json")), ["devstorage.full_control"])
```
"""
type GoogleSession
    credentials::GoogleCredentials
    scopes::Vector{String}
    authorization::Dict{Symbol, Any}
    expiry::DateTime
    """
        GoogleSession(credentials, scopes)

    Set up session with credentials and OAuth scopes.
    """
    function GoogleSession(credentials::GoogleCredentials, scopes::Vector{String})
        scopes = [isurl(scope) ? scope : "$SCOPE_ROOT/$scope" for scope in scopes]
        new(credentials, scopes, Dict{String, String}(), 0)
    end
end
GoogleSession(filename::AbstractString, args...) = GoogleSession(GoogleCredentials(filename), args...)

function print(io::IO, x::GoogleSession)
    println(io, "scopes: $(x.scopes)")
    println(io, "authorization: $(x.authorization)")
    println(io, "expiry: $(x.expiry)")
end
show(io::IO, x::GoogleSession) = print(io, x)

"""
    unixseconds(x)

Convert date-time into unix seconds.
"""
unixseconds(x::DateTime) = datetime2unix(trunc(x, Second))

"""
    JWTHeader

JSON Web Token header.
"""
type JWTHeader
    algorithm::String
end
function string(x::JWTHeader)
    base64encode(JSON.json(Dict(:alg => x.algorithm, :typ => "JWT")))
end
print(io::IO, x::JWTHeader) = print(io, string(x))

"""
    JWTClaimSet

JSON Web Token claim-set.
"""
type JWTClaimSet
    issuer::String
    scopes::Vector{String}
    assertion::DateTime
    expiry::DateTime
    function JWTClaimSet{S <: AbstractString}(issuer::AbstractString, scopes::Vector{S},
        assertion::DateTime=now(UTC), expiry::DateTime=now(UTC) + Hour(1))
        new(issuer, scopes, assertion, expiry)
    end
end
function string(x::JWTClaimSet)
    base64encode(JSON.json(Dict(
        :iss => x.issuer, :scope => join(x.scopes, " "), :aud => AUD_ROOT,
        :iat => Int64(unixseconds(x.assertion)),
        :exp => Int64(unixseconds(x.expiry))
    )))
end
print(io::IO, x::JWTClaimSet) = print(io, string(x))

"""
    JWS(credentials, claimset)

Construct the Base64-encoded JSON Web Signature based on the JWT header, claimset
and signed using the private key provided in the Google JSON service-account key.
"""
function JWS(credentials::GoogleCredentials, claimset::JWTClaimSet, header::JWTHeader=JWTHeader("RS256"))
    payload = "$header.$claimset"
    signature = base64encode(SHA256withRSA(payload, credentials.private_key))
    "$payload.$signature"
end

"""
    authorize(session[; cache=true)

Get OAuth 2.0 authorisation token from Google.

If `cache` set to `true`, get a new token only if the existing token has not
expired.
"""
function authorize(session::GoogleSession; cache=true)
    # don't get a new token if a non-expired one exists
    if cache && (session.expiry > now(UTC) + Second(5)) && !isempty(session.authorization)
        return session.authorization
    end

    # construct claim-set from service account email and requested scopes
    claimset = JWTClaimSet(session.credentials.client_email, session.scopes)
    data = Requests.format_query_str(Dict{Symbol, String}(
        :grant_type => "urn:ietf:params:oauth:grant-type:jwt-bearer",
        :assertion => JWS(session.credentials, claimset)
    ))
    headers = Dict{String, String}("Content-Type" => "application/x-www-form-urlencoded")
    res = Requests.post("$AUD_ROOT"; data=data, headers=headers)

    # check if request successful
    if statuscode(res) != 200
        session.authorization = typeof(session.authorization)()
        session.expiry = 0
        throw(SessionError("Unable to obtain authorization: $(readall(res))"))
    end

    authorization = Requests.json(res; dicttype=Dict{Symbol, Any})

    # cache authorization if required
    if cache
        session.expiry = claimset.expiry
        session.authorization = authorization
    else
        session.expiry = 0
        session.authorization = typeof(session.authorization)()
    end
    authorization
end

end
