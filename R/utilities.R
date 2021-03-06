## TODO: Add comment
                                        #
## Author: David Carslaw
## useful utility functions
## with some updates and modification by Karl Ropkins
###############################################################################

startYear <- function(dat) as.numeric(format(min(dat[order(dat)]), "%Y"))
endYear <- function(dat) as.numeric(format(max(dat[order(dat)]), "%Y"))
startMonth <- function(dat) as.numeric(format(min(dat[order(dat)]), "%m"))
endMonth <- function(dat) as.numeric(format(max(dat[order(dat)]), "%m"))

## these are pre-defined type that need a field "date"; used by cutData
dateTypes <- c("year", "hour", "month", "season", "weekday", "weekend",
               "monthyear", "gmtbst", "bstgmt", "dst", "daylight",
               "seasonyear", "yearseason")


###############################################################################

## function to find averaging period of data, returns "xx sec"
## for use in filling in gaps in time series data
## it finds the table of values of time gaps and picks the biggest
## can't think of better way unless user specifies what the time interval is meant to be

find.time.interval <- function(dates) {

    ## could have several sites, dates may be unordered
    ## find the most common time gap in all the data
    dates <- unique(dates)  ## make sure they are unique

    # work out the most common time gap of unique, ordered dates
    id <- which.max(table(diff(as.numeric(unique(dates[order(dates)])))))
    seconds <- as.numeric(names(id))

    if ("POSIXt" %in% class(dates)) seconds <- paste(seconds, "sec")

    if (class(dates)[1] == "Date") {
        seconds <- seconds * 3600 * 24
        seconds <- paste(seconds, "sec")
    }

    seconds
}



date.pad2 <-  function(mydata, type = NULL, interval = "month") {
  
  # assume by the time we get here the data have been split into types
  # This means we just need to pad out the missing types based on first
  # line.
 
  start.date <- min(mydata$date, na.rm = TRUE)
  end.date <- max(mydata$date, na.rm = TRUE)
  
  all.dates <- data.frame(date = seq(start.date, end.date, by = interval))
  mydata <- mydata %>% full_join(all.dates, by = "date")
  
  # add in missing types if gaps are made
  if (!is.null(type))
    mydata[type] <- mydata[1, type]
  
  # make sure order is correct
  mydata <- arrange(mydata, date)
  
  return(mydata)
  
}


## #################################################################
# Function to pad out missing time data
# assumes data have already been split by type, so just take first
# tries to work out time interval of input based on most common gap
# can print assumed gap to screen

date.pad <- function(mydata, type = NULL, print.int = FALSE) {
 
  ## time zone of data
  TZ <- attr(mydata$date, "tzone")
  if (is.null(TZ)) TZ <- "GMT" ## as it is on Windows for BST
  
  ## function to fill missing data gaps
  ## assume no missing data to begin with
  
  
  ## pad out missing data
  start.date <- min(mydata$date, na.rm = TRUE)
  end.date <- max(mydata$date, na.rm = TRUE)
  
  ## interval in seconds
  interval <- find.time.interval(mydata$date)
  
  ## equivalent number of days, used to refine interval for month/year
  days <- as.numeric(strsplit(interval, split = " ")[[1]][1]) /
    24 / 3600
  
  ## find time interval of data
  if (class(mydata$date)[1] == "Date") {
    
    interval <- paste(days, "day")
    
  } else {
    ## this will be in seconds
    interval <- find.time.interval(mydata$date)
    
  }
  
  ## better interval, most common interval in a year
  if (days == 31) interval <- "month"
  if (days %in% c(365, 366)) interval <- "year"
  
  ## only pad if there are missing data
  if (length(unique(diff(mydata$date))) != 1L) {
    
    all.dates <- data.frame(date = seq(start.date, end.date, by = interval))
    mydata <- mydata %>% full_join(all.dates, by = "date")
    
    # add missing types - if type is present
    if (!is.null(type))
      mydata[type] <- mydata[1, type]
  
  }
  
  ## return the same TZ that we started with
  attr(mydata$date, "tzone") <- TZ
  
  if (print.int) print(paste0("Input data time interval assumed is ", interval))
  
  # make sure date-sorted
  mydata <- arrange(mydata, date)
  
  mydata
}
#############################################################################################


