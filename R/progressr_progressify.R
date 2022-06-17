#' Make map-reduce function or expression report on progress
#'
#' @param x (function or expression) A map-reduce function or expression.
#'
#' @param \ldots Not used.
#'
#' @return A tweaked version of function `x` that reports on progress
#' via the \pkg{progressr} framework.
#'
#' @examples
#' p_sapply <- progressify(sapply)
#' y <- sum(p_sapply(1:10, slow_fun))
#'
#' p_sapply <- sapply %progressify% TRUE
#' y <- sum(p_sapply(1:10, slow_fun))
#'
#' ## Base R:
#' y <- sum(progressify(sapply(1:10, slow_fun)))
#' y <- 1:10 |> progressify(sapply)(slow_fun) |> sum()
#' y <- 1:10 |> sapply(slow_fun) |> progressify() |> sum()
#' y <- 1:10 |> sapply(slow_fun) %progressify% TRUE |> sum()
#' y <- x |> map(slow_fcn) |> progressify() |> map(slow_fcn) |> progressify()
#'
#' ## magrittr:
#' y <- 1:10 %>% sapply(slow_fun) |> progressify() %>% sum()
#' y <- 1:10 |> sapply(slow_fun) %>% progressify() |> sum()
#' y <- 1:10 |> sapply(slow_fun) |> progressify() %>% sum()
#' y <- 1:10 %>% sapply(slow_fun) |> progressify() %>% sum()
#' ## To fix:
#' y <- 1:10 %>% sapply(slow_fun) %>% progressify() %>% sum()
#' y <- sapply(1:10, slow_fun) %>% progressify() |> sum()
#' y <- sapply(1:10, slow_fun) %>% progressify() |> sum()
#' y <- sapply(1:10, slow_fun) %>% progressify() %>% sum()
#' ## TO BE FIXED:
#' y <- 1:10 %>% sapply(slow_fun) %>% progressify() %>% sum()
#' y <- 1:10 %P>% sapply(slow_fun) %>% sum()
#' 
#' @export
progressify <- function(expr, ..., substitute = TRUE, envir = parent.frame()) {
  if (substitute) expr <- substitute(expr)

  ## SPECIAL CASE: Was this function called via magrittr? For example,
  ## LHS %>% progressify. If so, then figure out what the LHS expression
  ## truly is
  if ("magrittr" %in% loadedNamespaces()) {
    calls <- sys.calls()
    n <- length(calls)
    if (is.symbol(expr)) {
      if (n > 1L && as.character(expr) == ".") {
        call <- calls[[n-1L]]
        op <- call[[1]]
        if (as.character(op) == "%>%") {
          expr <- call[[2]]
#          args <- list(expr = expr, ..., substitute = FALSE, envir = envir)
#          expr <- do.call(progressify, args = args)
          expr <- bquote(progressify(.(expr), envir = .(envir)))
          expr <- as.list(expr)
          expr <- c(expr[1:2], ..., expr[3])
          expr <- as.call(expr)
          value <- eval(expr, envir = envir, enclos = baseenv())
          if (!is.language(value) && !is.symbol(value)) return(value)
        }
      }
    } else if (is.language(expr) &&
               is.symbol(e <- expr[[1]]) && as.character(e) == "%>%") {
      lhs <- expr[[2]]
      rhs <- expr[[3]]

      if (is.language(lhs)) {
        e <- bquote(progressify(.(lhs)))
        expr <- e
        value <- eval(expr, envir = envir, enclos = baseenv())
        return(value)
      }
      
      e <- rhs[[1]]
      if (is.symbol(e)) {
        e <- bquote(progressify(.(e)))
        rhs[[1]] <- e
        expr[[3]] <- rhs
        value <- eval(expr, envir = envir, enclos = baseenv())
        return(value)
      }
      
      stop("Not supported")
    }
  }

  if (is.function(expr)) {
    fcn <- progressify.function(expr, ...)
  } else if (is.symbol(expr)) {
    name <- as.character(expr)
    fcn <- get(name, mode = "function", envir = envir)
    args <- c(list(fcn), ...)
    fcn <- do.call(progressify.function, args = args)
  } else if (is.call(expr)) {
    name <- as.character(expr[[1]])
    if (name == "%>%") {
      stop("[Internal error] Not supported/should not happen: ", sQuote(name))
    }
    fcn <- get(name, mode = "function", envir = envir)
    args <- c(list(fcn), ...)
    fcn <- do.call(progressify.function, args = args)

    p_name <- sprintf("...progressr_%s", name)
    assign(p_name, fcn, envir = envir)
    expr[[1]] <- as.symbol(p_name)
    expr <- bquote({
      res <- withVisible(.(expr))
      if (exists(.(p_name))) rm(list = .(p_name))
      if (res$visible) res$value else invisible(res$value)
    })
    value <- eval(expr, envir = envir, enclos = baseenv())
    return(value)
  } else {
    stop(sprintf("Non-supported expression: %s", as.character(expr)))
  }
  stopifnot(is.function(fcn))
  fcn
}

