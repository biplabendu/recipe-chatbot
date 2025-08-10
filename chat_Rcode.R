# Load required packages
library(ellmer)
library(text)
library(rchroma)
library(shinychat)

ui <- bslib::page_fluid(
  chat_ui("chat")
)

server <- function(input, output, session) {
  tbl <- readRDS(here::here("dev/code_tbl.rds"))
  
  # Convert table to string: each function on its own, code wrapped in triple backticks to preserve formatting
  tbl_lines <- purrr::map2_chr(tbl$function_name, tbl$function_code, function(name, code) {
    paste0(
      "- **", name, "**:\n\n",
      "```r\n",
      code,
      "\n```\n"
    )
  })
  tbl_string <- paste(tbl_lines, collapse = "\n")
  
  chat <- chat_ollama(
    system_prompt = "
You are a knowledgeable R coding assistant.
When answering a user query, use the following rules:
- Search the function_code column for the most relevant functions.
- For the most relevant function(s) found, produce a concise bullet-point 
  summary explaining what the function's code does, its purpose, and any key 
  variables involved.
- Focus on explaining the actual function code, not just its name or signature.
- If no relevant code is found, clearly state that nothing matches in the dataset and ask for clarification.
- Use markdown formatting to display info and keep it brief
Output format:
1. 'Summary:' followed by bullet points explaining the function code
",
    # model = "llama3.2:3b-instruct-q4_K_M"
    model = "smollm2:1.7b"
  )
  
  observeEvent(input$chat_user_input, {
    user_input_with_context <- paste(
      "\n\nUse the following data, one per row function, as context:\n\n",
      tbl_string,
      "\n\n",
      "\n\nAccording to the `function_code` column, explain:\n\n",
      input$chat_user_input,
      "\n\nIMPORTANT:\n\n",
      "DO NOT MAKE UP new code or invent details that are not present in the user-provided context.
      D0 NOT MAKE MISTAKES!"
    )
    stream <- chat$stream_async(user_input_with_context)
    chat_append("chat", stream)
  })
}


shiny::shinyApp(ui, server)
