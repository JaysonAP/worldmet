##' Main function for importing meteorological data
##' 
##' This is the main function to import data from the NOAA Integrated Surface 
##' Database (ISD). The ISD contains detailed surface meteorological data from 
##' around the world for over 30,000 locations. For general information of the 
##' ISD see \url{https://www.ncdc.noaa.gov/isd} and the map here 
##' \url{https://gis.ncdc.noaa.gov/map/viewer/#app=cdo&cfg=cdo&theme=hourly&layers=1}.
##' 
##' Note the following units for the main variables:
##' 
##' \describe{
##' 
##' \item{date}{Date/time in POSIXct format. \strong{Note the time zone is GMT 
##' (UTC) and may need to be adjusted to merge with other local data. See 
##' details below.}}
##' 
##' \item{lat}{Latitude in decimal degrees (-90 to 90).}
##' 
##' \item{lon}{Longitude in decimal degrees (-180 to 180). Negative numbers are 
##' west of the Greenwich Meridian.}
##' 
##' \item{elev}{Elevention of site in metres.}
##' 
##' \item{wd}{Wind direction in degrees. 90 is from the east.}
##' 
##' \item{ws}{Wind speed in m/s.}
##' 
##' \item{sky_ceiling}{The height above ground level (AGL) of the lowest cloud 
##' or obscuring phenomena layer aloft with 5/8 or more summation total sky 
##' cover, which may be predominantly opaque, or the vertical visibility into a 
##' surface-based obstruction.}
##' 
##' \item{visibility}{The visibility in metres.}
##' 
##' \item{air_temp}{Air temperature in degrees Celcius.}
##' 
##' \item{dew_point}{The dew point temperature in degrees Celcius.}
##' 
##' \item{sea_level_press}{The sea level pressure in millibars.}
##' 
##' \item{RH}{The relative humidity (\%).}
##' 
##' \item{cl_1,  ...,  cl_3}{Cloud cover for different layers in Oktas (1-8).}
##' 
##' \item{cl}{Maximum of cl_1 to cl_3 cloud cover in Oktas (1-8).}
##' 
##' \item{cl_1_height, ..., cl_3_height}{Height of the cloud base for each later
##' in metres.}
##' 
##' \item{pwc}{The description of the present weather description (if 
##' available).}
##' 
##' }
##' 
##' The data are returned in GMT (UTC). It may be necessary to adjust the time 
##' zone when comining with other data. For example, if air quality data were 
##' available for Beijing with time zone set to "Etc/GMT-8" (note the negative 
##' offset even though Beijing is ahead of GMT. See the \code{openair} package 
##' and manual for more details), then the time zone of the met data can be 
##' changed to be the same. One way of doing this would be \code{attr(met$date, 
##' "tzone") <- "Etc/GMT-8"} for a meteorological data frame called \code{met}. 
##' The two data sets could then be merged based on \code{date}.
##' 
##' @title Import meteorological data
##'   
##' @param code The identifing code as a character string. The code is a 
##'   combination of the USAF and the WBAN unique identifiers. The codes are 
##'   sperated by a \dQuote{-} e.g. \code{code = "037720-99999"}.
##' @param year The year to import. This can be a vector of years e.g. 
##'   \code{year = 2000:2005}.
##' @param hourly Should hourly means be calculated? The default is \code{TRUE}. If \code{FALSE} then the raw data are returned. 
##' @param PWC Description of the present weather conditions (if available).
##' @export
##' @import openair
##' @import plyr
##' @return Returns a data frame of surface observations. The data frame is 
##'   consistent for use with the \code{openair} package. NOTE! the data are 
##'   returned in GMT (UTC) time zone format. Users may wish to express the data
##'   in other time zones e.g. to merge with air pollution data.
##' @seealso \code{\link{getMeta}} to obtain the codes based on various site 
##'   search approaches.
##' @author David Carslaw
##' @examples 
##' 
##' \dontrun{
##' ## use Beijing airport code (see getMeta example)
##' dat <- importNOAA(code = "545110-99999", year = 2010:2011)
##' }
importNOAA <- function(code = "037720-99999", year = 2014, hourly = TRUE, PWC = FALSE) {
  
  ## main web site https://www.ncdc.noaa.gov/isd
  
  ## formats document ftp://ftp.ncdc.noaa.gov/pub/data/noaa/ish-format-document.pdf
  
  ## gis map https://gis.ncdc.noaa.gov/map/viewer/#app=cdo&cfg=cdo&theme=hourly&layers=1
  
  ## go through each of the years selected
  dat <- plyr::ldply(year, getDat, code = code, hourly = hourly, PWC = PWC)
  
  return(dat)
  
}

