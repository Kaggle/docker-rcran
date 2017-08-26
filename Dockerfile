FROM rocker/hadleyverse

RUN apt-get update && \
    apt-get install -y imagemagick libudunits2-dev

ADD package_installs.R /tmp/package_installs.R
RUN Rscript /tmp/package_installs.R && \
    bash -c "rm -Rf /tmp/Rtmp*"
