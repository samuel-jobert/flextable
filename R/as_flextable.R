#' @title Method to transform objects into flextables
#' @description This is a convenient function
#' to let users create flextable bindings
#' from any objects. Users should consult documentation
#' of corresponding method to understand the details and
#' see what arguments can be used.
#' @param x object to be transformed as flextable
#' @param ... arguments for custom methods
#' @export
#' @family as_flextable methods
as_flextable <- function( x, ... ){
  UseMethod("as_flextable")
}


#' @title Add row separators to grouped data
#'
#' @description Repeated consecutive values of group columns will
#' be used to define the title of the groups and will
#' be added as a row title.
#'
#' @param x dataset
#' @param groups columns names to be used as row separators.
#' @param columns columns names to keep
#' @param expand_single if FALSE, groups with only one
#' row will not be expanded with a title row. If TRUE (the
#' default), single row groups and multi-row groups are all
#' restructured.
#' @examples
#' # as_grouped_data -----
#' library(data.table)
#' CO2 <- CO2
#' setDT(CO2)
#' CO2$conc <- as.integer(CO2$conc)
#'
#' data_co2 <- dcast(CO2, Treatment + conc ~ Type,
#'   value.var = "uptake", fun.aggregate = mean)
#' data_co2
#' data_co2 <- as_grouped_data(x = data_co2, groups = c("Treatment"))
#' data_co2
#' @seealso [as_flextable.grouped_data()]
#' @export
as_grouped_data <- function( x, groups, columns = NULL, expand_single = TRUE){

  if( inherits(x, "data.table") || inherits(x, "tbl_df") || inherits(x, "tbl") || is.matrix(x) )
    x <- as.data.frame(x, stringsAsFactors = FALSE)

  stopifnot(is.data.frame(x), ncol(x) > 0 )

  if(is.null(columns))
    columns <- setdiff(names(x), groups)

  z <- x[, c(groups, columns), drop = FALSE]
  setDT(z)

  z[, c("rleid"):= list(do.call(rleid, as.list(.SD))), .SDcols = groups]
  z <- merge(
    z,
    z[, list(rlen = .N), by = "rleid"],
    by = "rleid")

  subsets <- list()
  for (grp_i in seq_along(groups)) {
    grp_comb <- groups[seq_len(grp_i)]
    if (!expand_single) {
      subdat <- unique(z[z$rlen>1, .SD, .SDcols = c(grp_comb, "rleid")], by = "rleid")
    } else {
      subdat <- unique(z[, .SD, .SDcols = c(grp_comb, "rleid")], by = "rleid")
    }
    subdat[, c("rleid") := list(.SD$rleid - 1 + grp_i*.1 )]
    void_cols <- setdiff(colnames(subdat), c(groups[grp_i], "rleid"))
    if (length(void_cols)) {
      subdat[, c(void_cols) := lapply(.SD, function(w) {w[] <- NA;w} ), .SDcols = void_cols]
    }
    subsets[[length(subsets) + 1]] <- subdat
  }

  if (!expand_single) {
    z[z$rlen>1, c(groups) := lapply(.SD, function(w) {w[] <- NA;w} ), .SDcols = groups]
  } else {
    z[, c(groups) := lapply(.SD, function(w) {w[] <- NA;w} ), .SDcols = groups]
  }
  z$rlen <- NULL

  subsets[[length(subsets) + 1]] <- z

  x <- rbindlist(subsets, use.names = TRUE, fill = TRUE)
  setorderv(x, cols = "rleid")
  x$rleid <- NULL
  setDF(x)
  class(x) <- c("grouped_data", class(x))
  attr(x, "groups") <- groups
  attr(x, "columns") <- columns
  x
}

