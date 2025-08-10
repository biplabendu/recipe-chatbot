# install and load required packages
# install devtools from CRAN
# install.packages('devtools')
# devtools::install_github("benyamindsmith/RKaggle")

library(text)
library(rchroma)
# library(RKaggle)
library(tibble)
library(dplyr)
library(purrr)

# run ChromaDB instance.
chroma_docker_run()

# Connect to a local ChromaDB instance
client <- chroma_connect()

# Check the connection
heartbeat(client)
version(client)
list_collections(client)

# Gather data -------------------------------------------------------------

code_files_path <- here::here("dev/abcd-metrics-backend/")
r_files <- list.files(code_files_path, pattern = "\\.R$", full.names = TRUE)

# # Extract functions from first file
# functions_tbl <- extract_functions_from_file(r_files[[1]])
# print(functions_tbl)

# To extract from all files and combine:
code_tbl <- purrr::map_dfr(
  r_files, 
  extract_functions_from_file
)
# saveRDS(code_tbl, here::here("dev/code_tbl.rds"))

# Read each file, split into function-aware chunks, flatten into one big list
# code_chunks <- r_files %>%
#   purrr::map(~ paste(readLines(.x, warn = FALSE), collapse = "\n")) %>%
#   purrr::map(split_r_code) %>%
#   purrr::flatten()

# chunk the dataset
chunk_size <- 1
n <- nrow(code_tbl)
r <- rep(1:ceiling(n/chunk_size),each = chunk_size)[1:n]
chunks <- split(code_tbl, r)

# #empty dataframe
# recipe_sentence_embeddings <-  data.frame(
#   recipe = character(),
#   recipe_vec_embeddings = I(list()),
#   recipe_id = character()
# )

#empty dataframe
code_sentence_embeddings <-  data.frame(
  code = character(),
  code_vec_embeddings = I(list()),
  code_id = character()
)

# create a progress bar
pb <- txtProgressBar(min = 1, max = length(code_chunks), style = 3)

## alternative using terminal ##
# source /Users/bidas/.virtualenvs/r-reticulate/bin/activate
# pip install torch numpy ....
# deactivate

# Install individual component of a pkg
# reticulate::repl_python()
## WHEN PROMPTED, ENTER THE FOLLOWING ##
# import nltk
# nltk.download('punkt_tab')


# embedding data
for (i in 1:length(code_chunks)) {
# for (i in 1:10) {
  code <- as.character(code_chunks[i])
  code_id <- paste0("code",i)
  code_embeddings <- textEmbed(as.character(code),
                                 layers = 10:11,
                                 aggregation_from_layers_to_tokens = "concatenate",
                                 aggregation_from_tokens_to_texts = "mean",
                                 keep_token_embeddings = FALSE,
                                 batch_size = 1
  )

  # convert tibble to vector
  code_vec_embeddings <- unlist(code_embeddings, use.names = FALSE)
  code_vec_embeddings <- list(code_vec_embeddings)

  # Append the current chunk's data to the dataframe
  code_sentence_embeddings <- code_sentence_embeddings %>%
    add_row(
      code = code,
      code_vec_embeddings = code_vec_embeddings,
      code_id = code_id
    )

  # track embedding progress
  setTxtProgressBar(pb, i)

}


# Save embeddings
saveRDS(code_sentence_embeddings, here::here("dev/abcd-metrics-backend_functions.rds"))


# # Create progress bar
# pb <- txtProgressBar(min = 1, max = length(code_chunks), style = 3)
# 
# # -------- Embed each chunk --------
# code_sentence_embeddings <- purrr::imap_dfr(
#   code_chunks[1:3],
#   # code_chunks,
#   function(chunk, i) {
#     code <- as.character(chunk)
#     code_id <- paste0("code_chunk_", i)
#     
#     code_embeddings <- textEmbed(
#       code,
#       layers = 10:11,
#       aggregation_from_layers_to_tokens = "concatenate",
#       aggregation_from_tokens_to_texts = "mean",
#       keep_token_embeddings = FALSE,
#       batch_size = 1
#     )
#     
#     code_vec_embeddings <- list(unlist(code_embeddings, use.names = FALSE))
#     
#     setTxtProgressBar(pb, i)
#     
#     tibble(
#       code = code,
#       code_vec_embeddings = code_vec_embeddings,
#       code_id = code_id
#     )
#   }
# )
# 
# close(pb)

# Create a new collection in Chroma
create_collection(client, "abcd-metrics-backend_functions")

# Load embeddings ---------------------------------------------------------

code_sentence_embeddings <- readRDS(
  "dev/abcd-metrics-backend_functions.rds"
)

# Add documents to the collection
add_documents(
  client,
  "abcd-metrics-backend_functions",
  documents = code_sentence_embeddings$code,
  ids = code_sentence_embeddings$code_id,
  embeddings = code_sentence_embeddings$code_vec_embeddings
)



# READINGS: ---------------------------------------------------------------
# 1. https://ajsw.info/resources/r-openmp-veclib-on-apple-silicon
# 2. https://developer.apple.com/documentation/accelerate/veclib
# 3. https://github.com/dselivanov/rsparse?tab=readme-ov-file
