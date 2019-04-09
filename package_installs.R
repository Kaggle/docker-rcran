# Repo to pull package data and metadata from.
REPO <- 'http://ftp.osuosl.org/pub/cran'

# Number of parallel installs. 
# Experimentally optimized. A too high value (128) crashes.
M <- 64

# Make use of all CPUs available to the custom GCB VM size we use.
options(Ncpus = 32)

library(parallel)
unlink("install_log_parallel")
cl <- makeCluster(M, outfile = "install_log_parallel")

packages <- as.data.frame(available.packages(repos=REPO))
existingPackages <- installed.packages()

pkgs <- as.character(packages$Package)
M <- min(M, length(pkgs))

do_one <- function(repo, pkg){
  h <- function(e) structure(conditionMessage(e), class=c("snow-try-error","try-error"))
  # Treat warnings as errors. (An example 'warning' is that the package is not found!)
  tryCatch(
    install.packages(pkg, verbose=FALSE, quiet=TRUE, repos=repo, dependencies=TRUE),
    error=h,
    warning=h)
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

print("Generating dependency list...")
dl <- utils:::.make_dependency_list(pkgs, packages, recursive = TRUE)
dl <- dl[!vecAlreadyInstalled(names(dl))]
dl <- lapply(dl, function(x) x[x %in% names(dl)])
lens <- sapply(dl, length)
ready <- names(dl[lens == 0L])
n <- length(ready)
total <- length(dl)

print(paste("Ready packages: ", n))
print(paste("Total packages to install: ", total))
print(paste("Already installed: ", nrow(existingPackages)))

submit <- function(node, pkg) {
    parallel:::sendCall(cl[[node]], do_one, list(REPO, pkg), tag = pkg)
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

print("Done!")
print(paste("Successfully installed:", success))
print(paste("Likely failed:", errors))
print(paste("Elapsed:", Sys.time() - start))