#' @export
#' @title Transform a 'grouped_data' object into a flextable
#' @description Produce a flextable from a table
#' produced by function [as_grouped_data()].
#' @param x 'grouped_data' object to be transformed into a "flextable"
#' @param col_keys columns names/keys to display. If some column names are not in
#' the dataset, they will be added as blank columns by default.
#' @param hide_grouplabel if TRUE, group label will not be rendered, only
#' level/value will be rendered.
#' @param ... unused argument
#' @examples
#' library(data.table)
#' CO2 <- CO2
#' setDT(CO2)
#' CO2$conc <- as.integer(CO2$conc)
#'
#' data_co2 <- dcast(CO2, Treatment + conc ~ Type,
#'                   value.var = "uptake", fun.aggregate = mean)
#' data_co2 <- as_grouped_data(x = data_co2, groups = c("Treatment"))
#'
#' ft <- as_flextable( data_co2 )
#' ft <- add_footer_lines(ft, "dataset CO2 has been used for this flextable")
#' ft <- add_header_lines(ft, "mean of carbon dioxide uptake in grass plants")
#' ft <- set_header_labels(ft, conc = "Concentration")
#' ft <- autofit(ft)
#' ft <- width(ft, width = c(1, 1, 1))
#' ft
#' @family as_flextable methods
#' @seealso [as_grouped_data()]
as_flextable.grouped_data <- function(x, col_keys = NULL, hide_grouplabel = FALSE, ... ){

  if( is.null(col_keys))
    col_keys <- attr(x, "columns")
  groups <- attr(x, "groups")
  if(hide_grouplabel){
    col_keys <- setdiff(col_keys, groups)
  }
  z <- flextable(x, col_keys = col_keys )

  j2 <- length(col_keys)
  for( grp_name in groups){
    i <- !is.na(x[[grp_name]])
    gnames <- x[[grp_name]][i]
    if(!hide_grouplabel){
      z <- compose(z, i = i, j = 1,
                   value = as_paragraph(as_chunk(grp_name), ": ", as_chunk(gnames)))
    } else {
      z <- compose(z, i = i, j = 1, value = as_paragraph(as_chunk(gnames)))
    }

    z <- merge_h_range(z, i = i, j1 = 1, j2 = j2)
    z <- align(z, i = i, align = "left")
  }

  z
}




pvalue_format <- function(x){
  z <- cut(x, breaks = c(-Inf, 0.001, 0.01, 0.05, 0.1, Inf), labels = c("***", " **", "  *", "  .", "   "))
  z <- as.character(z)
  z[is.na(x)] <- ""
  z
}

#' @export
#' @importFrom stats naprint quantile
#' @importFrom utils tail
#' @title Transform a 'glm' object into a flextable
#' @description produce a flextable describing a
#' generalized linear model produced by function `glm`.
#' @param x glm model
#' @param ... unused argument
#' @examples
#' if(require("broom")){
#'   dat <- attitude
#'   dat$high.rating <- (dat$rating > 70)
#'   probit.model <- glm(high.rating ~ learning + critical +
#'      advance, data=dat, family = binomial(link = "probit"))
#'   ft <- as_flextable(probit.model)
#'   ft
#' }
#' @family as_flextable methods
as_flextable.glm <- function(x, ...){


  if(!requireNamespace("broom", quietly = TRUE)){
    stop(sprintf(
      "'%s' package should be installed to create a flextable from an object of type '%s'.",
      "broom", "glm")
    )
  }

  data_t <- broom::tidy(x)
  sum_obj <- summary(x)

  ft <- flextable(data_t, col_keys = c("term", "estimate",
    "std.error", "statistic", "p.value", "signif"))
  ft <- colformat_double(ft, j = c("estimate", "std.error",
    "statistic"), digits = 3)
  ft <- colformat_double(ft, j = c("p.value"), digits = 4) # nolint
  ft <- mk_par(ft, j = "signif",
    value = as_paragraph(pvalue_format(p.value)))

  ft <- set_header_labels(ft, term = "", estimate = "Estimate",
                          std.error = "Standard Error", statistic = "z value",
                          p.value = "Pr(>|z|)")

  digits <- max(3L, getOption("digits") - 3L)

  ft <- add_footer_lines(ft, values = c(
    "Signif. codes: 0 <= '***' < 0.001 < '**' < 0.01 < '*' < 0.05",
    " ",
    paste("(Dispersion parameter for ", x$family$family, " family taken to be ", format(sum_obj$dispersion), ")", sep = ""),
    sprintf("Null deviance: %s on %s degrees of freedom", formatC(sum_obj$null.deviance), formatC(sum_obj$df.null)),
    sprintf("Residual deviance: %s on %s degrees of freedom", formatC(sum_obj$deviance), formatC(sum_obj$df.residual)),
    {
      if (nzchar(mess <- naprint(sum_obj$na.action)))
        paste("  (", mess, ")\n", sep = "")
      else character(0)
    }
  ))
  ft <- align(ft, i = 1, align = "right", part = "footer")
  ft <- italic(ft, i = 1, italic = TRUE, part = "footer")
  ft <- hrule(ft, rule = "auto")
  ft <- autofit(ft, part = c("header", "body"))
  ft <- width(ft, j = "signif", width = .4)
  ft
}


