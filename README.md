# Hydroclimate2k analysis tutorials

Worked examples for analyzing the [Hydroclimate2k](https://lipdverse.org/hydroclimate2k/) compilation with the LiPD family of R packages (lipdR, ens, lipdViz, agemodelR, geoChronR, compositeR, actR).

**Rendered site:** https://nickmckay.github.io/hydroclimate2k-analysis-tutorials/

## Quick start

```r
# from the project folder (open hydroclimate2k-analysis-tutorials.Rproj)
source("R/preflight.R")   # install packages, download and cache the data
```

Then open any file in `tutorials/` and run it chunk by chunk. After the preflight step everything runs offline.

## Layout

| Path | Contents |
|---|---|
| `tutorials/` | The four tutorials, as Quarto (`.qmd`) files |
| `R/helpers.R` | Shared helpers: download-once data access, IPCC AR6 region lookup, version checks |
| `R/preflight.R` | Installs packages and caches all data in `data/` |
| `data/` | Downloaded data (git-ignored) |
| `DESCRIPTION` | Package dependencies, used by GitHub Actions (this is not an R package) |

## Building the site

```bash
quarto preview     # live preview
quarto render      # build into _site/
```

GitHub Actions renders the site on every push to `main` and publishes it to the `gh-pages` branch (`.github/workflows/publish.yml`). Pull requests are rendered but not published.

To change the compilation version, edit `h2k_version` in `R/helpers.R`.
