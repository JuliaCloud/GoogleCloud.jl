module _text_service

export text_service, BISON_TEXT_MODEL_NAME, GEKKO_EMBEDDING_MODEL_NAME

using ..api
using ...root

const BISON_TEXT_MODEL_NAME = "text-bison"
const GEKKO_EMBEDDING_MODEL_NAME = "textembedding-gecko"


text_service = APIRoot(
  "https://{region}-aiplatform.googleapis.com/v1/projects/{project_id}",
  Dict{String,String}(
    "cloud-platform" => "Full access",
    "cloud-platform.read-only" => "Read only"
  ),
  PALM=APIResource(
    "locations/{region}/publishers/google/models/{model_name}:predict",
    predict=APIMethod(:POST, "", "Perform an online prediction.")
  )
)

end
