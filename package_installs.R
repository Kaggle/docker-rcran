
# Docker Hub imposes a 2 hour time limit. That includes the time it takes
# to pull the base images, and to push the result.
timeLimitMinutes <- 80
timeLimitSeconds <- 60 * timeLimitMinutes

print(Sys.time())

packages <- as.data.frame(available.packages())
existingPackages <- installed.packages()

alreadyInstalled <- function(pkg){
  if(pkg %in% rownames(existingPackages)){
    if(existingPackages[pkg,"Version"] == as.character(packages$Version[pkg])) {
      return(TRUE)
    }
  }
  return(FALSE)
}
vecAlreadyInstalled <- Vectorize(alreadyInstalled)

packages <- packages[!vecAlreadyInstalled(packages)]

cat("Total packages to install: ", length(packages), "\n")
cat("Already installed: ", nrow(existingPackages), "\n")

my.install.packages <- function(package) {
    install.packages(package, verbose=FALSE, quiet=TRUE, repos="https://cran.cnr.berkeley.edu/")
    return("success")
}

totalPackagesToProcess <- length(packages)
for (package in packages) {
    cat(as.character(Sys.time()), ": Installing Package ", package, "\n")
    status <- tryCatch(my.install.packages(package),
                       error=function(e) {
                       print(e)
                       cat("Failed to install package ", package, "\n")
                       return("error")})
    successes <- successes + (if (status=="success") 1 else 0)
    errors    <- errors    + (if (status=="error")   1 else 0)
    cat(successes, "successes and", errors, "errrors so far\n")
    cat(Sys.time(), "\n")
    if(as.numeric(Sys.time() - startTime, units="secs") > timeLimitSeconds) {
        break
    }
}

if(successes + errors == totalPackagesToProcess) {
 print("Done!!!")
}else{
 print("**** Stopping due to time limit ****")
}