#' @export
#' @title Transform a 'lm' object into a flextable
#' @description produce a flextable describing a
#' linear model produced by function `lm`.
#' @param x lm model
#' @param ... unused argument
#' @examples
#' if(require("broom")){
#'   lmod <- lm(rating ~ complaints + privileges +
#'     learning + raises + critical, data=attitude)
#'   ft <- as_flextable(lmod)
#'   ft
#' }
#' @family as_flextable methods
as_flextable.lm <- function(x, ...){

  if( !requireNamespace("broom", quietly = TRUE) ){
    stop(sprintf(
      "'%s' package should be installed to create a flextable from an object of type '%s'.",
      "broom", "lm")
    )
  }

  data_t <- broom::tidy(x)
  data_g <- broom::glance(x)

  ft <- flextable(data_t, col_keys = c("term", "estimate", "std.error", "statistic", "p.value", "signif"))
  ft <- colformat_double(ft, j = c("estimate", "std.error", "statistic"), digits = 3)
  ft <- colformat_double(ft, j = c("p.value"), digits = 4)
  ft <- compose(ft, j = "signif", value = as_paragraph(pvalue_format(p.value)) )

  ft <- set_header_labels(ft, term = "", estimate = "Estimate",
                          std.error = "Standard Error", statistic = "t value",
                          p.value = "Pr(>|t|)", signif = "" )
  dimpretty <- dim_pretty(ft, part = "all")

  ft <- add_footer_lines(ft, values = c(
    "Signif. codes: 0 <= '***' < 0.001 < '**' < 0.01 < '*' < 0.05",
    "",
    sprintf("Residual standard error: %s on %.0f degrees of freedom", formatC(data_g$sigma), data_g$df.residual),
    sprintf("Multiple R-squared: %s, Adjusted R-squared: %s", formatC(data_g$r.squared), formatC(data_g$adj.r.squared)),
    sprintf("F-statistic: %s on %.0f and %.0f DF, p-value: %.4f", formatC(data_g$statistic), data_g$df.residual, data_g$df, data_g$p.value)
  ))
  ft <- align(ft, i = 1, align = "right", part = "footer")
  ft <- italic(ft, i = 1, italic = TRUE, part = "footer")
  ft <- hrule(ft, rule = "auto")
  ft <- autofit(ft, part = c("header", "body"))
  ft <- width(ft, j = "signif", width = .4)
  ft
}


#' @export
#' @title Transform a 'htest' object into a flextable
#' @description produce a flextable describing an
#' object oof class `htest`.
#' @param x htest object
#' @param ... unused argument
#' @examples
#' if(require("stats")){
#'   M <- as.table(rbind(c(762, 327, 468), c(484, 239, 477)))
#'   dimnames(M) <- list(gender = c("F", "M"),
#'   party = c("Democrat","Independent", "Republican"))
#'   ft_1 <- as_flextable(chisq.test(M))
#'   ft_1
#' }
#' @family as_flextable methods
as_flextable.htest <- function (x, ...) {
  ret <- x[c("estimate", "statistic", "p.value", "parameter")]
  if (length(ret$estimate) > 1) {
    names(ret$estimate) <- paste0("estimate", seq_along(ret$estimate))
    ret <- c(ret$estimate, ret)
    ret$estimate <- NULL
    if (x$method == "Welch Two Sample t-test") {
      ret <- c(estimate = ret$estimate1 - ret$estimate2,
               ret)
    }
  }
  if (length(x$parameter) > 1) {
    ret$parameter <- NULL
    if (is.null(names(x$parameter))) {
      warning("Multiple unnamed parameters in hypothesis test; dropping them")
    }
    else {
      message("Multiple parameters; naming those columns ",
              paste(make.names(names(x$parameter)), collapse = ", "))
      ret <- append(ret, x$parameter, after = 1)
    }
  }
  ret <- Filter(Negate(is.null), ret)
  if (!is.null(x$conf.int)) {
    ret <- c(ret, conf.low = x$conf.int[1], conf.high = x$conf.int[2])
  }
  if (!is.null(x$method)) {
    ret <- c(ret, method = as.character(x$method))
  }
  if (!is.null(x$alternative)) {
    ret <- c(ret, alternative = as.character(x$alternative))
  }
  dat <- as.data.frame(ret, stringsAsFactors = FALSE)
  z <- flextable(dat)
  z <- colformat_double(z)
  if("p.value" %in% colnames(dat)){
    z <- colformat_double(z, j = "p.value", digits = 4)
    z <- append_chunks(x = z, j = "p.value", part = "body",
                        dumb = as_chunk(p.value, formatter = pvalue_format))
    z <- add_footer_lines(z, values = c(
      "Signif. codes: 0 <= '***' < 0.001 < '**' < 0.01 < '*' < 0.05")
    )
  }
  z <- autofit(z)
  z
}



