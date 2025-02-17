% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/borders.R
\name{before}
\alias{before}
\title{Is an element before a match with entries}
\usage{
before(x, entries)
}
\arguments{
\item{x}{an atomic vector of values to be tested}

\item{entries}{a sequence of items to be searched in \code{x}.}
}
\description{
return a logical vector of the same length as x, indicating
if elements are located before a set of entries to match or not.
}
\examples{
library(flextable)
library(officer)

dat <- data.frame(
  stringsAsFactors = FALSE,
  check.names = FALSE,
  Level = c("setosa", "versicolor", "virginica", "<NA>", "Total"),
  Freq = as.integer(c(50, 50, 50, 0, 150)),
  `\% Valid` = c(100/3,
                100/3,100/3,NA,100),
  `\% Valid Cum.` = c(100/3, 100*2/3, 100, NA, 100),
  `\% Total` = c(100/3,
                100/3,100/3,0,100),
  `\% Total Cum.` = c(100/3,
                     100*2/3,100,100,100)
)

ft <- flextable(dat)
ft <- hline(ft, i = ~ before(Level, "Total"),
            border = fp_border_default(width = 2))
ft
}
\seealso{
\code{\link[=hline]{hline()}}
}