## unitility function to convert decimal date to POSIXct
decimalDate <- function(x, date = "date") {
    thedata <- x
    x <- x[, date]
    x.year <- floor(x)
    ## fraction of the year
    x.frac <- x - x.year
    ## number of seconds in each year
    x.sec.yr <- unclass(ISOdate(x.year + 1, 1, 1, 0, 0, 0)) - unclass(ISOdate(x.year, 1, 1, 0, 0, 0))
    ## now get the actual time
    x.actual <- ISOdate(x.year, 1, 1, 0, 0, 0) + x.frac * x.sec.yr
    x.actual <- as.POSIXct(trunc(x.actual, "hours"), "GMT")
    thedata$date <- x.actual
    thedata
}




##' Calculate rollingMean values
##'
##' Calculate rollingMean values taking account of data capture thresholds
##'
##' This is a utility function mostly designed to calculate rolling
##' mean statistics relevant to some pollutant limits e.g. 8 hour
##' rolling means for ozone and 24 hour rolling means for
##' PM10. However, the function has a more general use in helping to
##' display rolling mean values in flexible ways e.g. with the rolling
##' window width left, right or centre aligned.
##'
##' The function will try and fill in missing time gaps to get a full
##' time sequence but return a data frame with the same number of rows
##' supplied.
##'
##' @param mydata A data frame containing a \code{date}
##' field. \code{mydata} must contain a \code{date} field in
##' \code{Date} or \code{POSIXct} format. The input time series must
##' be regular e.g. hourly, daily.
##' @param pollutant The name of a pollutant e.g. \code{pollutant = "o3"}.
##' @param width The averaging period (rolling window width) to use
##' e.g. \code{width = 8} will generate 8-hour rolling mean values
##' when hourly data are analysed.
##' @param new.name The name given to the new rollingMean variable. If
##' not supplied it will create a name based on the name of the
##' pollutant and the averaging period used.
##' @param data.thresh The data capture threshold in %. No values are
##' calculated if data capture over the period of interest is less
##' than this value. For example, with \code{width = 8} and
##' \code{data.thresh = 75} at least 6 hours are required to calculate
##' the mean, else \code{NA} is returned.
##' @param align specifyies how the moving window should be
##' aligned. \code{"right"} means that the previous \code{hours}
##' (including the current) are averaged. This seems to be the default
##' for UK air quality rolling mean statistics. \code{"left"} means
##' that the forward \code{hours} are averaged, and \code{"centre"} or
##' \code{"center"}, which is the default.
##' @param ... other arguments, currently unused.
##' @export
##' @author David Carslaw
##' @keywords methods
##' @examples
##'
##' ## rolling 8-hour mean for ozone
##' mydata <- rollingMean(mydata, pollutant = "o3", width = 8, new.name =
##' "rollingo3", data.thresh = 75, align = "right")
##'
##'
rollingMean <- function(mydata, pollutant = "o3", width = 8, new.name = "rolling",
                         data.thresh = 75, align = "centre", ...){
    ## function to calculate rolling means
    ## uses C++ code

    ## get rid of R check annoyances
    site = NULL
    if (!align %in% c("left", "right", "centre", "center")) stop("align should be one of 'right', 'left', 'centre' or 'center'.")


    if (missing(new.name)) new.name <- paste("rolling", width, pollutant, sep = "")
    if (data.thresh < 0 | data.thresh > 100) stop("Data threshold must be between 0 and 100.")
    
    calc.rolling <- function(mydata, ...) {

        ## data needs to be numeric
        if (!is.numeric(mydata[[pollutant]])) {
            warning("Data are not numeric.")
            return(mydata)
        }

        ## need to know whether dates added
        dates <- mydata$date

        ## pad missing hours
        mydata <- date.pad(mydata)

        ## make sure function is not called with window width longer than data
        if (width > nrow(mydata)) return(mydata)

        mydata[[new.name]] <- .Call("rollingMean", mydata[[pollutant]],
                                    width, data.thresh, align,
                                    PACKAGE = "ggopenair")

        if (length(dates) != nrow(mydata)) {
            ## return what was put in
            ## avoids adding missing data e.g. for factors
            mydata <- mydata[mydata$date %in% dates, ]
        }

        mydata
    }

    ## split if several sites
    if ("site" %in% names(mydata)) { ## split by site

        mydata <- group_by(mydata, site) %>%
            do(calc.rolling(., ...))

        mydata
        
    } else {
        
        mydata <- calc.rolling(mydata, ...)
        mydata
    }

}