getDat <- function(code, year, hourly, PWC) {
  
  ## location of data
  file.name <- paste0("ftp://ftp.ncdc.noaa.gov/pub/data/noaa/",
                      year, "/", code, "-", year, ".gz")
  
  z <- gzcon(url(file.name))
  
  ## read.table can only read from a text-mode connection.
  ## note the last set of data 'V32' is the additional data that contains cloud cover etc.
  
  ## deal with any missing data, issue warning
  raw <- try(textConnection(readLines(z)), TRUE)
  if (!inherits(raw, "try-error")) {
    
    close(z)
    
  } else {
    
    warning(call. = FALSE, paste0("Data for ", year, " does not exist on server"))
    return()
  }
  
  dat <- read.fwf(raw, header = FALSE, widths = c(4, 6, 5, 8, 4, 1, 6, 7, 5, 
                                                  5, 5, 4, 3, 1, 1, 4, 1, 5, 1, 
                                                  1, 1, 6, 1, 1, 1, 5, 1, 5, 1, 
                                                  5, 1, 1000))
  close(raw)
  
  ## make a POSIXct date, all dates are UTC
  dat$date <- paste(dat$V4, formatC(dat$V5, width = 4, format = "d", flag = "0"))
  dat$date <- as.POSIXct(strptime(dat$date, format = "%Y%m%d %H%M", tz = "GMT"),
                         tz = "GMT")
  
  ## of Names variables
  names(dat)[1:31] <- c('var_length', 'usaf_id', 'wban', 'dateX', 'gmt', 'data_source',
                        'lat', 'long', 'report_type', 'elev', 'call_letters', 'qc_level',
                        'wd', 'wind_dir_flag', 'wind_type', 'ws', 'wind_speed_flag',
                        'sky_ceiling', 'sky_ceil_flag', 'sky_ceil_determ', 'sky_cavok',
                        'visibility', 'vis_flag', 'vis_var', 'vis_var_flag', 'air_temp',
                        'air_temp_flag', 'dew_point', 'dew_point_flag', 'sea_lev_press',
                        'sea_levp_flag')
  
  ## find and set missing
  id <- which(dat$wd == 999)
  dat$wd[id] <- NA
  
  id <- which(dat$ws == 9999)
  dat$ws[id] <- NA
  
  id <- which(dat$sky_ceiling == 99999)
  dat$sky_ceiling[id] <- NA
  
  id <- which(dat$visibility == 999999)
  dat$visibility[id] <- NA
  
  id <- which(dat$air_temp == 9999)
  dat$air_temp[id] <- NA
  
  id <- which(dat$dew_point == 9999)
  dat$dew_point[id] <- NA
  
  id <- which(dat$sea_lev_press== 99999)
  dat$sea_lev_press[id] <- NA
  
  ## used for calms in openair
  id <- which(dat$ws == 0)
  dat$wd[id] <- 0
  
  ## sort out the units
  dat$lat <- dat$lat / 1000
  dat$long <- dat$long / 1000
  dat$ws <- dat$ws / 10
  dat$air_temp <- dat$air_temp / 10
  dat$sea_lev_press <- dat$sea_lev_press / 10
  dat$dew_point <- dat$dew_point / 10
  
  ## relative humidity - general formula based on T and dew point
  dat$RH <- 100 * ((112 - 0.1 * dat$air_temp + dat$dew_point) /
                     (112 + 0.9 * dat$air_temp)) ^ 8
    
  ## process the additional data separately
  dat <- procAddit(dat, PWC)
  
  ## for cloud cover, make new 'cl' max of 3 cloud layers
  dat$cl <- pmax(dat$cl_1, dat$cl_2, dat$cl_3, na.rm = TRUE)
  
  ## select the variables we want
  dat <- dat[names(dat) %in% c("date", "ws", "wd", "air_temp", "sea_lev_press",
                               "visibility", "dew_point", "RH", "sky_ceiling", "lat",
                               "long", "elev", "cl_1", "cl_2", "cl_3", "cl",
                               "cl_1_height", "cl_2_height", "cl_3_height", "pwc")]
  
  ## present weather is character and cannot be averaged, take first
    if ("pwc" %in% names(dat) && hourly) {
    
    pwc <- dat[c("date", "pwc")]
    pwc$date2 <- format(pwc$date, "%Y-%m-%d %H") ## nearest hour
    tmp <- pwc[which(!duplicated(pwc$date2)), ]
    dates <- as.POSIXct(paste0(unique(pwc$date2), ":00:00"), tz = "GMT")
    
    pwc <- data.frame(date = dates, pwc = tmp$pwc)
    PWC <- TRUE
  }
  
  ## average to hourly
  if (hourly)
    dat <- openair::timeAverage(dat, avg.time = "hour")
  
  ## add pwc back in
  if (PWC)
    dat <- merge(dat, pwc, by = "date", all = TRUE)
  
  return(dat)
  
}

