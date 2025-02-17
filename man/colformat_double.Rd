% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/formatters.R
\name{colformat_double}
\alias{colformat_double}
\title{Format numeric cells}
\usage{
colformat_double(
  x,
  i = NULL,
  j = NULL,
  big.mark = get_flextable_defaults()$big.mark,
  decimal.mark = get_flextable_defaults()$decimal.mark,
  digits = get_flextable_defaults()$digits,
  na_str = get_flextable_defaults()$na_str,
  nan_str = get_flextable_defaults()$nan_str,
  prefix = "",
  suffix = ""
)
}
\arguments{
\item{x}{a flextable object}

\item{i}{rows selection}

\item{j}{columns selection.}

\item{big.mark, digits, decimal.mark}{see \code{\link[=formatC]{formatC()}}}

\item{na_str, nan_str}{string to be used for NA and NaN values}

\item{prefix, suffix}{string to be used as prefix or suffix}
}
\description{
Format numeric cells in a flextable.
}
\examples{
dat <- mtcars
ft <- flextable(head(dat))
ft <- colformat_double(
  x = ft,
  big.mark = ",", digits = 2, na_str = "N/A"
)
autofit(ft)
}
\seealso{
Other cells formatters: 
\code{\link{colformat_char}()},
\code{\link{colformat_datetime}()},
\code{\link{colformat_date}()},
\code{\link{colformat_image}()},
\code{\link{colformat_int}()},
\code{\link{colformat_lgl}()},
\code{\link{colformat_num}()},
\code{\link{set_formatter}()}
}
\concept{cells formatters}
