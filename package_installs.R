packages <- as.data.frame(available.packages())

successes = 0
errors = 0

for (package in packages$Package) {
    cat("Installing Package ", package, "\n")
    tryCatch(function() {
            install.package(package)
            successes <- successes + 1},
        error=function(e) {
            errors <- errors + 1
            print(e)
            cat("Failed to install package ", package, "\n")
        })
    cat(sucesses, "successes and", errors, "errrors so far\n")
}