#' @export
#' @title Continuous columns summary
#' @description create a data.frame summary for continuous variables
#' @param dat a data.frame
#' @param columns continuous variables to be summarized. If NULL all
#' continuous variables are summarized.
#' @param by discrete variables to use as groups when summarizing.
#' @param hide_grouplabel if TRUE, group label will not be rendered, only
#' level/value will be rendered.
#' @param digits the desired number of digits after the decimal point
#' @examples
#' ft_1 <- continuous_summary(iris, names(iris)[1:4], by = "Species",
#'   hide_grouplabel = FALSE)
#' ft_1
continuous_summary <- function(dat, columns = NULL,
                               by = character(0),
                               hide_grouplabel = TRUE,
                               digits = 3){

  if(!is.data.table(dat)){
    x <- as.data.table(dat)
  }
  if(is.null(columns)){
    columns <- colnames(dat)[sapply(dat, function(z) is.double(z) || is.integer(z))]
  }

  fun_list <- c("N", "MIN", "Q1", "MEDIAN",
               "Q3", "MAX", "MEAN", "SD", "MAD", "NAS")
  agg <- x[,
           c(
             lapply(.SD, N),
             lapply(.SD, MIN),
             lapply(.SD, Q1),
             lapply(.SD, MEDIAN),
             lapply(.SD, Q3),
             lapply(.SD, MAX),
             lapply(.SD, MEAN),
             lapply(.SD, SD),
             lapply(.SD, MAD),
             lapply(.SD, NAS)
           ),
           .SDcols = columns,
           by = by]

  gen_cn <- lapply(fun_list, function(fun, col) paste0( col, "_", fun ), columns)
  colnames(agg) <- c(by, unlist(gen_cn))

  agg <- melt(agg, measure = c(gen_cn), value.name = fun_list)
  levels(x = agg[["variable"]] ) <- columns
  z <- as_grouped_data( agg, groups = "variable", columns = setdiff(names(agg), "variable") )
  is_label <- !is.na(z$variable)
  ft <- as_flextable(z, hide_grouplabel = hide_grouplabel)


  ft <- colformat_int(ft, j = c("N", "NAS"))
  ft <- colformat_double(ft, j = setdiff(fun_list, c("N", "NAS")), digits = digits)
  ft <- set_header_labels(ft, values = c("MIN" = "min.", "MAX" = "max.",
                                         "Q1" = "q1", "Q3" = "q3",
                                         "MEDIAN" = "median", "MEAN" = "mean", "SD" = "sd",
                                         "MAD" = "mad",
                                         "NAS" = "# na"))
  ft <- hline(ft, i = is_label, border = officer::fp_border(width = .5))
  ft <- italic(ft, italic = TRUE, i = is_label)
  ft <- merge_v(ft, j = by)
  ft <- valign(ft, j = by, valign = "top")
  ft <- vline(ft, j = length(by), border = officer::fp_border(width = .5), part = "body")
  ft <- vline(ft, j = length(by), border = officer::fp_border(width = .5), part = "header")
  fix_border_issues(ft)
}




