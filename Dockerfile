FROM rocker/tidyverse:4.0.5

RUN apt-get update && \
    apt-get install -y imagemagick libmagick++-dev libudunits2-dev curl libgdal-dev \
    libjpeg-dev libxt-dev libprotobuf-dev protobuf-compiler libjq-dev libzmq3-dev \
    libv8-dev libnode-dev libgeos-dev libproj-dev

# Install Rust and Cargo. Some R packages requires Rust.
# See: b/113106905
# Script is pulled from https://sh.rustup.rs and mirrored locally for security reasons.
# See: b/238367731
ADD rustup.sh rustup.sh
RUN cat rustup.sh | sh -s -- -y

ADD packages packages
ADD packages_users packages_users
ADD package_installs.R /tmp/package_installs.R
RUN Rscript /tmp/package_installs.R && \
    bash -c "rm -Rf /tmp/Rtmp*"

# Used in the `rstats` Jenkins `Docker GPU Build` step to restrict the images being pruned.
LABEL kaggle-lang=r