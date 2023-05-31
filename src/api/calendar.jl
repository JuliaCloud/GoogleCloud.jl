module Calendar

    module Calendars
        using HTTP 
        using JSON3 

        """

            get(calendar_id, key, client_id, access_token, accept = "application/json", authorization = "Bearer")  

        Returns metadata for a calendar. 

        # Arguments
        
        - `calendar_id` - Calendar identifier; if you want to access the primary calendar of the currently logged in user, assign this argument to "primary"
        - `client_id` - client identifier set-up for your GCP project
        - `access_token` - OAuth 2.0 access token for user of GCP project 
        - `accept` - what sort of payload to expect in header; default: "application/json"
        - `authorization` - authorization type; default: "Bearer"

        # Return 

        - Calendar resource with the following fields:
          - `kind` - type of the resource 
          - `etag` - Etage of the resource
          - `id` - Identifier of the calendar
          - `summary` - Title of the calendar
          - `description` - Description of the calendar
          - `location` - geographic location of the calendar as free-form text
          - `timeZone` - The time zone of the calendar (formatted as an IANA Time Zone Database name, e.g. "Europe/Zurich")
          - `conferenceProperties` - Conferencing properties for this calendar, for example what types of conferences are allowed
        """
        function get(calendar_id, key, client_id, access_token, accept = "application/json", authorization = "Bearer")

            url = "https://www.googleapis.com/calendar/v3/calendars/"

            headers = [
                        "Authorization" => "$authorization $access_token",
                        "client_id" => client_id,
                        "Accept" => accept 
                      ] 

            HTTP.get(url * calendar_id * "?key=$key", headers = headers)

        end
        
    end

    module Events 
        using HTTP 
        using JSON3 

        function get(calendar_id, event_id, key, client_id, access_token, accept = "application/json", authorization = "Bearer"; max_attendees = nothing)

            url = "https://www.googleapis.com/calendar/v3/calendars/$calendar_id/events?key=$key"

            kwarg_dict = Dict("maxAttendees" => max_attendees)

            for (k, v) in kwarg_dict
                if !isnothing(v) && !isempty(v)
                    url = url * "&$k=$v"
                end
            end

            headers = [
                        "Authorization" => "$authorization $access_token",
                        "client_id" => client_id,
                        "Accept" => accept 
                      ] 

            HTTP.get(url, headers = headers)

        end

        function list(calendar_id, key, client_id, access_token, accept = "application/json", authorization = "Bearer"; event_types = nothing, ical_uid = nothing, max_results = nothing, order_by = nothing, page_token = nothing, private_extended_property = nothing, q = nothing, shared_extended_property = nothing, show_deleted = nothing, single_events = nothing, show_hidden_invitations = nothing, sync_token = nothing, time_max = nothing, time_min = nothing, max_attendees = nothing, time_zone = nothing, updated_min = nothing)

            url = "https://www.googleapis.com/calendar/v3/calendars/$calendar_id/events?key=$key"

            kwarg_dict = Dict("eventTypes" => event_types, "iCalUID" => ical_uid, "maxAttendees" => max_attendees, "maxResults" => max_results, "orderBy" => order_by, "pageToken" => page_token, "privateExtendedProperty" => private_extended_property, "q" => q, "sharedExtendedProperty" => shared_extended_property, "showDeleted" => show_deleted, "showHiddenInvitations" => show_hidden_invitations, "singleEvents" => single_events, "syncToken" => sync_token, "timeMax" => time_max, "timeMin" => time_min, "timeZone" => time_zone, "updatedMin" => updated_min)

            for (k, v) in kwarg_dict
                if !isnothing(v) && !isempty(v)
                    url = url * "&$k=$v"
                end
            end

            headers = [
                        "Authorization" => "$authorization $access_token",
                        "client_id" => client_id,
                        "Accept" => accept 
                      ] 

            HTTP.get(url, headers = headers)

        end

        function instances(calendar_id, event_id, key, client_id, access_token, accept = "application/json", authorization = "Bearer"; max_attendees = nothing, max_results = nothing, original_start = nothing, page_token = nothing, show_deleted = nothing, time_max = nothing, time_min = nothing, time_zone = nothing)

            url = "https://www.googleapis.com/calendar/v3/calendars/$calendar_id/events/$event_id/instances?key=$key"

            kwarg_dict = Dict("maxAttendees" => max_attendees, "timeZone" => time_zone, "maxResults" => max_results, "originalStart" => original_start, "pageToken" => page_token, "showDeleted" => show_deleted, "timeMax" => time_max, "timeMin" => time_min)

            for (k, v) in kwarg_dict
                if !isnothing(v) && !isempty(v)
                    url = url * "&$k=$v"
                end
            end

            headers = [
                        "Authorization" => "$authorization $access_token",
                        "client_id" => client_id,
                        "Accept" => accept 
                      ] 

            HTTP.get(url, headers = headers)

        end
        
    end
    
end
