"""
OAuth 2.0 Google Sessions
"""
module session

export GoogleSession, authorize

import Base: string, print, show
using Dates, Base64 

#using Requests
using HTTP, HTTP.Messages 

import JSON
import MbedTLS

using ..error
using ..credentials
using ..root

"""
    SHA256withRSA(message, key)

Sign message using private key with RSASSA-PKCS1-V1_5-SIGN algorithm.
"""
SHA256withRSA(message, key::MbedTLS.PKContext) = MbedTLS.sign(key, MbedTLS.MD_SHA256,
    MbedTLS.digest(MbedTLS.MD_SHA256, message), MbedTLS.MersenneTwister(0)
)

"""
GoogleSession(...)

OAuth 2.0 session for Google using provided credentials.

Caches authorisation tokens up to expiry.

```julia
sess = GoogleSession(JSONCredentials(expanduser("~/auth.json")), ["devstorage.full_control"])
```
"""
mutable struct GoogleSession{T <: Credentials}
    credentials::T
    scopes::Vector{String}
    authorization::Dict{Symbol, Any}
    expiry::DateTime
    """
        GoogleSession(credentials, scopes)

    Set up session with credentials and OAuth scopes.
    """
    function GoogleSession(credentials::T, scopes::AbstractVector{<: AbstractString}) where {T <: Credentials}
        scopes = [isurl(scope) ? scope : "$SCOPE_ROOT/$scope" for scope in scopes]
        new{T}(credentials, scopes, Dict{String, String}(), DateTime(1))
    end
end

function GoogleSession(credentials::Union{AbstractString, Nothing},
                       scopes::AbstractVector{<: AbstractString}=String[])
    if credentials === nothing
        credentials = ""
    end
    if isfile(credentials)
        credentials = JSONCredentials(credentials)
    else
        if isempty(credentials)
            credentials = MetadataCredentials()
        elseif isurl(credentials)
            credentials = MetadataCredentials(; url=credentials)
        else
            throw(CredentialError("Invalid credentials: ", credentials))
        end
        scopes = intersect(scopes, credentials.scopes)
    end
    GoogleSession(credentials, scopes)
end

function GoogleSession(scopes::AbstractVector{<: AbstractString})
    GoogleSession(get(ENV, "GOOGLE_APPLICATION_CREDENTIALS", ""), scopes)
end

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
unixseconds(x::DateTime) = trunc(Int, datetime2unix(x))

"""
    JWTHeader

JSON Web Token header.
"""
struct JWTHeader
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
struct JWTClaimSet
    issuer::String
    scopes::Vector{String}
    assertion::DateTime
    expiry::DateTime
    function JWTClaimSet(issuer::AbstractString, scopes::AbstractVector{<: AbstractString},
                         assertion::DateTime=now(UTC), expiry::DateTime=now(UTC) + Hour(1))
        new(issuer, scopes, assertion, expiry)
    end
end
function string(x::JWTClaimSet)
    base64encode(JSON.json(Dict(
        :iss => x.issuer, :scope => join(x.scopes, " "), :aud => AUD_ROOT,
        :iat => unixseconds(x.assertion),
        :exp => unixseconds(x.expiry)
    )))
end
print(io::IO, x::JWTClaimSet) = print(io, string(x))

"""
    JWS(credentials, claimset)

Construct the Base64-encoded JSON Web Signature based on the JWT header, claimset
and signed using the private key provided in the Google JSON service-account key.
"""
function JWS(credentials::JSONCredentials, claimset::JWTClaimSet, header::JWTHeader=JWTHeader("RS256"))
    payload = "$header.$claimset"
    signature = base64encode(SHA256withRSA(payload, credentials.private_key))
    "$payload.$signature"
end

function token(credentials::JSONCredentials, 
               scopes::AbstractVector{<: AbstractString})
    # construct claim-set from service account email and requested scopes
    claimset = JWTClaimSet(credentials.client_email, scopes)
    data = HTTP.URIs.escapeuri(Dict{Symbol, String}(
        :grant_type => "urn:ietf:params:oauth:grant-type:jwt-bearer",
        :assertion => JWS(credentials, claimset)
    ))
    headers = Dict{String, String}(
                        "Content-Type" => "application/x-www-form-urlencoded")
    res = HTTP.post("$AUD_ROOT", headers, data)
    if res.status != 200
        throw(SessionError("Unable to obtain authorization: $(read(res, String))"))
    end
    authorization = JSON.parse(payload(res, String); dicttype=Dict{Symbol, Any})
    authorization, claimset.assertion
end

function token(credentials::MetadataCredentials, ::AbstractVector{<: AbstractString})
    assertion = now(UTC)
    authorization = JSON.parse(get(credentials, "token"); dicttype=Dict{Symbol, Any})
    authorization, assertion
end

"""
    authorize(session; cache=true)

Get OAuth 2.0 authorisation token from Google.

If `cache` set to `true`, get a new token only if the existing token has expired.
"""
function authorize(session::GoogleSession; cache::Bool=true)
    # don't get a new token if a non-expired one exists
    if cache && (session.expiry >= now(UTC)) && !isempty(session.authorization)
        return session.authorization
    end

    authorization, assertion = try token(session.credentials, session.scopes) catch e
        session.expiry = DateTime(1)
        empty!(session.authorization)
        rethrow(e)
    end

    # cache authorization if required
    if cache
        session.expiry = assertion + Second(authorization[:expires_in] - 30)
        session.authorization = authorization
    else
        session.expiry = DateTime(1)
        empty!(session.authorization)
    end
    authorization
end

end