convert.date <- function(mydata, format = "%d/%m/%Y %H:%M") {
    mydata$date <- as.POSIXct(strptime(mydata$date, format = format), "GMT")
    mydata
}



#############################################################################################
## splits data frame into date chunks. Allows users to supply simple dates and labels
## useful for type = "site", interventions



##' Divide up a data frame by time
##'
##' Utility function to prepare input data for use in openair functions
##'
##' This function partitions a data frame up into different time segments. It
##' produces a new column called controlled by \code{name} that can be used in many
##' \code{openair} functions. Note that there must be one more label than there
##' are dates. See examples below and in full \code{openair} documentation.
##'
##' @param mydata A data frame containing a \code{date} field in hourly or high
##'   resolution format.
##' @param dates A date or dates to split data by.
##' @param labels Labels for each time partition.
##' @param name The name to give the new column to identify the periods split
##' @export
##' @author David Carslaw
##' @keywords methods
##' @examples
##'
##' ## split data up into "before" and "after"
##' mydata <- splitByDate(mydata, dates = "1/04/2000",
##' labels = c("before", "after"))
##'
##' ## split data into 3 partitions:
##' mydata <- splitByDate(mydata, dates = c("1/1/2000", "1/3/2003"),
##' labels = c("before", "during", "after"))
##'
##'
splitByDate <- function(mydata, dates = "1/1/2003", labels = c("before", "after"), name = "split.by") {
    ## if date in format dd/mm/yyyy hh:mm (basic check)
    if (missing(mydata)) stop("No data frame was supplied!")

    mydata <- checkPrep(mydata, names(mydata), "default", remove.calm = FALSE)
    ## check there are sufficent labels for number of dates
    if (length(dates) != length(labels) - 1) {
        stop("There is a mis-match between dates and labels. There should be
one more label than date")
    }

    if (length(grep("/", as.character(dates))) > 0) {

        if (class(mydata$date)[1] == "Date") {

            dates <- as.Date(as.POSIXct(strptime(dates, "%d/%m/%Y"), "GMT"))

        } else {

            dates <- as.POSIXct(strptime(dates, "%d/%m/%Y"), "GMT")

        }

    } else { ## asume format yyyy-mm-dd

        if (class(mydata$date)[1] == "Date") {

            dates <- as.Date(dates)

        } else {

            dates <- as.POSIXct(dates, "GMT")

        }


    }


    mydata[ , name] <- cut(as.numeric(mydata$date), breaks = c(0, as.numeric(dates),
                                                max(mydata$date)), labels = labels,
                       ordered_result = TRUE)
    mydata
}
#############################################################################################

## function to make it easy to use d/m/y format for subsetting by date


##' Subset a data frame based on date
##'
##' Utility function to make it easier to select periods from a data frame
##' before sending to a function
##'
##' This function makes it much easier to select periods of interest from a
##' data frame based on dates in a British format. Selecting date/times in R
##' format can be intimidating for new users. This function can be used to
##' select quite complex dates simply - see examples below.
##'
##' Dates are assumed to be inclusive, so \code{start = "1/1/1999"}
##' means that times are selected from hour zero. Similarly, \code{end
##' = "31/12/1999"} will include all hours of the 31st
##' December. \code{start} and \code{end} can also be in standard R
##' format as a string i.e. "YYYY-mm-dd", so \code{start =
##' "1999-01-01"} is fine.
##'
##' All options are applied in turn making it possible to select quite complex
##' dates
##'
##' @param mydata A data frame containing a \code{date} field in hourly or high
##'   resolution format.
##' @param start A start date string in the form d/m/yyyy
##' e.g. \dQuote{1/2/1999} or in \sQuote{R} format
##' i.e. \dQuote{YYYY-mm-dd}, \dQuote{1999-02-01}
##' @param end See \code{start} for format.
##' @param year A year or years to select e.g. \code{year = 1998:2004} to
##'   select 1998-2004 inclusive or \code{year = c(1998, 2004)} to select 1998
##'   and 2004.
##' @param month A month or months to select. Can either be numeric e.g.
##'   \code{month = 1:6} to select months 1-6 (January to June), or by name
##'   e.g. \code{month = c("January", "December")}. Names can be abbreviated to
##'   3 letters and be in lower or upper case.
##' @param day A day name or or days to select. \code{day} can be
##' numeric (1 to 31) or character. For example \code{day =
##' c("Monday", "Wednesday")} or \code{day = 1:10} (to select the 1st
##' to 10th of each month). Names can be abbreviated to 3 letters and
##' be in lower or upper case. Also accepts \dQuote{weekday} (Monday -
##' Friday) and \dQuote{weekend} for convenience.
##' @param hour An hour or hours to select from 0-23 e.g. \code{hour = 0:12} to
##'   select hours 0 to 12 inclusive.
##' @importFrom lubridate dst year month hour force_tz day
##' @export
##' @author David Carslaw
##' @keywords methods
##' @examples
##'
##' ## select all of 1999
##' data.1999 <- selectByDate(mydata, start = "1/1/1999", end = "31/12/1999")
##' head(data.1999)
##' tail(data.1999)
##'
##' # or...
##' data.1999 <- selectByDate(mydata, start = "1999-01-01", end = "1999-12-31")
##'
##' # easier way
##' data.1999 <- selectByDate(mydata, year = 1999)
##'
##'
##' # more complex use: select weekdays between the hours of 7 am to 7 pm
##' sub.data <- selectByDate(mydata, day = "weekday", hour = 7:19)
##'
##' # select weekends between the hours of 7 am to 7 pm in winter (Dec, Jan, Feb)
##' sub.data <- selectByDate(mydata, day = "weekend", hour = 7:19, month =
##' c("dec", "jan", "feb"))
##'
selectByDate <- function (mydata, start = "1/1/2008", 
                          end = "31/12/2008", year = 2008,
    month = 1, day = "weekday", hour = 1)

{
     ## extract variables of interest
    vars <- names(mydata)

    ## check data - mostly date format
    mydata <- checkPrep(mydata, vars, "default", remove.calm = FALSE, 
                        strip.white = FALSE)

    weekday.names <- format(ISOdate(2000, 1, 3:9), "%A")


    if (!missing(start) & !missing(end)) {

        if (length(grep("/", start)) > 0 & length(grep("/", end)) > 0) {
            ## assume UK date format
            start <- as.Date(start, "%d/%m/%Y")
            end <- as.Date(end, "%d/%m/%Y")
        }

        if (length(grep("-", start)) > 0 & length(grep("-", end)) > 0) {
            ## assume R date format
            start <- as.Date(start)
            end <- as.Date(end)
        }

        mydata <- subset(mydata, as.Date(date) >= start & as.Date(date) <= end)

    }
    
    if (!missing(year)) 
      mydata <- mydata[which(year(mydata$date) %in% year), ]
        

    if (!missing(month)) {
        if (is.numeric(month)) {
            if (any(month < 1 | month > 12)) 
              stop ("Month must be between 1 to 12.")
            
          mydata <- mydata[which(month(mydata$date) %in% month), ]
           
        }
      
        else {
            mydata <- subset(mydata, substr(tolower(format(date,
                "%B")), 1, 3) %in% substr(tolower(month), 1, 3))
        }
    }
    if (!missing(hour)) {
        if (any(hour < 0 | hour > 23)) stop ("Hour must be between 0 to 23.")
      
      mydata <- mydata[which(hour(mydata$date) %in% hour), ]
       
    }

    if (!missing(day)) {
        days <- day

        if (is.numeric(day)) {

            if (any(day < 1 | day > 31)) 
              stop ("Day must be between 1 to 31.")
          mydata <- mydata[which(day(mydata$date) %in% day), ]

        } else {

            if (day[1] == "weekday")
                days <- weekday.names[1:5]
            if (day[1] == "weekend")
                days <- weekday.names[6:7]
            mydata <- subset(mydata, substr(tolower(format(date, "%A")), 1, 3) %in%
                             substr(tolower(days), 1, 3))
        }
    }
    mydata
}



### panel functions for plots based on lattice ####################################################

panel.gam <- function (x, y, form = y ~ x, method = "loess", k = k, Args, ..., simulate = FALSE, n.sim = 200,
                       autocor = FALSE, se = TRUE,
                       level = 0.95, n = 100, col = plot.line$col, col.se = col,
                       lty = plot.line$lty, lwd = plot.line$lwd, alpha = plot.line$alpha,
                       alpha.se = 0.20, border = NA, subscripts, group.number, group.value,
                       type, col.line, col.symbol, fill, pch, cex, font, fontface,
                       fontfamily)
{

    ## panel function to add a smooth line to a plot
    ## Uses a GAM (mgcv) to fit smooth
    ## Optionally can plot 95% confidence intervals and run bootstrap simulations
    ## to estimate uncertainties. Simple block bootstrap is also available for correlated data

    ## get rid of R check annoyances#
    plot.line = NULL

    thedata <- data.frame(x = x, y = y)
    thedata <- na.omit(thedata)
    
    tryCatch({
        
        if (!simulate) {

            if (is.null(k)) {
                mod <- suppressWarnings(gam(y ~ s(x), select = TRUE, data = thedata, ...))

            } else {
                mod <- suppressWarnings(gam(y ~ s(x, k = k), select = TRUE, data = thedata, ...))
            }


            lims <- current.panel.limits()
            xrange <- c(max(min(lims$x), min(x, na.rm = TRUE)), min(max(lims$x), max(x, na.rm = TRUE)))
            xseq <- seq(xrange[1], xrange[2], length = n)

            ## for uncertainties
            std <- qnorm(level / 2 + 0.5)

            pred <- predict(mod, data.frame(x = xseq), se = se)


            results <- data.frame(date = xseq, pred = pred$fit,
                                  lower = pred$fit - std * pred$se,
                                  upper = pred$fit + std * pred$se)

            if (se) {

                panel.polygon(x = c(xseq, rev(xseq)), y = c(pred$fit -
                                                      std * pred$se, rev(pred$fit + std * pred$se)),
                              col = col.se, alpha = alpha.se, border = border)
                pred <- pred$fit
            }

            panel.lines(xseq, pred, col = col, alpha = alpha, lty = lty, lwd = 2)

        } else { ## simulations required

            sam.size <- length(x)

            lims <- current.panel.limits()
            xrange <- c(max(min(lims$x), min(x)), min(max(lims$x), max(x)))
            xseq <- seq(xrange[1], xrange[2], length = sam.size)

            boot.pred <- matrix(nrow = sam.size, ncol = n.sim)

            print ("Taking bootstrap samples. Please wait...")

            ## set up bootstrap
            block.length <- 1

            if (autocor) block.length <- round(sam.size ^ (1 / 3))
            index <- samp.boot.block(sam.size, n.sim, block.length)

            ## predict first
            if (is.null(k)) {
                mod <- gam(y ~ s(x), data = thedata, ...)
            } else {
                 mod <- gam(y ~ s(x, k = k), data = thedata, ...)
            }

            residuals <- residuals(mod) ## residuals of the model

            pred.input <- predict(mod, thedata)

            for (i in 1:n.sim) {
                ## make new data
                new.data <- data.frame(x = xseq, y = pred.input + residuals[index[, i]])

                mod <- gam(y ~ s(x), data = new.data, ...)

                pred <- predict(mod, new.data)

                boot.pred[, i] <- as.vector(pred)

            }

            ## calculate percentiles
            percentiles <- apply(boot.pred, 1, function(x) quantile(x, probs = c(0.025, 0.975)))

            results <- as.data.frame(cbind(pred = rowMeans(boot.pred),
                                           lower = percentiles[1, ], upper = percentiles[2, ]))

            if (se) {

                panel.polygon(x = c(xseq, rev(xseq)), y = c(results$lower, rev(results$upper)),
                              col = col.se, alpha = alpha.se, border = border)

            }

            panel.lines(xseq, pred.input, col = col, alpha = alpha, lty = lty, lwd = 2)

        }
        results
    }, error = function(x) return)
}


## version of GAM fitting not for plotting - need to rationalise both...
fitGam <- function (thedata, x = "date", y = "conc", form = y ~ x, k = k,
                        Args, ..., simulate = FALSE, n.sim = 200, autocor = FALSE, se = TRUE,
                       level = 0.95, n = 100)
{

    ## panel function to add a smooth line to a plot
    ## Uses a GAM (mgcv) to fit smooth
    ## Optionally can plot 95% confidence intervals and run bootstrap simulations
    ## to estimate uncertainties. Simple block bootstrap is also available for correlated data

    data.orig <- thedata ## return this if all else fails

    id <- which(names(thedata) == x)
    names(thedata)[id] <- "x"
    id <- which(names(thedata) == y)
    names(thedata)[id] <- "y"
    
    # can only fit numeric, so convert back after fitting
    class_x <- class(thedata$x)

    thedata$x <- as.numeric(thedata$x)

    tryCatch({

        if (!simulate) {

            if (is.null(k)) {
                mod <- suppressWarnings(gam(y ~ s(x), select = TRUE, data = thedata, ...))

            } else {
                mod <- suppressWarnings(gam(y ~ s(x, k = k), select = TRUE, data = thedata, ...))
            }

            xseq <- seq(min(thedata$x, na.rm = TRUE), max(thedata$x, na.rm = TRUE), length = n)

            ## for uncertainties
            std <- qnorm(level / 2 + 0.5)

            pred <- predict(mod, data.frame(x = xseq), se = se)


            results <- data.frame(date = xseq, pred = pred$fit,
                                  lower = pred$fit - std * pred$se,
                                  upper = pred$fit + std * pred$se)

        } else { ## simulations required

            sam.size <- nrow(thedata)

            xseq <- seq(min(thedata$x, na.rm = TRUE), max(thedata$x, na.rm = TRUE), length = n)

            boot.pred <- matrix(nrow = sam.size, ncol = n.sim)

            print ("Taking bootstrap samples. Please wait...")

            ## set up bootstrap
            block.length <- 1

            if (autocor) block.length <- round(sam.size ^ (1 / 3))
            index <- samp.boot.block(sam.size, n.sim, block.length)

            ## predict first
            if (is.null(k)) {
                mod <- gam(y ~ s(x), data = thedata, ...)
            } else {
                 mod <- gam(y ~ s(x, k = k), data = thedata, ...)
            }

            residuals <- residuals(mod) ## residuals of the model

            pred.input <- predict(mod, thedata)

            for (i in 1:n.sim) {
                ## make new data
                new.data <- data.frame(x = xseq, y = pred.input + residuals[index[, i]])

                mod <- gam(y ~ s(x), data = new.data, ...)

                pred <- predict(mod, new.data)

                boot.pred[, i] <- as.vector(pred)

            }

            ## calculate percentiles
            percentiles <- apply(boot.pred, 1, function(x) quantile(x, probs = c(0.025, 0.975)))

            results <- as.data.frame(cbind(pred = rowMeans(boot.pred),
                                           lower = percentiles[1, ], upper = percentiles[2, ]))

        }
      
      # convert class back to orginal
      class(results$x) <- class_x
        results
    }, error = function(x) {data.orig})
}


#########################################################################################################



## error in mean from Hmisc

errorInMean <- function (x, mult = qt((1 + conf.int)/2, n - 1), conf.int = 0.95,
                         na.rm = TRUE)
{
    if (na.rm)
        x <- x[!is.na(x)]
    n <- length(x)
    if (n < 2)
        return(c(Mean = mean(x), Lower = NA, Upper = NA))
    xbar <- sum(x)/n
    se <- sqrt(sum((x - xbar)^2)/n/(n - 1))
    c(Mean = xbar, Lower = xbar - mult * se, Upper = xbar + mult *
      se)
}

## bootsrap confidence intervals in the mean from Hmisc
bootMean <- function (x, conf.int = 0.95, B = 1000, na.rm = TRUE, reps = FALSE, ...)
{
    if (na.rm)
        x <- x[!is.na(x)]
    n <- length(x)
    xbar <- mean(x)
    if (n < 2)
        return(c(Mean = xbar, Lower = NA, Upper = NA))
    z <- unlist(lapply(1:B, function(i, x, N)
                       sum(x[(sample.int(N, N, TRUE, NULL))]), x = x, N = n)) / n
    quant <- quantile(z, c((1 - conf.int) / 2, (1 + conf.int) / 2))
    names(quant) <- NULL
    res <- c(Mean = xbar, Lower = quant[1], Upper = quant[2])
    if (reps)
        attr(res, "reps") <- z
    res
}

bootMeanDiff <- function (mydata, x = "x", y = "y", conf.int = 0.95, B = 1000, na.rm = TRUE, reps = TRUE)
{

    ## calculates bootstrap mean differences
    ## assumes y - x
    x.name <- x
    y.name <- y
    x <- na.omit(mydata[[x]])
    y <- na.omit(mydata[[y]])
    Mean <- mean(y) - mean(x)

    if (nrow(mydata) < 2) {
        res1 <- data.frame(variable = x.name, Mean = mean(x), Lower = NA, Upper = NA)
        res2 <- data.frame(variable = y.name, Mean = mean(y), Lower = NA, Upper = NA)
        res <- data.frame(variable = paste(y.name, "-", x.name), Mean = Mean, Lower = NA, Upper = NA)

        res <- bind_rows(res1, res2, res)
        res$variable <- factor(res$variable)
        return(res)

    }

    x <- attr(bootMean(x,  B = B, reps = TRUE), 'reps')
    y <- attr(bootMean(y,  B = B, reps = TRUE), 'reps')
    quant1 <- quantile(x, c((1 - conf.int) / 2, (1 + conf.int) / 2))
    quant2 <- quantile(y, c((1 - conf.int) / 2, (1 + conf.int) / 2))
    quant <- quantile(y - x, c((1 - conf.int) / 2, (1 + conf.int) / 2))
    names(quant1) <- NULL
    names(quant2) <- NULL
    names(quant) <- NULL

    res1 <- data.frame(variable = x.name, Mean = mean(x), Lower = quant1[1], Upper = quant1[2])
    res2 <- data.frame(variable = y.name, Mean = mean(y), Lower = quant2[1], Upper = quant2[2])
    res <- data.frame(variable = paste(y.name, "-", x.name), Mean = Mean, Lower = quant[1], Upper = quant[2])

    res <- bind_rows(res1, res2, res)
    res$variable <- factor(res$variable)
    res
}

###########################################################################################################

## list update function
## for lattice type object structure and ... handling

## (currently used by)
## (all openair plots that include colorkey controlled by drawOpenKey)

##listUpdate function
#[in development]
listUpdate <- function(a, b, drop.dots = TRUE,
                       subset.a = NULL, subset.b = NULL){
    if(drop.dots){
        a <- a[names(a) != "..."]
        b <- b[names(b) != "..."]
    }
    if(!is.null(subset.a))
        a <- a[names(a) %in% subset.a]
    if(!is.null(subset.b))
        b <- b[names(b) %in% subset.b]
    if(length(names(b) > 0))
        a <- modifyList(a, b)
    a
}

#############################################################################################################

## makeOpenKeyLegend v0.1

##common code for making legend list
##objects for use with drawOpenkey outputs

##uses listUpdate in utilities

makeOpenKeyLegend <- function(key, default.key, fun.name = "function"){
    #handle logicals and lists
    if (is.logical(key)) {
        legend <- if (key) default.key else NULL
    } else if (is.list(key)) {
            legend <- listUpdate(default.key, key)
        } else {
            if(!is.null(key))
                warning(paste("In ", fun.name, "(...):\n unrecognised key not exported/applied\n",
                              " [see ?drawOpenKey for key structure/options]", sep = ""),
                        call. = FALSE)
            legend <- NULL
    }

    #structure like legend for drawOpenKey
    if(!is.null(legend)){
        legend <- list(right = list(fun = drawOpenKey, args = list(key = legend),
                         draw =FALSE))
        if("space" %in% names(legend$right$args$key))
            names(legend)[[1]] <- legend$right$args$key$space
    }
    legend
}

 ## polygon that can deal with missing data for use in lattice plots with groups
poly.na <- function(x1, y1, x2, y2, group.number, myColors, alpha = 0.4, border = NA) {
    for(i in seq(2, length(x1)))
        if (!any(is.na(y2[c(i - 1, i)])))
            lpolygon(c(x1[i - 1], x1[i], x2[i], x2[i - 1]),
                     c(y1[i - 1], y1[i], y2[i], y2[i - 1]),
                     col = myColors[group.number], border = border, alpha = alpha)
}


## gives names of lattice strips
strip.fun <- function(results.grid, type, auto.text) {
    ## proper names of labelling ###################################################
    pol.name <- sapply(levels(factor(results.grid[[type[1]]])),
                       function(x) quickText(x, auto.text, expression = FALSE))
    
    
    pol.name2 <- NULL

    if (length(type) != 1 ) {

         ## two conditioning variables

        pol.name2 <- sapply(levels(factor(results.grid[[type[2]]])),
                           function(x) quickText(x, auto.text, expression = FALSE))
       
        
    }
    if (length(type) == 1 & type[1] == "default") strip <- FALSE ## remove strip
    list(pol.name, pol.name2)
}



## from lattice
chooseFace <- function (fontface = NULL, font = 1)
{
    if (is.null(fontface))
        font
    else fontface
}


## .smoothScatterCalcDensity() is also in graphics, but not exported.
.smoothScatterCalcDensity <- function(x, nbin, bandwidth, range.x)
{
    if (!("KernSmooth" %in% loadedNamespaces())) {
        ns <- try(loadNamespace("KernSmooth"))
        if (isNamespace(ns))
            message("(loaded the KernSmooth namespace)")
        else stop("panel.smoothScatter() requires the KernSmooth package, but unable to load KernSmooth namespace")
    }
    if (length(nbin) == 1)
        nbin <- c(nbin, nbin)
    if (!is.numeric(nbin) || (length(nbin)!=2)) stop("'nbin' must be numeric of length 1 or 2")
    if (missing(bandwidth)) {
        bandwidth <- diff(apply(x, 2, quantile, probs=c(0.05, 0.95), na.rm=TRUE)) / 25
    } else {
        if(!is.numeric(bandwidth)) stop("'bandwidth' must be numeric")
    }
    bandwidth[bandwidth==0] <- 1
    ## create density map
    if(missing(range.x))
        rv <- KernSmooth::bkde2D(x, gridsize=nbin, bandwidth=bandwidth)
    else
        rv <- KernSmooth::bkde2D(x, gridsize=nbin, bandwidth=bandwidth, range.x=range.x)
    rv$bandwidth <- bandwidth
    return(rv)
}


Cquantile <- function(x, probs = 0.5) {
    ## Quick (but basic) C++ quantile function

    if (!is.numeric(x))
        stop("Quantiles only work for numeric data")
    
    if (any(probs < 0) | any(probs > 1))
        stop("Probabilities should be betweem 0 and 1")

    if (all(is.na(x))) return(NA)

    res <- Cquant(x, probs)
    
    return(res)
    
}



## simple rounding function from plyr
round_any <- function(x, accuracy, f = round) {
  f(x / accuracy) * accuracy
}

## pretty gap calculator
prettyGap <- function(x, n = 100) {
    return(diff(pretty(x, n))[1])
}

# function to check variables are numeric, if not force with warning
checkNum <- function(mydata, vars) {
 
  for (i in seq_along(vars)) {
    
    if (!is.numeric(mydata[[vars[i]]])) {
     
      mydata[[vars[i]]] <- as.numeric(as.character(mydata[[vars[i]]]))
     
      warning(paste(vars[i], "is not numeric, forcing to numeric..."),
              call. = FALSE)
    }
  }
  
  return(mydata)
}

# Multiple plot function
#
# ggplot objects can be passed in ..., or to plotlist (as a list of ggplot objects)
# - cols:   Number of columns in layout
# - layout: A matrix specifying the layout. If present, 'cols' is ignored.
#
# If the layout is something like matrix(c(1,2,3,3), nrow=2, byrow=TRUE),
# then plot 1 will go in the upper left, 2 will go in the upper right, and
# 3 will go all the way across the bottom.
#
multiplot <- function(..., plotlist = NULL, file, cols = 1, layout = NULL) {
  library(grid)
  
  # Make a list from the ... arguments and plotlist
  plots <- c(list(...), plotlist)
  
  numPlots = length(plots)
  
  # If layout is NULL, then use 'cols' to determine layout
  if (is.null(layout)) {
    # Make the panel
    # ncol: Number of columns of plots
    # nrow: Number of rows needed, calculated from # of cols
    layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                     ncol = cols, nrow = ceiling(numPlots/cols))
  }
  
  if (numPlots==1) {
    print(plots[[1]])
    
  } else {
    # Set up the page
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))
    
    # Make each plot, in the correct location
    for (i in 1:numPlots) {
      # Get the i,j matrix positions of the regions that contain this subplot
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))
      
      print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                      layout.pos.col = matchidx$col))
    }
  }
}



