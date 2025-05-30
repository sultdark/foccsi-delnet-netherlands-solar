% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/results.R
\name{plot_Prognosefehler_Anbieter}
\alias{plot_Prognosefehler_Anbieter}
\title{Prognosefehler_Anbieter}
\usage{
plot_Prognosefehler_Anbieter(name, datapath = datapath, i18n = i18n)
}
\arguments{
\item{name}{the name of the file on disk to be used as data source}

\item{datapath}{- optional, the path on disk where data is stored}

\item{i18n}{- required, the translator object used to personalize output according with user set language}
}
\value{
a plotly object
}
\description{
Draw Prognosefehler_Anbieter 
Requires the following data columns:
"Z", 
"PF_A1", "PF_A2", "PF_A3", "PF_A4", "PF_A5", "PF_A6", "PF_A7"
}
\examples{
p1 <- plot_Prognosefehler_Anbieter(name = i18n$t("Forecast_Error_Provider"), datapath = file.path("tests/output"), i18n = i18n)

}
