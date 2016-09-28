"""
Basic exceptions.
"""
module error

export CredentialError, SessionError, APIError

import Base: showerror

"""
Base error type.
"""
abstract Error <: Exception

showerror(io::IO, e::Error) = print(io, "$(typeof(e)): $(e.message)")

"""
An error in the provided credentials.
"""
type CredentialError <: Error
    message::String
    CredentialError(message::String) = new(message)
end

"""
An error in establising a session.
"""
type SessionError <: Error
    message::String
    SessionError(message::String) = new(message)
end

"""
An error from the API.
"""
type APIError <: Error
    message::String
    APIError(message::String) = new(message)
end

end
