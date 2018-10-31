using Test 
using GoogleCloud 

creds = JSONCredentials("/secrets/google-secret.json")

session = GoogleSession(creds, ["devstorage.full_control"])

set_session!(storage, session) 

bkts = storage(:Bucket, :list)