#' @export
#' @title Transform a mixed model into a flextable
#' @description produce a flextable describing a
#' mixed model. The function is only using package 'broom.mixed'
#' that provides the data presented in the resulting flextable.
#' @param x a mixed model
#' @param ... unused argument
#' @examples
#' if(require("broom.mixed") && require("nlme")){
#'   m1 <- lme(distance ~ age, data = Orthodont)
#'   ft <- as_flextable(m1)
#'   ft
#' }
#' @family as_flextable methods
as_flextable.merMod <- function(x, ...){

  if( !requireNamespace("broom.mixed", quietly = TRUE) ){
    stop(sprintf(
      "'%s' package should be installed to create a flextable from an object of type '%s'.",
      "broom.mixed", "mixed model")
    )
  }

  data_t <- broom::tidy(x)
  data_t$effect[data_t$effect %in% "fixed"] <- "Fixed effects"
  data_t$effect[data_t$effect %in% c("ran_pars", "ran_vals", "ran_coefs")] <- "Random effects"

  data_g <- broom::glance(x)
  has_pvalue <- if("p.value" %in% colnames(data_t)) TRUE else FALSE

  col_keys <- c("effect", "group", "term", "estimate",
                "std.error", "df", "statistic", if(has_pvalue) c("p.value", "signif"))
  data_t <- as_grouped_data(x = data_t, groups = "effect", )

  ft <- as_flextable(data_t, col_keys = col_keys,
                     hide_grouplabel = TRUE)
  ft <- colformat_double(ft, j = c("estimate", "std.error", "statistic"), digits = 3)
  ft <- colformat_double(ft, j = c("df"), digits = 0)
  if(has_pvalue){
    ft <- colformat_double(ft, j = "p.value", digits = 4)
  }
  ft <- set_header_labels(ft, term = "", estimate = "Estimate",
                          std.error = "Standard Error",
                          p.value = "p-value")
  ft <- autofit(ft, part = c("header", "body"))

  if(has_pvalue){
    ft <- compose(ft, j = "signif", value = as_paragraph(pvalue_format(p.value)))
    ft <- width(ft, j = "signif", width = .4)
  }
  ft <- align(ft, i = ~ !is.na(effect), align = "center")

  ft <- add_footer_lines(ft, values = c(
    "Signif. codes: 0 <= '***' < 0.001 < '**' < 0.01 < '*' < 0.05",
    ""
  ))

  mod_stats <- c("sigma", "logLik", "AIC", "BIC")
  mod_gl <- data.frame(
    stat = mod_stats,
    value = as.double(unlist(data_g[mod_stats])),
    labels = c("square root of the estimated residual variance",
               "data's log-likelihood under the model",
               "Akaike Information Criterion",
               "Bayesian Information Criterion"
    )
  )
  mod_qual <- paste0(
    c("square root of the estimated residual variance",
      "data's log-likelihood under the model",
      "Akaike Information Criterion",
      "Bayesian Information Criterion"),
    ": ",
    format_fun(unlist(data_g[mod_stats]))
  )
  ft <- add_footer_lines(ft, values = mod_qual)
  ft <- align(ft, align = "left", part = "footer")
  ft <- align(ft, i = 1, align = "right", part = "footer")
  ft <- hrule(ft, rule = "auto")
  ft
}

#' @export
#' @rdname as_flextable.merMod
as_flextable.lme <- as_flextable.merMod

#' @export
#' @rdname as_flextable.merMod
as_flextable.gls <- as_flextable.merMod

#' @export
#' @rdname as_flextable.merMod
as_flextable.nlme <- as_flextable.merMod

#' @export
#' @rdname as_flextable.merMod
as_flextable.brmsfit <- as_flextable.merMod

#' @export
#' @rdname as_flextable.merMod
as_flextable.glmmTMB <- as_flextable.merMod

#' @export
#' @rdname as_flextable.merMod
as_flextable.glmmadmb <- as_flextable.merMod

