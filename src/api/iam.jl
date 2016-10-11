"""
Google Cloud Identity Access Management (IAM) API
"""
module _iam

export iam

using ..api
using ...root

"""
Google Cloud IAM API root.
"""
iam = APIRoot(
    "https://iam.googleapis.com/v1",
    Dict(
        "cloud-platform" => "Full access to all resources and services in the specified Cloud Platform project.",
    );
    ServiceAccount=APIResource("projects/{project}/serviceAccounts";
        create=APIMethod(:POST, "", "Creates a ServiceAccount and returns it."),
        delete=APIMethod(:DELETE, "{serviceAccount}", "Deletes a ServiceAccount."),
        get=APIMethod(:GET, "{serviceAccount}", "Gets a ServiceAccount."),
        getIamPolicy=APIMethod(:POST, "{serviceAccount}:getIamPolicy", "Returns the IAM access control policy for a ServiceAccount."),
        list=APIMethod(:GET, "", "Lists ServiceAccounts for a project.";
            transform=(x, t) -> map(t, get(x, :accounts, []))
        ),
        setIamPolicy=APIMethod(:POST, "{serviceAccount}:setIamPolicy", "Sets the IAM access control policy for a ServiceAccount."),
        signBlob=APIMethod(:POST, "{serviceAccount}:signBlob", "Signs a blob using a service account's system-managed private key."),
        testIamPermissions=APIMethod(:POST, "{serviceAccount}:testIamPermissions", "Tests the specified permissions against the IAM access control policy for a ServiceAccount."),
        update=APIMethod(:PUT, "{serviceAccount}", "Updates a ServiceAccount."),
    ),
    Key=APIResource("projects/{project}/serviceAccounts/{serviceAccount}/keys";
        create=APIMethod(:POST, "", "Creates a ServiceAccountKey and returns it."),
        delete=APIMethod(:DELETE, "{key}", "Deletes a ServiceAccountKey."),
        get=APIMethod(:GET, "{key}", "Gets the ServiceAccountKey by key id."),
        list=APIMethod(:GET, "", "Lists ServiceAccountKeys.";
            transform=(x, t) -> map(t, get(x, :keys, []))
        ),
    ),
    Role=APIResource("roles";
        queryGrantableRoles=APIMethod(:POST, ":queryGrantableRoles", "Queries roles that can be granted on a particular resource."),
    ),
)

end
