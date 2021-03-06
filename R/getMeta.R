##' Get information on meteorological sites
##'
##' This function is primarily used to find a site code that can be used to
##' access data using \code{\link{importNOAA}}. Sites searches of approximately
##' 30,000 sites can be carried out based on the site name and based on the
##' nearest locations based on user-supplied latitude and logitude.
##'
##' See also \code{\link{getMetaLive}} to download the all meta data to allow
##' re-use and direct querying.
##' 
##' @title Find a ISD site code and other meta data
##' @param site A site name search string e.g. \code{site =
##'   "heathrow"}. The search strings and be partial and can be upper
##'   or lower case e.g. \code{site = "HEATHR"}.
##' @param lat A latitude in decimal degrees to search. Takes the
##'   values -90 to 90.
##' @param lon A longitude in decimal degrees to search. Takes values
##'   -180 to 180. Negative numbers are west of the Greenwich
##'   meridian.
##' @param country The country code. This is a two letter code. For a
##'   full listing see
##'   \url{ftp://ftp.ncdc.noaa.gov/pub/data/noaa/country-list.txt}.
##' @param state The state code. This is a two letter code.
##' @param n The number of nearest sites to search based on
##'   \code{latitude} and \code{longitude}.
##' @param end.year To help filter sites based on how recent the
##'   available data are. \code{end.year} can be "current", "any" or a
##'   numeric year such as 2016, or a range of years e.g. 1990:2016
##'   (which would select any site that had an end date in that range.
##'   \strong{By default only sites that have some data for the
##'   current year are returned}.
##' @param plot If \code{TRUE} will plot sites on an interactive
##'   leaflet map.
##' @param returnMap Should the leaflet map be returned instead of the
##'   meta data? Default is \code{FALSE}.
##' @return A data frame is returned with all available meta data,
##'   mostly importantly including a \code{code} that can be supplied
##'   to \code{\link{importNOAA}}. If latitude and longitude searches
##'   are made an approximate distance, \code{dist} in km is also
##'   returned.
##' @export
##' @author David Carslaw
##' @examples
##'
##' \dontrun{
##' ## search for sites with name beijing
##' getMeta(site = "beijing")
##' }
##'
##' \dontrun{
##' ## search for near a specified lat/lon - near Beijing airport
##' ## returns 'n' nearest by default
##' getMeta(lat = 40, lon = 116.9)
##' }
getMeta <- function(site = "heathrow", lat = NA, lon = NA,
                    country = NA, state = NA, n = 10, end.year = "current",
                    plot = TRUE, returnMap = FALSE) {
  ## read the meta data

  ## download the file, else use the package version
  meta <- getMetaLive()

  # check year
  if (!any(end.year %in% c("current", "all"))) {
    if (!is.numeric(end.year)) {
      stop("end.year should be one of 'current', 'all' or a numeric 4-digit year such as 2016.")
    }
  }

  # we base the current year as the max available in the meta data
  if ("current" %in% end.year) end.year <- max(as.numeric(format(meta$END, "%Y")), na.rm = TRUE)
  if ("all" %in% end.year) end.year <- 1900:2100



  ## search based on name of site
  if (!missing(site)) {
    ## search for station
    meta <- meta[grep(site, meta$STATION, ignore.case = TRUE), ]
  }

  ## search based on country codes
  if (!missing(country) && !is.na(country)) {
    ## search for country
    id <- which(meta$CTRY %in% toupper(country))
    meta <- meta[id, ]
  }

  ## search based on state codes
  if (!missing(state)) {
    ## search for state
    id <- which(meta$ST %in% toupper(state))
    meta <- meta[id, ]
  }

  # make sure no missing lat / lon
  id <- which(is.na(meta$LON))
  if (length(id) > 0) meta <- meta[-id, ]

  id <- which(is.na(meta$LAT))
  if (length(id) > 0) meta <- meta[-id, ]

  # filter by end year
  id <- which(format(meta$END, "%Y") %in% end.year)
  meta <- meta[id, ]

  ## approximate distance to site
  if (!missing(lat) && !missing(lon)) {
    r <- 6371 # radius of the Earth

    ## Coordinates need to be in radians
    meta$longR <- meta$LON * pi / 180
    meta$latR <- meta$LAT * pi / 180
    LON <- lon * pi / 180
    LAT <- lat * pi / 180
    meta$dist <- acos(sin(LAT) * sin(meta$latR) + cos(LAT) *
      cos(meta$latR) * cos(meta$longR - LON)) * r

    ## sort and retrun top n nearest
    meta <- head(openair:::sortDataFrame(meta, key = "dist"), n)
  }

  dat <- dplyr::rename(meta, latitude = LAT, longitude = LON)

  if (plot) {
    if (!"dist" %in% names(dat)) dat$dist <- NA

    content <- paste(paste(
      dat$STATION,
      paste("Code:", dat$code),
      paste("Start:", dat$BEGIN),
      paste("End:", dat$END),
      paste("Distance (km)", round(dat$dist, 1)),
      sep = "<br/>"
    ))


    m <- leaflet(dat) %>%
      addTiles() %>%
      addMarkers(~ longitude, ~ latitude, popup = content,
                 clusterOptions = markerClusterOptions())

    if (!is.na(lat) && !is.na(lon)) {
      m <- m %>% addCircles(
        lng = lon, lat = lat, weight = 20, radius = 200,
        stroke = TRUE, color = "red",
        popup = paste(
          "Search location",
          paste("Lat =", lat),
          paste("Lon =", lon),
          sep = "<br/>"
        )
      )
    }
    print(m)
  }


  if (returnMap) return(m) else return(dat)
}


#' Obtain site meta data from NOAA server
#'
#' @param ... Currently unused.
#'
#' @return A tibble with meta data.
#' @export
#'
#' @examples
#' \dontrun{
#' meta <- getMetaLive()
#' head(meta)
#' }
getMetaLive <- function(...) {

  ## downloads the whole thing fresh

  url <- "https://www1.ncdc.noaa.gov/pub/data/noaa/isd-history.csv"
  meta <- suppressMessages(read_csv(url, skip = 21, col_names = FALSE,
                                    col_types = cols(
                                      X1 = col_character(),
                                      X2 = col_character(),
                                      X3 = col_character(),
                                      X4 = col_character(),
                                      X5 = col_character(),
                                      X6 = col_character(),
                                      X7 = col_double(),
                                      X8 = col_double(),
                                      X9 = col_double(),
                                      X10 = col_date(format = "%Y%m%d"),
                                      X11 = col_date(format = "%Y%m%d")
                                    )))

  # if not available e.g. due to US Government shutdown, flag and exit
  # some header data may still be read, so check column number
  if (ncol(meta) == 1L) 
    stop("File not available, check \nhttps://www1.ncdc.noaa.gov/pub/data/noaa/ for potential server problems.", call. = FALSE)
  
  ## names in the meta file
  names(meta) <- c(
    "USAF", "WBAN", "STATION", "CTRY", "ST", "CALL", "LAT",
    "LON", "ELEV(M)", "BEGIN", "END"
  )

  ## full character string of site id
  meta$USAF <- formatC(meta$USAF, width = 6, format = "d", flag = "0")

   ## code used to query data
  meta$code <- paste(meta$USAF, meta$WBAN, sep = "-")

  return(meta)
}

# how to update meta data
# meta <- getMeta(fresh = TRUE)
# devtools::use_data(meta, overwrite = TRUE, internal = TRUE)
# devtools::use_data(meta, overwrite = TRUE)
