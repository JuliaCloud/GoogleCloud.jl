"""
Basic exceptions.
"""
module error

export CredentialError, SessionError, APIError

import Base: showerror

using Compat

"""
Base error type.
"""
@compat abstract type Error <: Exception end

showerror(io::IO, e::Error) = print(io, "$(typeof(e)): $(e.message)")

"""
An error in the provided credentials.
"""
type CredentialError <: Error
    message::String
    CredentialError(message::AbstractString) = new(message)
end

"""
An error in establising a session.
"""
type SessionError <: Error
    message::String
    SessionError(message::AbstractString) = new(message)
end

"""
An error from the API.
"""
type APIError <: Error
    message::String
    APIError(message::AbstractString) = new(message)
end

end
