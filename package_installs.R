# Repo to pull package data and metadata from.
REPO <- 'http://cran.us.r-project.org'
options(repos = c("CRAN" = REPO))

# Make use of all CPUs available.
options(Ncpus = parallel::detectCores())

install.packages('pkgdepends')
library(pkgdepends)
library(dplyr)
library(purrr)

p <- trimws(readLines("packages"))
pu <- trimws(readLines('packages_users'))
pkgs <- union(p, pu)

# Remove items listed on packages_users that aren't valid package names
pkgs <- keep(pkgs, is_valid_package_name)

# Check if packages are available
p <- new_pkg_deps(pkgs)
p$resolve()
df <- p$get_resolution()

# List all installable packages
# removes items listed on packages_users that aren't actual packages
pkgs <- filter(df, directpkg, status=="OK") |> pull(package)

# make a install plan
p <- new_pkg_installation_proposal(pkgs)
p$solve()
p$download()
# this will apt-get missing sysreqs if the package defines them
p$install_sysreqs()

failed_pkgs <- c()
errors <- list()
cant_install_pkgs <- c()
start_time <- Sys.time()
repeat {
	tryCatch({
		p$install()
		break
	},error=function(e) {
		if(!inherits(e, c("package_build_error", "install_input_error"))) {
			# if this isnt a package install error, stop
			stop(e)
		}
		# else, error installing e$package
		errors <<- c(errors, list(e))
		failed_pkgs <<- union(failed_pkgs, e$package)
		install_plan <- p$get_install_plan()
		fps <- c(e$package)
		# we need to remove all dependants of e$package from the install list
		while(length(fps)>0) {
			fp <- fps[[1]] # take 1st item
			fps <- fps[-1] # remove from queue
			# find packages that depended on the failed package
			p_deps <- pull(install_plan, dependencies,name=package) |> keep(~has_element(.x, fp)) |> names()
			# remove failed package from install_plan
			install_plan <- filter(install_plan, package != fp)
			if(fp %in% pkgs) {
				# note if this was a package we requested to install
				cant_install_pkgs <<- union(cant_install_pkgs, fp)
			}
			# repeat this loop for the dependencies of failed package
			fps <- union(fps, p_deps)
		}
		# make a new plan without the failed package + deps
		# directpkg are packages we explicitly asked to install
		p <<- new_pkg_installation_proposal(filter(install_plan, directpkg)$package)
		# the new plan will skip packages already installed
		p$solve()
		# the downloads are cached and wont be re-done
		p$download()
	})
}
print(errors)
print("Done!")
print(paste("Successfully installed:",nrow(p$get_install_plan()),'packages'))
print(paste("Failed to install:",paste(failed_pkgs,collapse=', ')))
print(paste("Could not install due to failed dependencies:",paste(setdiff(cant_install_pkgs,failed_pkgs),collapse=', ')))
print(paste("Elapsed:", lubridate::as.duration(Sys.time() - start_time)))

