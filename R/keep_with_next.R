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
#' df = data.frame(
#' 	"Items" = c(rep("Item 1", 10), rep("Item 2", 15), rep("Item 3", 25), rep("Item 4", 5), rep("Item 5", 25)),
#' 	 "var_bidon" = seq_len(10 + 15 + 25 + 5 + 25)
#' )
#' ft = flextable(df)
#' 
#' # Set all rows keep_with_next to TRUE
#' ft = ft %>% set_keep_with_next(rows = NULL, value = TRUE)
#' # Select rows after which the break can append (all lines of an item have to be on the same page)
#' ft = ft %>% set_keep_with_next(rows = c(10, 10+15, 10+15+25, 10+15+25+5), value = FALSE)
#' 
#' doc = read_docx()
#' doc = doc %>% body_add_par("Insert lines here !")
#' doc = doc %>% body_add_flextable(ft, keepnext = TRUE, split = FALSE)
#' print(doc, target = "mon_doc.docx")

set_keep_with_next <- function(x, rows = NULL, value = TRUE) {
	stopifnot(inherits(x, "flextable"))
	rows <- get_rows_id(x$body, rows)
	x$body$styles$pars$keep_with_next[rows, ] <- value
	x
}
