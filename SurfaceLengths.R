# SurfaceLengths.R
# ref: http://en.wikipedia.org/wiki/Latitude#The_length_of_a_degree_of_latitude

SurfaceLengths.OneDegree <- function(latitudeDegrees) {
  # Determine surface distance in latitude and longitude of a one degree change at latitude.
  #
  # Args:
  # latitudeDegrees: latitude in degrees. This is phi in the reference document.
  #
  # Value: list with two components
  # $latitudeDistance: distance in meters of a 1 degree change in latitude
  # $longitudeDistance: distance in meters of a 1 degree change in longitude
  
  latitudeRadians <- latitudeDegrees * pi / 180  # convert from degrees to radians
  sinPhi <- sin(latitudeRadians)
  sinPhi2 <- sinPhi * sinPhi
  a <- 6378137.0  # radius of earth at equator (meters)
  e2 <- 0.00669437999014  # eccentricity squared (dimensionless)
  term <- 1 - e2 * sinPhi2  # (1 - e^2 sin^2 phi)
  piTimesA <- pi * a
  latitudeDistance <- piTimesA * (1 - e2) / (180 * (term ^ 1.5))
  longitudeDistance <- piTimesA * cos(latitudeRadians) / (180 * (term ^ 0.5))
  list(latitudeDistance=latitudeDistance,
       longitudeDistance=longitudeDistance)
}

SurfaceLengths <- function(lat1, lat2, long1, long2) {
  # Determine surface lengths between (lat1, long1) and (lat2, long2)
  #
  # Args:
  # lat1, lat2: latitudes in degrees
  # long1, long2: longitudes in degrees
  #
  # Details:
  # The phi value is the average of the latitudes.
  #
  # Value: a list with two components
  # $latitudeDistance: distance in meters on the surface in the latitude direction
  # $longitudeDistance: distance in meters on the surface in the longitude direction
  
  avgLatitude <- (lat1 + lat2) / 2  # avg latitude in degrees
  d <- SurfaceLengths.OneDegree(avgLatitude)
  list(latitudeDistance=abs(d$latitudeDistance * (lat2 - lat1)),
       longitudeDistance=abs(d$longitudeDistance * (long2 - long1)))
}

SurfaceLengths.Test <- function() {
  # unit tests (from the reference source)
  nErrors <- 0
  test <- function(phi, expectedLatitude, expectedLongitude) {
    lengths <- SurfaceLengths.OneDegree(phi)
    tolerance <- 1  # within one meter of expected distance
    if (abs(lengths$latitudeDistance - expectedLatitude) > tolerance) {
      cat("bad latitude", phi, lengths$latitudeDistance, expectedLatitude, "\n")
      nErrors <<- nErrors + 1
    }
    if (abs(lengths$longitudeDistance - expectedLongitude) > tolerance) {
      cat("bad longitude", phi, lengths$longitudeDistance, expectedLongitude, "\n")
      nErrors <<- nErrors + 1
    }
  }
  
  # ref has lengths in kilometers, we have lengths in meters
  # the expected distances (2nd and 3rd args) are from the reference text
  test(0, 110574, 111320 )
  test(15, 110649, 107551)
  test(30, 110852, 96486)
  test(45, 111132, 78847)
  test(60, 111412, 55800)
  test(75, 111618, 28902)
  test(90, 111694, 0)
  if (nErrors > 0)
    stop("found errors")
}

debug(SurfaceLengths.Test)
debug(SurfaceLengths)
debug(SurfaceLengths.OneDegree)

SurfaceLengths.Test()