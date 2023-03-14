#' @export
#' @title Tag the row(s) of FT table as keep with next.
#' In word table, the tagged row will be attached to the next row's first line
#' in case of page break
#' It overrides the value passed to body_add_flextable keep_with_next parameter
#' @param x the FT table
#' @param rows single value or vector of values representing the rows which paragraphs will be marked as keep with next
#' Value of rows is integer (row number) or character (row name)
#' Can be a logical vector of same length as number of rows of the table
#' @param value Logical. TRUE will keep the row attached to the following row's first paragraph in case of page break.
#' @examples
#' ft = flextable(mtcars[1:5, 1:3])
#' ft = ft %>% set_keep_with_next(rows = c(1:2), value = TRUE)
#' doc = read_docx()
#' doc = doc %>% body_add_flextable(keep_with_next = FALSE, split = FALSE)
#' print(doc, target = "my_doc_with_kn.docx")
set_keep_with_next <- function(x, rows, value = TRUE) {
	stopifnot(inherits(x, "flextable"))
	rows <- get_rows_id(x$body, rows)
	x$body$styles$pars$keep_with_next[rows, ] <- value
	x
}
