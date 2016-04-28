
print(Sys.time())
startTime <- Sys.time()

r <- getOption("repos")
r["CRAN"] <- "https://cran.cnr.berkeley.edu/"
options(repos = r)

availablePackages <- available.packages()
packages <- as.data.frame(availablePackages)
existingPackages <- as.data.frame(installed.packages())

FAILURE_LOG_FILENAME <- "install_failures.txt"
if(file.exists(FAILURE_LOG_FILENAME)){
  failures <- scan(file=FAILURE_LOG_FILENAME, what=character(), quiet=TRUE)
  cat("Ignoring ", length(failures), " previous failed installations.\n")
}else{
  failures <- c()
}

alreadyInstalled <- function(pkg){
  if(pkg %in% failures){
    return(TRUE)
  }
  if(pkg %in% rownames(existingPackages) && pkg %in% rownames(packages)){
    if(as.character(existingPackages[pkg,"Version"]) == as.character(packages$Version[pkg])) {
      return(TRUE)
    }
  }
  return(FALSE)
}
vecAlreadyInstalled <- Vectorize(alreadyInstalled)

packagesToGet <- rownames(packages)[!vecAlreadyInstalled(rownames(packages))]

cat("Total packages to install: ", nrow(packages), "\n")
cat("Already installed: ", nrow(existingPackages), "\n")


# Docker Hub imposes a 2 hour time limit. That includes the time it takes
# to pull the base images, and to push the result.
if(nrow(existingPackages) < 500) {
    timeLimitMinutes <- 95
} else if(nrow(existingPackages) < 800) {
    timeLimitMinutes <- 89
} else if(nrow(existingPackages) < 1000) {
    # Weird speedhump building rcran2
    timeLimitMinutes <- 60
} else {
  # Based on estimates from previous builds
  pushPullTime <- 10 + 0.005*nrow(existingPackages)
  fudgeFactor <- 2
  timeLimitMinutes <- 120 - (pushPullTime + fudgeFactor)
}

timeLimitSeconds <- 60 * timeLimitMinutes


my.install.packages <- function(package) {
    install.packages(package, verbose=FALSE, quiet=TRUE, available=availablePackages)
    return("success")
}

totalPackagesToProcess <- nrow(packages)
successes <- 0
errors <- 0
for (package in packagesToGet) {
    cat(as.character(Sys.time()), ": Installing Package ", package, "\n")
    # We treat warning() calls as errors because install.packages only ever
    # throws a warning
    status <- tryCatch(my.install.packages(package),
                       warning=function(e) {
                       print(e)
                       cat("Failed to install package ", package, "\n")
                       failures <<- c(failures, package)
                       return("error")})
    successes <- successes + (if (status=="success") 1 else 0)
    errors    <- errors    + (if (status=="error")   1 else 0)
    cat(successes, "successes and", errors, "errors so far\n")
    cat(as.character(Sys.time(), "\n"))
    if(as.numeric(Sys.time() - startTime, units="secs") > timeLimitSeconds) {
        break
    }
}

write(failures, file=FAILURE_LOG_FILENAME)

if(successes + errors == totalPackagesToProcess) {
 cat("Done!!!\n")
}else{
 cat("**** Stopping due to time limit ****\n")
}

