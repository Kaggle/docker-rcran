
# Docker Hub imposes a 2 hour time limit. That includes the time it takes
# to pull the base images
timeLimitMinutes <- 100
timeLimitSeconds <- 60 * timeLimitMinutes

packages <- as.data.frame(available.packages())
existingPackages <- installed.packages()

pkgs <- as.character(packages$Package)
M <- 10 # number of parallel installs
M <- min(M, length(pkgs))
library(parallel)
unlink("install_log")
cl <- makeCluster(M, outfile = "install_log")

do_one <- function(pkg){
  install.packages(pkg, verbose=FALSE, quiet=TRUE, repos='http://cran.stat.ucla.edu/')
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

DL <- utils:::.make_dependency_list(pkgs, packages, recursive = TRUE)
DL <- lapply(DL, function(x) x[x %in% pkgs])
DL <- DL[!vecAlreadyInstalled(names(DL))]
lens <- sapply(DL, length)
ready <- names(DL[lens == 0L])
done <- character() # packages already installed
n <- length(ready)

submit <- function(node, pkg) {
    parallel:::sendCall(cl[[node]], do_one, list(pkg), tag = pkg)
}

for (i in 1:min(n, M)) submit(i, ready[i])
DL <- DL[!names(DL) %in% ready[1:min(n, M)]]
av <- if(n < M) (n+1L):M else integer() # available workers
startTime <- Sys.time()
while(length(done) < length(pkgs) && as.numeric(Sys.time() - startTime, units="secs") < timeLimitSeconds) {
    d <- parallel:::recvOneResult(cl)
    av <- c(av, d$node)
    done <- c(done, d$tag)
    print(d$tag)
    OK <- unlist(lapply(DL, function(x) all(x %in% done) ))
    if (!any(OK)) next
    p <- names(DL)[OK]
    m <- min(length(p), length(av)) # >= 1
    for (i in 1:m) {
      submit(av[i], p[i])
    }
    av <- av[-(1:m)]
    DL <- DL[!names(DL) %in% p[1:m]]
}

if(length(done) < length(pkgs)) {
  print("**** Stopping due to time limit ****")
}else{
  print("Done!!!")
}
