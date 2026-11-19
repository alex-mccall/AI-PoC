#' Prepare chronologically ordered data explicitly labelled for provisional use.
prepare_population_review <- function(results, config) {
  results |>
    dplyr::arrange(sex_code, age_group_order) |>
    dplyr::mutate(
      dataset_id = config$dataset_id,
      geography_label = config$context$geography_label,
      period_label = config$context$period_label,
      result_status = "provisional_review_only",
      official_acceptance = "blocked",
      .before = 1
    )
}

#' Draw count panels on a shared scale, without relying on colour for sex.
#'
#' Unequal age widths are explicitly noted. The companion CSV is the text/data
#' alternative; this chart does not represent counts per year of age.
population_review_chart <- function(results, config) {
  ordered_groups <- results |>
    dplyr::distinct(age_group, age_group_order) |>
    dplyr::arrange(age_group_order)
  plot_data <- results |>
    dplyr::mutate(age_group = factor(age_group, levels = ordered_groups$age_group))
  ggplot2::ggplot(plot_data, ggplot2::aes(x = age_group, y = population)) +
    ggplot2::geom_col() +
    ggplot2::facet_wrap(ggplot2::vars(sex_label), ncol = 1) +
    ggplot2::scale_y_continuous(labels = function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)) +
    ggplot2::labs(
      title = paste0("PROVISIONAL: ", config$context$period_label,
                     "\nPopulation by sex and broad age group"),
      subtitle = paste0(config$context$geography_label,
                        "\nSupplied-file scope; coverage not independently verified."),
      x = "Age group (years)", y = "Population count",
      caption = paste(
        "Source: supplied RM121 extract; provenance incomplete.",
        "Official acceptance blocked.",
        "Age groups have unequal widths; 65+ is open-ended.",
        "Bars show totals, not counts per year of age.",
        sep = "\n"
      )
    )
}
