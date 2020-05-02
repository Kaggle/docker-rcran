FROM rocker/tidyverse:3.6.3

RUN apt-get update && \
    apt-get install -y imagemagick libmagick++-dev libudunits2-dev curl libgdal-dev \
    libjpeg-dev libxt-dev

# Install Rust and Cargo. Some R packages requires Rust.
# See: b/113106905
RUN curl -sSf https://static.rust-lang.org/rustup.sh | sh

ADD packages packages
ADD packages_users packages_users
ADD package_installs.R /tmp/package_installs.R
RUN Rscript /tmp/package_installs.R && \
    bash -c "rm -Rf /tmp/Rtmp*"

# Used in the `rstats` Jenkins `Docker GPU Build` step to restrict the images being pruned.
LABEL kaggle-lang=r