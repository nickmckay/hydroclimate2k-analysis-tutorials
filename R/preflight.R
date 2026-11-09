# Run this once, with a good internet connection, before the workshop.
#
# It installs (or updates) the LiPD family of R packages from GitHub, then
# downloads the Hydroclimate2k compilation and the IPCC AR6 regions into the
# `data/` folder. After that, every tutorial runs offline.
#
# From the project folder:   Rscript R/preflight.R
# Or open the .Rproj in RStudio and source this file.

options(repos = c(CRAN = "https://cloud.r-project.org"))

if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
if (!requireNamespace("here", quietly = TRUE)) install.packages("here")

# geoChronR 2.x installs lipdR, ens, lipdViz and agemodelR as well.
family <- c("nickmckay/lipdR", "nickmckay/ens", "nickmckay/lipdViz",
            "nickmckay/agemodelR", "nickmckay/geoChronR",
            "nickmckay/compositeR", "LinkedEarth/actR")
# upgrade = "always" also updates outdated CRAN dependencies. An old xfun,
# for example, makes several of these packages fail to install.
for (repo in family) {
  remotes::install_github(repo, upgrade = "always", dependencies = TRUE)
}

cran <- c("dplyr", "tidyr", "purrr", "ggplot2", "sf", "knitr", "rmarkdown")
missing <- cran[!vapply(cran, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing)

source(here::here("R/helpers.R"))
checkVersions()

message("Downloading and reading the Hydroclimate2k compilation ",
        "(about 280 MB; the first read takes a few minutes)...")
D <- getHydro2k()
regions <- getAr6Regions()

message("\nAll set: ", length(D), " datasets cached in ", h2k_data_dir, ".")
for (p in c("lipdR", "ens", "lipdViz", "agemodelR", "geoChronR",
            "compositeR", "actR")) {
  message(sprintf("  %-11s %s", p, utils::packageVersion(p)))
}
