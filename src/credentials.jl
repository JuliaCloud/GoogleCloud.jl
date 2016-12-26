"""
Google Cloud Platform service-account API credentials.
"""
module credentials

export GoogleCredentials

import Base: show, print
import JSON

using ..error

"""
    GoogleCredentials(...)

Parse JSON credentials created for a service-account at
[Google Cloud Platform Console](https://console.cloud.google.com/apis/credentials)
"""
type GoogleCredentials
    account_type::String
    project_id::String
    private_key_id::String
    private_key::String
    client_email::String
    client_id::String
    auth_uri::String
    token_uri::String
    auth_provider_x509_cert_url::String
    client_x509_cert_url::String
end

"""
    GoogleCredentials(data::Dict{Symbol, String})

Initialise credentials from dictionary containing values.
"""
function GoogleCredentials(data::Dict{Symbol, String})
    fields = fieldnames(GoogleCredentials)
    fields[findfirst(fields, :account_type)] = :type  # type is a keyword!
    missing = setdiff(fields, keys(data))
    if !isempty(missing)
        info(missing)
        throw(CredentialError("Missing fields in key: ", join(missing, ", ")))
    end
    GoogleCredentials((data[field] for field in fields)...)
end

"""
    GoogleCredentials(filename)

Load credentials from a JSON file.
"""
GoogleCredentials(filename::AbstractString) = GoogleCredentials(JSON.parsefile(filename; dicttype=Dict{Symbol, String}))
GoogleCredentials(io::IO) = GoogleCredentials(JSON.parse(io; dicttype=Dict{Symbol, String}))

Base.convert(::Type{GoogleCredentials}, x::AbstractString) = GoogleCredentials(x)

function print(io::IO, x::GoogleCredentials)
    fields = [:client_id, :client_email, :account_type, :project_id]
    print(io, join(("$field: $(getfield(x, field))" for field in fields), "\n"))
end
show(io::IO, x::GoogleCredentials) = print(io, x)

end
