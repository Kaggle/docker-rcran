# Repo to pull package data and metadata from.
REPO <- 'http://cran.us.r-project.org'
options(repos = c("CRAN" = REPO))

options(install.packages.compile.from.source = "never")

# Number of parallel installs. 
# Experimentally optimized. A too high value (128) crashes.
M <- 16

# Make use of all CPUs available.
options(Ncpus = parallel::detectCores())

# Install parallel library.
library(parallel)
unlink("install_log_parallel")

# Install util packages.
utilPackages <- c('Rcpp', 'repr', 'rmutil', 'testthat', 'hrbrthemes')
for (p in utilPackages) {
  install.packages(p, verbose=FALSE, quiet=FALSE, repos=REPO)
}

# All packages available in the repo.
allPackages <- as.data.frame(available.packages(repos=REPO))

# Already installed packages.
existingPackages <- installed.packages()

# Get list of packages to install from files.
library("rmutil")
p <- read.table(file="packages")
pu <- read.table(file="packages_users")
pmerged <- rbind(p, pu)
pkgs <- pmerged[,1]

M <- min(M, length(pkgs))

do_one <- function(pkg, repos){
  h <- function(e) structure(conditionMessage(e), class=c("snow-try-error","try-error"))
  # Treat warnings as errors. (An example 'warning' is that the package is not found!)
  tryCatch(
    install.packages(pkg, verbose=FALSE, quiet=FALSE, repos=repos),
    error=h,
    warning=h)
}

alreadyInstalled <- function(pkg){
  if(pkg %in% rownames(existingPackages)){
    if(!is.na(allPackages$Version[pkg]) && existingPackages[pkg,"Version"] == as.character(allPackages$Version[pkg])) {
      return(TRUE)
    }
  }
  return(FALSE)
}
vecAlreadyInstalled <- Vectorize(alreadyInstalled)

print("Generating dependency list...")
dl <- utils:::.make_dependency_list(pkgs, allPackages, recursive = TRUE)
dl <- dl[!vecAlreadyInstalled(names(dl))]
dl <- lapply(dl, function(x) x[x %in% names(dl)])
lens <- sapply(dl, length)
ready <- names(dl[lens == 0L])
n <- length(ready)
total <- length(dl)

print(paste("Ready packages: ", n))
print(paste("Total packages to install: ", total))

cl <- makeCluster(M, outfile = "install_log_parallel")

submit <- function(node, pkg) {
  parallel:::sendCall(cl[[node]], do_one, list(pkg, repos=REPO), tag = pkg)
}

for (i in 1:min(n, M)) {
  submit(i, ready[i])
}
dl <- dl[!names(dl) %in% ready[1:min(n, M)]]
av <- if(n < M) (n+1L):M else integer() # available workers

success <- character(0)
errors <- character(0)
start <- Sys.time()
while(length(dl) > 0 || length(av) != M) {
  if (length(av) == M) {
    stop("deadlock")
  }

  d <- parallel:::recvOneResult(cl)

  # Handle errors reported by the worker.
  if (inherits(d$value, 'try-error')) {
    msg <- paste("ERROR: worker", d$node, "for package ", d$tag, ":", d$value)
    print(msg)
    warning(msg)
    errors <- c(errors, d$tag)
  } else {
    success <- c(success, d$tag)
  }

  # Find work to be done.
  av <- c(av, d$node)
  dl <- lapply(dl, function(x) x[x != d$tag])
  lens <- sapply(dl, length)
  ready <- names(dl[lens == 0L])
  m <- min(length(ready), length(av))  # >= 1

  # Report for this iteration.
  eta <- start + (Sys.time() - start) / (length(success) + length(errors)) * total
  print(paste(
    "done:", d$tag, "on", d$node,
    ", success:", length(success),
    ", failed:", length(errors),
    ", remaining:", length(dl),
    ", ready:", length(ready),
    ", next:", if (m) paste(ready[1:m], "on", av[1:m]) else "<none>",
    ", eta:", eta))

  # Possibly schedule next work. Typically submits exactly 1 task, though occasionally:
  #   - 0 (when blocked on ongoing installs to complete dependencies first)
  #   - or >1 (possibly after being unblocked from the previously described condition)
  if (m) {
    for (i in 1:m) {
      submit(av[i], ready[i])
    }
    av <- av[-(1:m)]
    dl <- dl[!names(dl) %in% ready[1:m]]
  }
}

# Make sure the packages from the file `packages` are properly installed 
# otherwise reinstalling in a single thread, as they sometimes fail in the
# previous technique.
for (p in p[,1]) {
  if (!require(p, character.only = TRUE)) {
    install.packages(p, verbose=FALSE, quiet=FALSE, repos=REPO)
  }
}


# Install older version of packages.
library(devtools)
install_version("randomForest", version='4.6.14') # [b/219681100]
install_version("terra", version='1.5-34') # [b/240934971]
install_version("ranger", version='0.14.1') # [b/291120269]
install_version("leaflet", version='2.1.2') # [b/299859148]


print("Done!")
print(paste("Successfully installed:", success))
print(paste("Likely failed:", errors))
print(paste("Elapsed:", Sys.time() - start))
