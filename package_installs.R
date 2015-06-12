packages <- as.data.frame(available.packages())

successes = 0
errors = 0

my.install.packages <- function(package) {
    install.packages(package, verbose=FALSE, quiet=TRUE)
    return("success")
}

for (package in packages$Package) {
    cat(as.character(Sys.time()), ": Installing Package ", package, "\n")
    status <- system.time(tryCatch(my.install.packages(package),
                                   error=function(e) {
                                   print(e)
                                   cat("Failed to install package ", package, "\n")
                                   return("error")}))
    successes <- successes + (if (status=="success") 1 else 0)
    errors    <- errors    + (if (status=="error")   1 else 0)
    cat(successes, "successes and", errors, "errrors so far\n")
}