#' @export
#' @title Transform a 'kmeans' object into a flextable
#' @description produce a flextable describing a
#' kmeans object. The function is only using package 'broom'
#' that provides the data presented in the resulting flextable.
#' @param x a [kmeans()] object
#' @param digits number of digits for the numeric columns
#' @param ... unused argument
#' @examples
#' if(require("stats")){
#'   cl <- kmeans(scale(mtcars[1:7]), 5)
#'   ft <- as_flextable(cl)
#'   ft
#' }
#' @importFrom rlang sym
#' @family as_flextable methods
as_flextable.kmeans <- function(x, digits = 4, ...) {
  if (!requireNamespace("broom", quietly = TRUE)) {
    stop(sprintf(
      "'%s' package should be installed to create a flextable from an object of type '%s'.",
      "broom", "kmeans")
    )
  }

  ## kmeans body ----
  clusters_stat <- broom::tidy(x)
  setDT(clusters_stat)
  keys <- c("withinss", "size", setdiff(colnames(clusters_stat), c("cluster", "withinss", "size")))
  key_type <- rep("Centers", length(keys))
  key_type[1:2] <- "Statistics"
  clusters_stat[, c(keys) := lapply(.SD, as.double), .SDcols = keys]

  clusters_stat <- melt.data.table(
    data = clusters_stat, id.vars = "cluster",
    measure.vars = setdiff(colnames(clusters_stat), c("cluster")),
    value.name = "value"
  )
  clusters_stat$variable <- factor(clusters_stat$variable, levels = keys)
  setorderv(clusters_stat, cols = c("variable"))
  setDF(clusters_stat)

  ## kmeans footer ----
  data_g <- broom::glance(x)
  w_labels <- c(
    "Total sum of squares",
    "Total within-cluster sum of squares",
    "Total between-cluster sum of squares",
    "BSS/TSS ratio",
    "Number of iterations"
  )
  totss <- data_g$totss
  tot.withinss <- data_g$tot.withinss
  betweenss <- data_g$betweenss
  ratio <- betweenss / totss
  w_labels <- paste0(
    w_labels, ": ",
    c(
      format_fun(totss),
      format_fun(tot.withinss),
      format_fun(betweenss),
      format_fun(ratio * 100, suffix = "%"),
      as.character(x$iter)
    )
  )

  ## tabulate ----
  ct <- tabulator(
    x = clusters_stat, rows = c("variable"), columns = "cluster",
    hidden_data = data.frame(
      variable = keys,
      key_type = key_type
    ),
    zz = as_paragraph(as_chunk(value))
  )

  ## flextable ----
  ft <- as_flextable(ct)
  ft <- add_footer_lines(ft, c("(*) Centers", w_labels))

  zz_labs <- tabulator_colnames(ct, type = "columns", columns = "zz")
  value_labq <- tabulator_colnames(ct, type = "hidden", columns = "value")

  for (j in seq_along(zz_labs)) {
    sym_val <- sym(value_labq[j])
    ft <- mk_par(ft,
      i = ~ variable %in% "size",
      j = zz_labs[j],
      value = as_paragraph(
        as_chunk(
          !!sym_val,
          formatter = function(x) sprintf("%.0f", x)
        )
      )
    )
    ft <- mk_par(ft,
      i = ~ !variable %in% c("size", "withinss"),
      j = zz_labs[j],
      value = as_paragraph(
        as_chunk(
          !!sym_val,
          formatter = function(x) format_fun(x, digits = digits)
        )
      )
    )
  }
  ft <- append_chunks(ft, j = 1, part = "body",
                      i = ~ key_type %in% "Centers",
                      as_chunk("*"))
  ft <- hline(ft,
    j = c("variable", zz_labs), i = ~ variable %in% "size",
    border = fp_border_default()
  )
  ft <- autofit(ft, part = c("header", "body"))
  ft <- align(ft, align = "right", part = "footer")
  ft <- align(ft, align = "left", i = 1,
              part = "footer")
  ft <- hrule(ft, rule = "auto")
  ft <- bold(ft, part = "header", bold = TRUE)
  ft
}

#' @export
#' @title Transform a 'pam' object into a flextable
#' @description produce a flextable describing a
#' pam object. The function is only using package 'broom'
#' that provides the data presented in the resulting flextable.
#' @param x a [cluster::pam()] object
#' @param digits number of digits for the numeric columns
#' @param ... unused argument
#' @examples
#' if(require("cluster")){
#'   dat <- as.data.frame(scale(mtcars[1:7]))
#'   cl <- pam(dat, 3)
#'   ft <- as_flextable(cl)
#'   ft
#' }
#' @family as_flextable methods
as_flextable.pam <- function(x, digits = 4, ...){
  if( !requireNamespace("broom", quietly = TRUE) ){
    if (!requireNamespace("broom", quietly = TRUE)) {
      stop(sprintf(
        "'%s' package should be installed to create a flextable from an object of type '%s'.",
        "broom", "pam")
      )
    }
  }

  clus_stat_names <- c(
    "size", "max.diss", "avg.diss", "diameter",
    "separation", "avg.width")

  ## kmeans body ----
  clusters_stat <- broom::tidy(x)
  setDT(clusters_stat)
  keys <- colnames(clusters_stat)
  clusters_stat <- melt.data.table(
    data = clusters_stat, id.vars = "cluster",
    measure.vars = setdiff(colnames(clusters_stat), c("cluster")),
    value.name = "value"
  )

  ## tabulate ----
  ct <- tabulator(
    x = clusters_stat, rows = c("variable"), columns = "cluster",
    zz = as_paragraph(as_chunk(value))
  )

  ## flextable ----
  ft <- as_flextable(ct)
  ft <- add_footer_lines(ft, "(*) Centers")

  zz_labs <- tabulator_colnames(ct, type = "columns", columns = "zz")
  value_labq <- tabulator_colnames(ct, type = "hidden", columns = "value")

  for (j in seq_along(zz_labs)) {
    sym_val <- sym(value_labq[j])
    ft <- mk_par(ft,
                 i = ~ variable %in% "size",
                 j = zz_labs[j],
                 value = as_paragraph(
                   as_chunk(
                     !!sym_val,
                     formatter = function(x) sprintf("%.0f", x)
                   )
                 )
    )
    ft <- mk_par(ft,
                 i = ~ !variable %in% c(
                   "size", "max.diss", "avg.diss", "diameter",
                   "separation", "avg.width"),
                 j = zz_labs[j],
                 value = as_paragraph(
                   as_chunk(
                     !!sym_val,
                     formatter = function(x)
                       format_fun(x, digits = digits)
                   )
                 )
    )
  }

  data_g <- broom::glance(x)

  ft <- append_chunks(ft, j = 1, part = "body",
                      i = ~ !variable %in% c(
                        "size", "max.diss", "avg.diss", "diameter",
                        "separation", "avg.width"),
                      as_chunk("*"))
  ft <- hline(ft,
              j = c("variable", zz_labs), i = ~ variable %in% "avg.width",
              border = fp_border_default()
  )

  ft <- autofit(ft, part = c("header", "body"))
  ## kmeans footer ----
  ft <- add_footer_lines(
    x = ft,
    values = paste0("The average silhouette width is ",
                    formatC(data_g$avg.silhouette.width))
  )

  ft <- align(ft, j = 1, align = "left", part = "footer")
  ft <- hrule(ft, rule = "auto")
  ft <- bold(ft, part = "header", bold = TRUE)
  ft
}

