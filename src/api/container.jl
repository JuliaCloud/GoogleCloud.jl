"""
Google Cloud Container Engine API
"""
module _container

export container

using ..api
using ...root

"""
Google Cloud Container Engine API root.
"""
container = APIRoot(
    "https://container.googleapis.com/v1/projects/{project}/zones/{zone}",
    Dict(
        "cloud-platform" => "Full access to all resources and services in the specified Cloud Platform project.",
    );
    ServerConfig=APIResource("";
        getServerconfig=APIMethod(:GET, "serverconfig", "Returns configuration info about the Container Engine service."),
    ),
    Cluster=APIResource("clusters";
        create=APIMethod(:POST, "", "Creates a cluster, consisting of the specified number and type of Google Compute Engine instances."),
        delete=APIMethod(:DELETE, "{cluster}", "Deletes the cluster, including the Kubernetes endpoint and all worker nodes."),
        get=APIMethod(:GET, "{cluster}", "Gets the details of a specific cluster."),
        list=APIMethod(:GET, "", "Lists all clusters owned by a project in either the specified zone or all zones."),
        update=APIMethod(:PUT, "{cluster}", "Updates the settings of a specific cluster."),
    ),
    NodePool=APIResource("clusters/{cluster}/nodePools";
        create=APIMethod(:POST, "", "Creates a node pool for a cluster."),
        delete=APIMethod(:DELETE, "{nodePool}", "Deletes a node pool from a cluster."),
        get=APIMethod(:GET, "{nodePool}", "Retrieves the node pool requested."),
        list=APIMethod(:GET, "", "Lists the node pools for a cluster."),
    ),
    Operation=APIResource("operations";
        get=APIMethod(:GET, "{operation}", "Gets the specified operation."),
        list=APIMethod(:GET, "", "Lists all operations in a project in a specific zone or all zones."),
    ),
)

end
