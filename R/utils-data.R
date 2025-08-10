# -------- Function to split R code into function-aware chunks --------
split_r_code <- function(code) {
  lines <- unlist(strsplit(code, "\n"))
  
  # Detect function definitions
  func_starts <- grep("^\\s*\\w+\\s*<-\\s*function\\s*\\(", lines)
  
  if (length(func_starts) == 0) {
    return(list(paste(lines, collapse = "\n")))
  }
  
  chunks <- list()
  start_idx <- 1
  
  for (i in seq_along(func_starts)) {
    func_start <- func_starts[i]
    
    # Non-function code before this function
    if (func_start > start_idx) {
      non_func_code <- lines[start_idx:(func_start - 1)]
      if (any(nzchar(trimws(non_func_code)))) {
        chunks <- append(chunks, list(paste(non_func_code, collapse = "\n")))
      }
    }
    
    # Capture full function body
    brace_count <- 0
    func_lines <- character()
    in_function <- FALSE
    
    for (j in func_start:length(lines)) {
      func_lines <- c(func_lines, lines[j])
      brace_count <- brace_count + stringr::str_count(lines[j], "\\{") - stringr::str_count(lines[j], "\\}")
      if (!in_function && grepl("\\{", lines[j])) in_function <- TRUE
      if (in_function && brace_count == 0) {
        start_idx <- j + 1
        break
      }
    }
    
    chunks <- append(chunks, list(paste(func_lines, collapse = "\n")))
  }
  
  # Any trailing code after the last function
  if (start_idx <= length(lines)) {
    trailing_code <- lines[start_idx:length(lines)]
    if (any(nzchar(trimws(trailing_code)))) {
      chunks <- append(chunks, list(paste(trailing_code, collapse = "\n")))
    }
  }
  
  chunks
}

extract_functions_from_file <- function(filepath) {
  # Read all lines of the script
  lines <- readLines(filepath, warn = FALSE)
  
  # Parse the script to get expressions
  exprs <- parse(text = lines)
  
  results <- list()
  
  for (i in seq_along(exprs)) {
    expr <- exprs[[i]]
    
    # Check if expression is an assignment <- or =
    if (is.call(expr) && (as.character(expr[[1]]) %in% c("<-", "="))) {
      lhs <- expr[[2]]
      rhs <- expr[[3]]
      
      # Check RHS is a function definition
      if (is.call(rhs)) {
        if (identical(as.character(rhs[[1]]), "function")) {
          fn_name <- as.character(lhs)
          fn_code <- paste(deparse(expr), collapse = "\n")
          
          results[[length(results) + 1]] <- list(
            function_name = fn_name,
            function_code = fn_code
          )
        }
      }
    }
  }
  
  tibble(
    function_name = map_chr(results, "function_name"),
    function_code = map_chr(results, "function_code")
  )
}