#' @export
#' @title Transform and summarise a 'data.frame' into a flextable
#' Simple summary of a data.frame as a flextable
#' @description It displays the first rows and shows the column types.
#' If there is only one row, a simplified vertical table is produced.
#' @param x a data.frame
#' @param max_row The number of rows to print. Default to 10.
#' @param split_colnames Should the column names be split
#' (with non alpha-numeric characters). Default to FALSE.
#' @param short_strings Should the character column be shorten.
#' Default to FALSE.
#' @param short_size Maximum length of character column if
#' `short_strings` is TRUE. Default to 35.
#' @param short_suffix Suffix to add when character values are shorten.
#' Default to "...".
#' @param do_autofit Use [autofit()] before rendering the table.
#' Default to TRUE.
#' @param show_coltype Show column types.
#' Default to TRUE.
#' @param color_coltype Color to use for column types.
#' Default to "#999999".
#' @param ... unused arguments
#' @examples
#' as_flextable(mtcars)
#' @family as_flextable methods
as_flextable.data.frame <- function(x,
                                    max_row = 10,
                                    split_colnames = FALSE,
                                    short_strings = FALSE,
                                    short_size = 35,
                                    short_suffix = "...",
                                    do_autofit = TRUE,
                                    show_coltype = TRUE,
                                    color_coltype = "#999999",
                                    ...) {
  if (nrow(x) == 1) {
    singlerow_df_printer(
      dat = x,
      max_row = max_row,
      short_strings = short_strings,
      short_size = short_size,
      short_suffix = short_suffix,
      do_autofit = do_autofit,
      show_coltype = show_coltype,
      color_coltype = color_coltype
    )
  } else {
    multirow_df_printer(
      dat = x,
      max_row = max_row,
      split_colnames = split_colnames,
      short_strings = short_strings,
      short_size = short_size,
      short_suffix = short_suffix,
      do_autofit = do_autofit,
      show_coltype = show_coltype,
      color_coltype = color_coltype
    )
  }
}

look_like_int <- function(x) {
  (is.numeric(x) && isTRUE(all.equal(x, as.integer(x)))) || is.integer(x)
}

