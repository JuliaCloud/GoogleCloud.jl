module _text_service

export text_service

using ..api
using ...root


text_service = APIRoot(
  "https://{region}-aiplatform.googleapis.com/v1/projects/{project_id}",
  Dict{String,String}(
    "cloud-platform" => "Full access",
    "cloud-platform.read-only" => "Read only"
  ),
  PALM=APIResource(
    "locations/{region}/publishers/google/models",
    generate_text=APIMethod(:POST, "text-bison:predict", "Generate text from prompt"),
    generate_embedding=APIMethod(:POST, "textembedding-gecko:predict", "Generate text from prompt")
  )
)

end
