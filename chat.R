# Load required packages
library(ellmer)
library(text)
library(rchroma)
library(shinychat)

ui <- bslib::page_fluid(
  chat_ui("chat")
)

server <- function(input, output, session) {
  # Connect to a local ChromaDB instance running on docker with embeddings loaded 
  client <- chroma_connect()
  
  # sentence embeddings function and query
  question <- function(sentence){
    sentence_embeddings <- textEmbed(
      sentence,
      layers = 10:11,
      aggregation_from_layers_to_tokens = "concatenate",
      aggregation_from_tokens_to_texts = "mean",
      keep_token_embeddings = FALSE
    )
    # convert tibble to vector
    sentence_vec_embeddings <- unlist(
      sentence_embeddings, 
      use.names = FALSE
    )
    sentence_vec_embeddings <- list(
      sentence_vec_embeddings
    )
    # Query similar documents
    results <- query(
      client,
      "recipes_collection",
      query_embeddings = sentence_vec_embeddings,
      n_results = 2
    )
    # output results
    results
  }
  
  # function that provides context
  tool_context  <- tool(
    question,
    "obtains the right context for a given question",
    sentence = type_string()
    
  )
  
  #  Initialize the chat system 
  chat <- chat_ollama(
    system_prompt = "You are a knowledgeable culinary assistant specializing in recipe recommendations. 
                      You provide tailored meal suggestions based on the user's available ingredients and the desired amount of food or servings.
                      Ensure the recipes align closely with the user's inputs and yield the expected quantity.",
    model = "llama3.2:3b-instruct-q4_K_M"
    # model = "smollm2:1.7b-instruct-q4_K_M"
  )
  #register tool
  chat$register_tool(tool_context)
  
  observeEvent(input$chat_user_input, {
    stream <- chat$stream_async(input$chat_user_input)
    chat_append("chat", stream)
  })
}

shiny::shinyApp(ui, server)
