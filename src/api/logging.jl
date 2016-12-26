"""
Google Cloud Stackdriver Logging API
"""
module _logging

export logging

using ..api
using ...root

"""
Google Cloud Stackdriver Logging API root.
"""
logging = APIRoot(
    "https://logging.googleapis.com/v2",
    Dict(
        "cloud-platform" => "View and manage your data across Google Cloud Platform services",
        "cloud-platform.read-only" => "View your data across Google Cloud Platform services",
        "logging.admin" => "Administrate log data for your projects",
        "logging.read" => "View log data for your projects",
        "logging.write" => "Submit log data for your projects",
    );
    Entry=APIResource("entries";
        list=APIMethod(:POST, ":list", "Lists log entries."),
        write=APIMethod(:POST, ":write", "Writes log entries to Stackdriver Logging."),
    ),
    MonitoredResourceDescriptor=APIResource("monitoredResourceDescriptors";
        list=APIMethod(:GET, "", "Lists the monitored resource descriptors used by Stackdriver Logging."),
    ),
    OrganizationLog=APIResource("organizations/{organization}/logs";
        delete=APIMethod(:DELETE, "{log}", "Deletes a log and all its log entries."),
    ),
    OrganizationSink=APIResource("organizations/{organization}/sinks";
        create=APIMethod(:POST, "", "Creates a sink."),
        delete=APIMethod(:DELETE, "{sink}", "Deletes a sink."),
        get=APIMethod(:GET, "{sink}", "Gets a sink."),
        list=APIMethod(:GET, "", "Lists sinks."),
        update=APIMethod(:PUT, "{sink}", "Updates or creates a sink."),
    ),
    ProjectLog=APIResource("projects/{project}/logs";
        delete=APIMethod(:DELETE, "{log}", "Deletes a log and all its log entries."),
    ),
    ProjectMetric=APIResource("projects/{project}/metrics";
        create=APIMethod(:POST, "", "Creates a logs-based metric."),
        delete=APIMethod(:DELETE, "{metric}", "Deletes a logs-based metric."),
        get=APIMethod(:GET, "{metric}", "Gets a logs-based metric."),
        list=APIMethod(:GET, "", "Lists logs-based metrics."),
        update=APIMethod(:PUT, "{metric}", "Creates or updates a logs-based metric."),
    ),
    ProjectSink=APIResource("projects/{project}/sinks";
        create=APIMethod(:POST, "", "Creates a sink."),
        delete=APIMethod(:DELETE, "{sink}", "Deletes a sink."),
        get=APIMethod(:GET, "{sink}", "Gets a sink."),
        list=APIMethod(:GET, "", "Lists sinks."),
        update=APIMethod(:PUT, "{sink}", "Updates or creates a sink."),
    ),
)

end
