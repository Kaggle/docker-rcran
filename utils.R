# Based on private methods found in utils package
# https://github.com/wch/r-source/blob/05bfe40425384c06ac179f64cd1060f04088064a/src/library/utils/R/packages.R#L1103

clean_up_dependencies <- function(x)
{
    ## x is a character vector of Depends / Suggests / Imports entries
    ## returns a character vector of all the package dependencies mentioned
    x <- x[!is.na(x)]
    if(!length(x)) return(x)
    x <- unlist(strsplit(x, ",", fixed = TRUE), use.names = FALSE)
    unique(sub("^[[:space:]]*([[:alnum:].]+).*$", "\\1" , x))
}

make_dependency_list <- function(pkgs, available)
{
    ## given a character vector of packages,
    ## return a named list of character vectors of their dependencies.
    entries <- c("Depends", "Imports", "LinkingTo")

    if(!length(pkgs)) return(NULL)
    if(is.null(available))
        stop(gettextf("%s must be supplied", sQuote("available")), domain = NA)
        
    dependencies <- vector("list", length(pkgs)); names(dependencies) <- pkgs
    
    known_packages <- row.names(available)
    info <-  available[, entries, drop = FALSE]

    known_packages_with_dep <- vector("list", length(known_packages)); names(xx) <- known_packages
    for (i in seq_along(known_packages))
        known_packages_with_dep[[i]] <- clean_up_dependencies(info[i, ])

    # Dependency Discovery, find the dependencies of the dependencies
    for (pkg in pkgs) {
        p <- known_packages_with_dep[[pkg]]
        p <- p[p %in% known_packages]; p1 <- p
        repeat {
            extra <- unlist(known_packages_with_dep[p1])
            extra <- extra[extra != pkg]
            extra <- extra[extra %in% known_packages]
            deps <- unique(c(p, extra))
            if (length(deps) <= length(p)) break
            p1 <- deps[!deps %in% p]
            p <- deps
        }
        dependencies[[pkg]] <- p
    }

    dependencies
}
