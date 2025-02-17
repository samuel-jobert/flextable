% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/summarizor.R
\name{fmt_avg_dev}
\alias{fmt_avg_dev}
\title{Format content for mean and sd}
\usage{
fmt_avg_dev(avg, dev, digit1 = 1, digit2 = 1)
}
\arguments{
\item{avg, dev}{mean and sd values}

\item{digit1, digit2}{number of digits to show when printing 'mean' and 'sd'.}
}
\description{
The function formats means and
standard deviations as \code{mean (sd)}.
}
\examples{
library(flextable)

df <- data.frame(avg = 1:3*3, sd = 1:3)

ft_1 <- flextable(df, col_keys = "avg")
ft_1 <- mk_par(
  x = ft_1, j = 1, part = "body",
  value = as_paragraph(fmt_avg_dev(avg = avg, dev = sd)))
ft_1 <- autofit(ft_1)
ft_1
}
\seealso{
\code{\link[=tabulator]{tabulator()}}, \code{\link[=mk_par]{mk_par()}}

Other text formatter functions: 
\code{\link{fmt_2stats}()},
\code{\link{fmt_header_n}()},
\code{\link{fmt_n_percent}()}
}
\concept{text formatter functions}
