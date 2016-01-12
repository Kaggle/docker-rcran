
print(Sys.time())
startTime <- Sys.time()

packages <- as.data.frame(available.packages())
existingPackages <- as.data.frame(installed.packages())

alreadyInstalled <- function(pkg){
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
if(nrow(existingPackages) < 900) {
    timeLimitMinutes <- 95
}else if(nrow(existingPackages) < 2300){
    # Allow for push/pulls of larger images
    timeLimitMinutes <- 80
}else if(nrow(existingPackages) < 3650){
  timeLimitMinutes <- 65
}else{
  # Extrapolating the time/package trend to guess how long we have
  timeLimitMinutes <- 65 - 0.011*(existingPackages-3650)
}

timeLimitSeconds <- 60 * timeLimitMinutes


my.install.packages <- function(package) {
    install.packages(package, verbose=FALSE, quiet=TRUE, repos="https://cran.cnr.berkeley.edu/")
    return("success")
}

totalPackagesToProcess <- nrow(packages)
successes <- 0
errors <- 0
for (package in packagesToGet) {
    cat(as.character(Sys.time()), ": Installing Package ", package, "\n")
    status <- tryCatch(my.install.packages(package),
                       error=function(e) {
                       print(e)
                       cat("Failed to install package ", package, "\n")
                       return("error")})
    successes <- successes + (if (status=="success") 1 else 0)
    errors    <- errors    + (if (status=="error")   1 else 0)
    cat(successes, "successes and", errors, "errrors so far\n")
    cat(as.character(Sys.time(), "\n"))
    if(as.numeric(Sys.time() - startTime, units="secs") > timeLimitSeconds) {
        break
    }
}

if(successes + errors == totalPackagesToProcess) {
 cat("Done!!!\n")
}else{
 cat("**** Stopping due to time limit ****\n")
}