multirow_df_printer <- function(dat,
                                max_row = 10,
                                split_colnames = FALSE,
                                short_strings = FALSE,
                                short_size = 35,
                                short_suffix = "...",
                                do_autofit = TRUE,
                                show_coltype = TRUE,
                                color_coltype = "#999999") {
  x <- as.data.frame(dat)
  nro <- nrow(x)

  z <- get_flextable_defaults()

  x <- head(x, n = max_row)
  coltypes <- as.character(sapply(dat, function(x) head(class(x), 1)))

  lli <- sapply(x, look_like_int)
  x[lli] <- lapply(x[lli], as.integer)

  if (!is.null(short_strings) && short_strings) {
    wic <- sapply(x, is.character)
    x[wic] <- lapply(x[wic], function(x) {
      paste0(substring(text = x, first = 1, last = short_size), short_suffix)
    })
  }

  colkeys <- colnames(x)

  ft <- flextable(x, col_keys = colkeys)

  if (split_colnames) {
    labs <- strsplit(colkeys, split = "[^[:alnum:]]+")
    names(labs) <- colkeys
    labs <- lapply(labs, paste, collapse = "\n")
    ft <- set_header_labels(ft, values = labs)
  }

  if (show_coltype) {
    ft <- add_header_row(ft, top = FALSE, values = coltypes)
  }

  ft <- colformat_double(ft)
  ft <- colformat_int(ft)

  if (nro > max_row) {
    ft <- add_footer_lines(ft, values = sprintf("n: %.0f", nro))
  }
  ft <- set_table_properties(ft, layout = z$table.layout)
  if ("fixed" %in% z$table.layout && do_autofit) {
    ft <- autofit(ft)
  }

  ft <- do.call(z$theme_fun, list(ft))

  if (show_coltype) {
    ft <- color(ft, i = nrow_part(ft, "header"), part = "header", color = color_coltype)
  }
  ft <- align(ft, align = "left", part = "footer")
  ft
}

singlerow_df_printer <- function(dat,
                                 max_row = 10,
                                 split_colnames = FALSE,
                                 short_strings = FALSE,
                                 short_size = 35,
                                 short_suffix = "...",
                                 do_autofit = TRUE,
                                 show_coltype = TRUE,
                                 color_coltype = "#999999") {
  coltypes <- as.character(sapply(dat, function(x) head(class(x), 1)))

  lli <- sapply(dat, look_like_int)
  dat[lli] <- lapply(dat[lli], as.integer)

  x <- data.frame(
    "Col." = colnames(dat),
    "Type" = coltypes,
    "Val." = vapply(dat, format_fun.default, FUN.VALUE = NA_character_)
  )

  z <- get_flextable_defaults()

  x <- head(x, n = max_row)

  if (!is.null(short_strings) && short_strings) {
    wic <- sapply(x, is.character)
    x[wic] <- lapply(x[wic], function(x) {
      paste0(substring(text = x, first = 1, last = short_size), short_suffix)
    })
  }

  colkeys <- c("Col.", "Val.")

  ft <- flextable(x, col_keys = colkeys)
  ft <- delete_part(ft, part = "header")
  ft <- set_table_properties(ft, layout = z$table.layout)
  if ("fixed" %in% z$table.layout && do_autofit) {
    ft <- autofit(ft)
  }
  ft <- do.call(z$theme_fun, list(ft))
  ft <- align(ft, align = "center", part = "all")
  ft <- align(ft, j = 1, align = "right", part = "all")
  ft <- valign(x = ft, valign = "top", part = "body")
  if (show_coltype) {
    ft <- append_chunks(
      x = ft, j = "Col.",
      as_chunk("\n"),
      colorize(
        x = as_chunk(Type, props = fp_text_default(font.size = z$font.size * 2 / 3)),
        color = color_coltype
      )
    )
  }
  ft
}


#' @export
#' @title set model automatic printing as a flextable
#' @description Define [as_flextable()] as
#' print method in an R Markdown document for models
#' of class:
#'
#' * lm
#' * glm
#' * models from package 'lme' and 'lme4'
#' * htest (t.test, chisq.test, ...)
#' * gam
#' * kmeans and pam
#'
#'
#' In a setup run chunk:
#'
#' ```
#' flextable::use_model_printer()
#' ```
#' @seealso [use_df_printer()], [flextable()]
use_model_printer <- function() {
  fun <- function(x, ...) knitr::knit_print(as_flextable(x))
  registerS3method("knit_print", "lm", fun)
  registerS3method("knit_print", "glm", fun)
  registerS3method("knit_print", "lme", fun)
  registerS3method("knit_print", "htest", fun)
  registerS3method("knit_print", "merMod", fun)
  registerS3method("knit_print", "gls", fun)
  registerS3method("knit_print", "nlme", fun)
  registerS3method("knit_print", "brmsfit", fun)
  registerS3method("knit_print", "glmmTMB", fun)
  registerS3method("knit_print", "glmmadmb", fun)
  registerS3method("knit_print", "gam", fun)
  registerS3method("knit_print", "pam", fun)
  registerS3method("knit_print", "kmeans", fun)
  invisible()
}

utils::globalVariables(c("p.value", "value", "Type", ".row_title"))




