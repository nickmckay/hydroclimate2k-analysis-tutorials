# Shared helpers for the Hydroclimate2k tutorials.
#
# Every tutorial runs `source(here::here("R/helpers.R"))` first. The helpers
# download data from lipdverse.org once, into the `data/` folder of this
# project, and read it from there afterwards. Once `R/preflight.R` has run,
# the tutorials work with no internet connection.

# The compilation version used throughout. Change it here to switch versions.
h2k_version <- "0_9_0"

# Where downloaded files are kept.
h2k_data_dir <- here::here("data")

#' URL of a file in the lipdverse download area for a hydroclimate2k version
h2k_url <- function(file, version = h2k_version) {
  paste0("https://lipdverse.org/export/downloads/hydroclimate2k/",
         version, "/", file)
}

#' Download a file once. Does nothing if `dest` already exists.
downloadOnce <- function(url, dest) {
  if (file.exists(dest)) {
    return(invisible(dest))
  }
  dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
  message("Downloading ", url)
  old <- options(timeout = max(1800, getOption("timeout")))
  on.exit(options(old))
  ok <- tryCatch({
    utils::download.file(url, dest, mode = "wb", quiet = FALSE)
    TRUE
  }, error = function(e) {
    message(conditionMessage(e))
    FALSE
  })
  if (!ok || !file.exists(dest) || file.size(dest) == 0) {
    unlink(dest)
    stop("Could not download ", url, "\n",
         "Download it in a web browser instead, and save it as:\n  ", dest,
         call. = FALSE)
  }
  invisible(dest)
}

#' Path to the hydroclimate2k zip file, downloading it if needed.
h2k_zip <- function(version = h2k_version) {
  file <- paste0("hydroclimate2k", version, ".zip")
  downloadOnce(h2k_url(file, version), file.path(h2k_data_dir, file))
}

#' Folder of unzipped .lpd files for a version, downloading and unzipping if
#' needed. (readLipd() reads a zip from a URL, but not a local zip file, so we
#' unzip it ourselves and read the folder.)
h2k_dir <- function(version = h2k_version) {
  dir <- file.path(h2k_data_dir, paste0("hydroclimate2k", version))
  if (!dir.exists(dir) || length(list.files(dir, "\\.lpd$")) == 0) {
    utils::unzip(h2k_zip(version), exdir = dir)
  }
  dir
}

#' Load the hydroclimate2k compilation as a multi-LiPD object.
#'
#' The first call downloads the zip (about 280 MB) and reads it with
#' `lipdR::readLipd()`, which takes a couple of minutes. The result is saved
#' as an .rds file, so later calls take a few seconds. Updating lipdR to a new
#' minor version (e.g. 0.8 to 0.9) reads the files again.
getHydro2k <- function(version = h2k_version) {
  # readLipd() adds information as it reads (e.g. time scales since lipdR
  # 0.8), so the cache is kept per lipdR version (major.minor)
  lv <- paste(unlist(utils::packageVersion("lipdR"))[1:2], collapse = ".")
  rds <- file.path(h2k_data_dir, paste0("hydroclimate2k", version, "-lipdR", lv, ".rds"))
  if (file.exists(rds)) {
    return(readRDS(rds))
  }
  bib <- paste0("hydroclimate2k-", version, ".bib")
  try(downloadOnce(h2k_url(bib, version), file.path(h2k_data_dir, bib)))
  D <- lipdR::readLipd(h2k_dir(version))
  saveRDS(D, rds)
  D
}

#' IPCC AR6 WGI reference regions (Iturbide et al., 2020) as an sf object.
#'
#' Polygons come from the SantanderMetGroup ATLAS repository and are cached in
#' `data/`.
getAr6Regions <- function() {
  url <- paste0("https://raw.githubusercontent.com/SantanderMetGroup/ATLAS/",
                "main/reference-regions/IPCC-WGI-reference-regions-v4.geojson")
  dest <- file.path(h2k_data_dir, "IPCC-WGI-reference-regions-v4.geojson")
  downloadOnce(url, dest)
  sf::st_read(dest, quiet = TRUE)
}

