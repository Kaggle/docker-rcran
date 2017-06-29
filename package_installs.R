packages <- as.data.frame(available.packages())
existingPackages <- installed.packages()

pkgs <- as.character(packages$Package)
M <- 4 # number of parallel installs
M <- min(M, length(pkgs))
library(parallel)
unlink("install_log_parallel")
cl <- makeCluster(M, outfile = "install_log_parallel")

do_one <- function(pkg){
  install.packages(pkg, verbose=FALSE, quiet=TRUE, repos='http://cran.stat.ucla.edu/', "--pkglock")
}

alreadyInstalled <- function(pkg){
  if(pkg %in% rownames(existingPackages)){
    if(existingPackages[pkg,"Version"] == as.character(packages$Version[pkg])) {
      return(TRUE)
    }
  }
  return(FALSE)
}
vecAlreadyInstalled <- Vectorize(alreadyInstalled)

print(Sys.time())

DL <- utils:::.make_dependency_list(pkgs, packages, recursive = TRUE)
DL <- lapply(DL, function(x) x[x %in% pkgs])
DL <- DL[!vecAlreadyInstalled(names(DL))]
lens <- sapply(DL, length)
ready <- names(DL[lens == 0L])
done <- character() # packages already installed
n <- length(ready)

print(paste("Ready packages: ", n))
print(paste("Total packages to install: ", length(DL)))
print(paste("Already installed: ", nrow(existingPackages)))

submit <- function(node, pkg) {
    parallel:::sendCall(cl[[node]], do_one, list(pkg), tag = pkg)
}

dependencyLevel <- 1
for (i in 1:min(n, M)) submit(i, ready[i])
DL <- DL[!names(DL) %in% ready[1:min(n, M)]]
av <- if(n < M) (n+1L):M else integer() # available workers
startTime <- Sys.time()
while(length(done) < length(pkgs) && length(DL) > 0) {
    d <- parallel:::recvOneResult(cl)
    av <- c(av, d$node)
    done <- c(done, d$tag)
    print(paste("Installed ", d$tag))
    OK <- unlist(lapply(DL, function(x) all(x %in% done) ))
    if (!any(OK)) {
      lens <- sapply(DL, length)
      ready <- names(DL[lens == dependencyLevel])
      if(length(ready) == 0){
        dependencyLevel <- dependencyLevel + 1
        print(paste("Stepping up dependency level to", dependencyLevel))
        lens <- sapply(DL, length)
        ready <- names(DL[lens == dependencyLevel])
      }
      print(paste("Installing next package with", dependencyLevel, "dependencies"))
      p <- ready[1:length(av)]
    }else{
      print(paste("Packages ready to install: ", sum(OK)))
      p <- names(DL)[OK]
    }
    m <- min(length(p), length(av)) # >= 1
    print(paste("Using", m, "workers"))
    for (i in 1:m) {
      submit(av[i], p[i])
    }
    av <- av[-(1:m)]
    DL <- DL[!names(DL) %in% p[1:m]]
    print(Sys.time())
    print(paste("Packages still remaining: ", length(DL)))
}

print("Done!!!")
