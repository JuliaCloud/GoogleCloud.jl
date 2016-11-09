"""
Google Pub/Sub API
"""
module _pubsub

export pubsub

using ..api
using ...root

"""
Google Pub/Sub API root.
"""
pubsub = APIRoot(
    "https://pubsub.googleapis.com/v1/projects/{project}",
    Dict(
        "cloud-platform" => "Full access to all resources and services in the specified Cloud Platform project.",
        "pubsub" => "View and manage Pub/Sub topics and subscriptions",
    );
    Subscription=APIResource("subscriptions";
        acknowledge=APIMethod(:POST, "{subscription}:acknowledge", "Acknowledges the messages associated with the ack_ids in the AcknowledgeRequest."),
        create=APIMethod(:PUT, "{subscription}", "Creates a subscription to a given topic."),
        delete=APIMethod(:DELETE, "{subscription}", "Deletes an existing subscription."),
        get=APIMethod(:GET, "{subscription}", "Gets the configuration details of a subscription."),
        getIamPolicy=APIMethod(:GET, "{subscription}:getIamPolicy", "Gets the access control policy for a resource."),
        list=APIMethod(:GET, "", "Lists matching subscriptions."),
        modifyAckDeadline=APIMethod(:POST, "{subscription}:modifyAckDeadline", "Modifies the ack deadline for a specific message."),
        modifyPushConfig=APIMethod(:POST, "{subscription}:modifyPushConfig", "Modifies the PushConfig for a specified subscription."),
        pull=APIMethod(:POST, "{subscription}:pull", "Pulls messages from the server."),
        setIamPolicy=APIMethod(:POST, "{subscription}:setIamPolicy", "Sets the access control policy on the specified resource."),
        testIamPermissions=APIMethod(:POST, "{subscription}:testIamPermissions", "Returns permissions that a caller has on the specified resource."),
    ),
    Topic=APIResource("topics";
        create=APIMethod(:PUT, "{topic}", "Creates the given topic with the given name."),
        delete=APIMethod(:DELETE, "{topic}", "Deletes the topic with the given name."),
        get=APIMethod(:GET, "{topic}", "Gets the configuration of a topic."),
        getIamPolicy=APIMethod(:GET, "{topic}:getIamPolicy", "Gets the access control policy for a resource."),
        list=APIMethod(:GET, "", "Lists matching topics."),
        publish=APIMethod(:POST, "{topic}:publish", "Adds one or more messages to the topic."),
        setIamPolicy=APIMethod(:POST, "{topic}:setIamPolicy", "Sets the access control policy on the specified resource."),
        testIamPermissions=APIMethod(:POST, "{topic}:testIamPermissions", "Returns permissions that a caller has on the specified resource."),
    ),
    TopicSubscription=APIResource("topics/{topic}/subscriptions";
        list=APIMethod(:GET, "", "Lists the name of the subscriptions for this topic."),
    ),
)

end