progressify.expression <- function(expr, ...) {
}


progressify_base_functions <- local({
  ats <- c(
    apply  = 2L,
    lapply = 2L,
    sapply = 2L,
    vapply = 2L
  )
  fcns <- vector("list", length = length(ats))
  names(fcns) <- names(ats)
  ns <- getNamespace("base")
  for (name in names(ats)) {
    if (exists(name, mode = "function", envir = ns)) {
      fcns[[name]] <- get(name, mode = "function", envir = ns)
    }
  }
 
  function(fcn) {
    for (name in names(fcns)) {
      if (identical(fcn, fcns[[name]])) return(ats[[name]])
    }
    NA_integer_
  }
}) ## progressify_base_functions()


## Search for "#progressr: ..." string
find_inject <- function(expr, ats = integer(0L)) {
  if (is.character(expr)) {
    e <- expr
    pattern <- "^#progressr:[[:space:]]*"
    if (grepl(pattern, e)) {
      e <- sub(pattern, "", e)
      e <- gsub("(^[[:space:]]*|[[:space:]]*$)", "", e)
      if (e == "{here}") {
        return(structure(ats, replace = TRUE))
      }
    }
  } else if (is.call(expr)) {
    e <- expr[[1]]
    if (as.character(e) == "{") {
      for (kk in 2:length(expr)) {
        e <- expr[[kk]]
        res <- Recall(e, ats = c(ats, kk))
        if (length(res) > 0) return(res)
      }
    }
  }
  
  NULL
} ## find_inject()



#' @export
progressify.function <- function(expr, ...) {
  stopifnot(is.function(expr))
  fcn <- expr

  expr <- body(fcn)
  args <- formals(fcn)

  dots <- list(...)
  at <- dots$at
  
  X_name <- dots$X_name
  if (is.null(X_name)) X_name <- names(args)[1]
  FUN_name <- dots$FUN_name
  if (is.null(FUN_name)) FUN_name <- names(args)[2]

  X_symbol <- as.symbol(X_name)
  FUN_symbol <- as.symbol(FUN_name)

  ## Automatically identify where in the function body the
  ## progressr code should be injected
  if (is.null(at)) {
    ## Search for "#progressr: ..."    
    at <- find_inject(body(fcn))
    if (is.null(at)) {
      ## A 'base' function?
      at <- progressify_base_functions(fcn)
    }
  }

  p_expr <- bquote({
    ...p <- progressr::progressor(along = .(X_symbol))
    ...progressr_FUN <- .(FUN_symbol)
    .(FUN_symbol) <- function(...) {
      ...p()
      ...progressr_FUN(...)
    }
  })

  if (any(is.na(at))) {
    expr <- bquote({
      .(p_expr)
      .(expr)
    })
  } else {
    replace <- isTRUE(attr(at, "replace"))
    if (replace) {
      expr[[at]] <- bquote(.(p_expr))
    } else {
      expr[[at]] <- bquote({
        .(expr[[at]])
        .(p_expr)
      })
    }
  }
  
  body(fcn) <- expr

  fcn
} ## progressify.function()


#' @param lhs (expression) A map-reduce function call
#'
#' @param modifier (expression) Controls how progressifier should be applied.
#'
#' @rdname progressify
#' @export
`%progressify%` <- function(lhs, modifier) {
  lhs <- substitute(lhs)
  modifier <- substitute(modifier)
  envir <- parent.frame(1L)

  if (is.logical(modifier)) {
    if (isTRUE(modifier)) {
      e <- lhs
      if (!is.symbol(e)) e <- e[[1]]
      if (is.symbol(e)) {
        name <- as.character(e)
        fcn <- get(name, mode = "function", envir = envir)
        args <- c(list(fcn), attributes(modifier))
        fcn <- do.call(progressify, args = args)
        p_name <- sprintf("...progressr_%s", name)
        assign(p_name, fcn, envir = envir)
        p_symbol <- as.symbol(p_name)
        if (is.symbol(lhs)) {
          lhs <- p_symbol
        } else {
          lhs[[1]] <- p_symbol
        }
        lhs <- bquote({
          res <- withVisible(.(lhs))
          rm(list = .(p_name))
          if (res$visible) res$value else invisible(res$value)
        })
      } else if (is.function(e)) {
      } else {
        stop(sprintf("<%s> %%progressify%% %s is not supported",
                     mode(e), modifier))
      }
    }
  }

  eval(lhs, envir = envir, enclos = baseenv())
} ## %progressify%