procAddit <- function(dat, PWC) {
  
  ## function to process additional data such as cloud cover
  
  ## consider first 3 layers of cloud GA1, GA2, GA3
  dat <- extractCloud(dat, "GA1", "cl_1")
  dat <- extractCloud(dat, "GA2", "cl_2")
  dat <- extractCloud(dat, "GA3", "cl_3")
  
  if (PWC)
    dat <- extractCurrentWeather(dat, "AW1")
  
  return(dat)
  
}

extractCloud <- function(dat, field = "GA1", out = "cl_1") {
  
  ## 3 fields are used: GA1, GA2 and GA3
  
  height <- paste0(out, "_height") ## cloud height field
  
  ## fields that contain search string
  id <- grep(field, dat[ , "V32"])
  
  ## variables for cloud amount (oktas) and cloud height
  dat[[out]] <- NA
  dat[[height]] <- NA
  
  if (length(id) > 1) {
    
    ## location of begining of GA1 etc
    loc <- sapply(id, function (x) regexpr(field, dat[x, "V32"]))
    
    ## extract the variable
    cl <- sapply(seq_along(id), function (x)
      substr(dat$V32[id[x]], start = loc[x] + 3, stop = loc[x] + 4))
    cl <- as.numeric(cl)
    
    miss <- which(cl > 8) ## missing or obscured in some way
    if (length(miss) > 0) cl[miss] <- NA
    
    ## and height of cloud
    h <- sapply(seq_along(id), function (x)
      substr(dat$V32[id[x]], start = loc[x] + 6, stop = loc[x] + 11))
    h <- as.numeric(h)
    
    miss <- which(h == 99999)
    if (length(miss) > 0) h[miss] <- NA
    
    dat[[out]][id] <- cl
    dat[[height]][id] <- h
    
  }
  
  return(dat)
  
}

extractCurrentWeather <- function(dat, field = "AW1") {
  
  ## extracts the present weather description based on code
  
  ## fields that contain search string
  id <- grep(field, dat[ , "V32"])
  
  if (length(id) > 1) {
    
    ## name of output variable
    dat[["pwc"]] <- NA
    
    ## location of begining of AW1
    loc <- sapply(id, function (x) regexpr(field, dat[x, "V32"]))
    
    ## extract the variable
    pwc <- sapply(seq_along(id), function (x)
      substr(dat$V32[id[x]], start = loc[x] + 3, stop = loc[x] + 4))
    pwc <- as.character(pwc)
    
    ## look up code in weatherCodes.RData
    
    desc <- sapply(pwc, function(x)
      weatherCodes$description[which(weatherCodes$pwc == x)])
    
    dat[["pwc"]][id] <- desc
    
  } else {
    
    return(dat)
    
  }
  
  return(dat)
  
}

