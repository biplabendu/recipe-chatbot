# install and load required packages
# install devtools from CRAN
# install.packages('devtools')
# devtools::install_github("benyamindsmith/RKaggle")

library(text)
library(rchroma)
library(RKaggle)
library(dplyr)

# run ChromaDB instance.
chroma_docker_run()

# Connect to a local ChromaDB instance
client <- chroma_connect()

# Check the connection
heartbeat(client)
version(client)


# Create a new collection
create_collection(client, "recipes_collection")

# # List all collections
# list_collections(client)
# 
# # Download and read the "recipe" dataset from Kaggle
# recipes_list <- RKaggle::get_dataset("thedevastator/better-recipes-for-a-better-life")
# 
# # extract the first tibble
# recipes_df <- recipes_list[[1]]
# 
# # convert to dataframe and drop the first column
# recipes_df <- as.data.frame(recipes_df[, -1])
# 
# # drop unnecessary columns
# cleaned_recipes_df <- subset(recipes_df, select = -c(yield,rating,url,cuisine_path,nutrition,timing,img_src))
# 
# ## Replace NA values dynamically based on conditions
# # Replace NA when all columns have NA values
# cols_to_modify <- c("prep_time", "cook_time", "total_time")
# cleaned_recipes_df[cols_to_modify] <- lapply(
#   cleaned_recipes_df[cols_to_modify],
#   function(x, df) {
#     # Replace NA in prep_time and cook_time where both are NA
#     replace(x, is.na(df$prep_time) & is.na(df$cook_time), "unknown")
#   },
#   df = cleaned_recipes_df  
# )
# 
# # Replace NA when either or columns have NA values
# cleaned_recipes_df <- cleaned_recipes_df %>%
#   mutate(
#     prep_time = case_when(
#       # If cook_time is present but prep_time is NA, replace with "no preparation required"
#       !is.na(cook_time) & is.na(prep_time) ~ "no preparation required",
#       # Otherwise, retain original value
#       TRUE ~ as.character(prep_time)
#     ),
#     cook_time = case_when(
#       # If prep_time is present but cook_time is NA, replace with "no cooking required"
#       !is.na(prep_time) & is.na(cook_time) ~ "no cooking required",
#       # Otherwise, retain original value
#       TRUE ~ as.character(cook_time)
#     )
#   )
# 
# # chunk the dataset
# chunk_size <- 1
# n <- nrow(cleaned_recipes_df)
# r <- rep(1:ceiling(n/chunk_size),each = chunk_size)[1:n]
# chunks <- split(cleaned_recipes_df,r)
# 
# #empty dataframe
# recipe_sentence_embeddings <-  data.frame(
#   recipe = character(),
#   recipe_vec_embeddings = I(list()),
#   recipe_id = character()
# )
# 
# # create a progress bar
# pb <- txtProgressBar(min = 1, max = length(chunks), style = 3)
# 
# 
# # INSTALL PYTHON pkgs
# reticulate::py_install(
#   c(
#     "numpy", 
#     "torch", 
#     "huggingface_hub", 
#     "transformers", 
#     "nltk"
#   ), 
#   envname = "/Users/bidas/.virtualenvs/r-reticulate", 
#   method = "virtualenv"
# )
# 
# ## alternative using terminal ##
# # source /Users/bidas/.virtualenvs/r-reticulate/bin/activate
# # pip install torch numpy ....
# # deactivate
# 
# # Install individual component of a pkg
# # reticulate::repl_python()
# ## WHEN PROMPTED, ENTER THE FOLLOWING ##
# # import nltk
# # nltk.download('punkt_tab')
# 
# 
# # embedding data
# for (i in 1:length(chunks)) {
# # for (i in 1:10) {
#   recipe <- as.character(chunks[i])
#   recipe_id <- paste0("recipe",i)
#   recipe_embeddings <- textEmbed(as.character(recipe),
#                                  layers = 10:11,
#                                  aggregation_from_layers_to_tokens = "concatenate",
#                                  aggregation_from_tokens_to_texts = "mean",
#                                  keep_token_embeddings = FALSE,
#                                  batch_size = 1
#   )
#   
#   # convert tibble to vector
#   recipe_vec_embeddings <- unlist(recipe_embeddings, use.names = FALSE)
#   recipe_vec_embeddings <- list(recipe_vec_embeddings)
#   
#   # Append the current chunk's data to the dataframe
#   recipe_sentence_embeddings <- recipe_sentence_embeddings %>%
#     add_row(
#       recipe = recipe,
#       recipe_vec_embeddings = recipe_vec_embeddings,
#       recipe_id = recipe_id
#     )
#   
#   # track embedding progress
#   setTxtProgressBar(pb, i)
#   
# }
# 
# saveRDS(
#   recipe_sentence_embeddings,
#   "dev/rse.rds"
# )


# Load embeddings ---------------------------------------------------------

recipe_sentence_embeddings <- readRDS(
  "dev/rse.rds"
)

# Add documents to the collection
add_documents(
  client,
  "recipes_collection",
  documents = recipe_sentence_embeddings$recipe,
  ids = recipe_sentence_embeddings$recipe_id,
  embeddings = recipe_sentence_embeddings$recipe_vec_embeddings
)



# READINGS: ---------------------------------------------------------------
# 1. https://ajsw.info/resources/r-openmp-veclib-on-apple-silicon
# 2. https://developer.apple.com/documentation/accelerate/veclib
# 3. https://github.com/dselivanov/rsparse?tab=readme-ov-file
