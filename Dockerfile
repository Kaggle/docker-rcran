FROM rocker/tidyverse:4.0.5

RUN apt-get update && \
    apt-get install -y imagemagick libmagick++-dev libudunits2-dev curl libgdal-dev \
    libjpeg-dev libxt-dev libprotobuf-dev protobuf-compiler libjq-dev libzmq3-dev

# Install Rust and Cargo. Some R packages requires Rust.
# See: b/113106905
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

ADD packages packages
ADD packages_users packages_users
ADD package_installs.R /tmp/package_installs.R
RUN Rscript /tmp/package_installs.R && \
    bash -c "rm -Rf /tmp/Rtmp*"

# Used in the `rstats` Jenkins `Docker GPU Build` step to restrict the images being pruned.
LABEL kaggle-lang=r