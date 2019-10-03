FROM rocker/tidyverse:3.6.0

RUN apt-get update && \
    apt-get install -y imagemagick libudunits2-dev curl libgdal-dev \
    libjpeg-dev libxt-dev

# Install Rust and Cargo. Some R packages requires Rust.
# See: b/113106905
RUN curl -sSf https://static.rust-lang.org/rustup.sh | sh

ADD package_installs.R /tmp/package_installs.R
RUN Rscript /tmp/package_installs.R && \
    bash -c "rm -Rf /tmp/Rtmp*"

# Miniconda (used by time-series API)
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH /opt/conda/bin:$PATH
RUN apt-get update --fix-missing && \
    apt-get install -y wget bzip2 ca-certificates curl git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-4.5.11-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    /opt/conda/bin/conda clean -tipsy && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc

# Install packages (used by time-series API)
RUN pip install pandas pycrypto

ENV TINI_VERSION v0.16.1
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini

ENTRYPOINT [ "/usr/bin/tini", "--" ]
