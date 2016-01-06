FROM rocker/hadleyverse

ADD package_installs.R /tmp/package_installs.R 
RUN Rscript /tmp/package_installs.R