#' Add the AR6 region of each record to a timeseries tibble.
#'
#' Adds `ar6_region` (the acronym, e.g. "WNA") and `ar6_name` (e.g.
#' "W.North-America"). Records outside every polygon get NA.
addAr6Region <- function(tib, regions = getAr6Regions()) {
  old <- sf::sf_use_s2(FALSE)
  on.exit(suppressMessages(sf::sf_use_s2(old)))
  pts <- sf::st_as_sf(
    data.frame(row = seq_len(nrow(tib)),
               lon = as.numeric(tib$geo_longitude),
               lat = as.numeric(tib$geo_latitude)),
    coords = c("lon", "lat"), crs = 4326, na.fail = FALSE
  )
  hit <- suppressMessages(sf::st_intersects(pts, regions))
  first <- vapply(hit, function(i) if (length(i)) i[1] else NA_integer_,
                  integer(1))
  tib$ar6_region <- regions$Acronym[first]
  tib$ar6_name <- regions$Name[first]
  tib
}

#' Stop early if an old version of the LiPD packages is installed.
checkVersions <- function() {
  need <- c(lipdR = "0.8.3", ens = "0.2.2", lipdViz = "0.3.0",
            agemodelR = "0.2.0", geoChronR = "2.0.0", compositeR = "0.6.0",
            actR = "0.5.0")
  for (p in names(need)) {
    have <- tryCatch(utils::packageVersion(p), error = function(e) NULL)
    if (is.null(have) || have < need[[p]]) {
      stop(p, " ", need[[p]], " or newer is needed, but ",
           if (is.null(have)) "it is not installed" else paste("you have", have),
           ".\nRun R/preflight.R, or see the 'Before the workshop' page.",
           call. = FALSE)
    }
    # a package updated during this R session is still loaded at its old version
    if (isNamespaceLoaded(p)) {
      loaded <- package_version(getNamespaceVersion(p))
      if (loaded < need[[p]]) {
        stop(p, " ", loaded, " is loaded in this R session, but ", have,
             " is installed. Restart R (Session > Restart R) and try again.",
             call. = FALSE)
      }
    }
  }
  invisible(TRUE)
}

#' TRUE if x holds at least one non-missing value
hasValues <- function(x) {
  !is.null(x) && length(x) > 0 && !all(is.na(x))
}

#' The Hydroclimate2k timeseries, ready to analyze.
#'
#' Does the steps from tutorial 1 in one go: reads the compilation, extracts
#' timeseries, keeps the members of this version, adds the AR6 region, and
#' puts every record's `time` on one scale with `lipdR::convertTsTime()`
#' (year CE by default). Returns a plain tibble, one row per timeseries.
h2kTimeseries <- function(version = h2k_version, units = "CE") {
  D <- getHydro2k(version)
  tib <- lipdR::filterByCompilation(lipdR::ts2tibble(lipdR::extractTs(D)),
                                    "hydroclimate2k", version = version,
                                    version.op = "==")
  tib <- lipdR::convertTsTime(addAr6Region(tib), units)
  tib <- tibble::as_tibble(tib)
  tib$paleoData_values <- lapply(tib$paleoData_values, as.numeric)
  tib
}

#' Is a record interpreted as a measure of moisture?
#'
#' TRUE for interpretation variables such as precipitation, streamflow, P/E,
#' PDSI, moisture balance or lake level, where larger values (with a positive
#' interpretation direction) mean wetter. FALSE for temperature, isotopes of
#' precipitation, moisture source, and drought indices (where larger means
#' drier, so they would point the wrong way), and for missing interpretations.
isMoisture <- function(variable) {
  v <- tolower(variable)
  !is.na(v) &
    grepl("precip|streamflow|p/e|p-e|pdsi|moisture|water level|lake ?level|runoff|wetness", v) &
    !grepl("isotope|d18o|d2h|source", v)
}

#' Keep the part of each record between two times (in the units of `time`,
#' year CE for h2kTimeseries()).
#'
#' Clips every column with one value per observation (the values, `time`,
#' and its source column such as `year` or `age`, depth, ...), and the rows of
#' ensemble matrices, so they all stay consistent.
clipTime <- function(tib, from, to) {
  listCols <- names(tib)[vapply(tib, is.list, logical(1))]
  for (i in seq_len(nrow(tib))) {
    tm <- as.numeric(tib$time[[i]])
    n <- length(tm)
    keep <- !is.na(tm) & tm >= from & tm <= to
    for (col in listCols) {
      x <- tib[[col]][[i]]
      if (is.matrix(x) && nrow(x) == n) {
        tib[[col]][[i]] <- x[keep, , drop = FALSE]
      } else if (is.atomic(x) && !is.matrix(x) && length(x) == n && n > 1) {
        tib[[col]][[i]] <- x[keep]
      }
    }
    tib$time[[i]] <- tm[keep]
  }
  tib
}
