FROM rocker/tidyverse:4.0.5

RUN apt-get update && \
    apt-get install -y build-essential clang imagemagick libmagick++-dev libudunits2-dev curl libgdal-dev \
    libjpeg-dev libxt-dev libprotobuf-dev protobuf-compiler libjq-dev libzmq3-dev \
    libv8-dev libnode-dev

# Install Rust and Cargo. Some R packages requires Rust.
# See: b/113106905
# Script is pulled from https://sh.rustup.rs and mirrored locally for security reasons.
# See: b/238367731
ADD rustup.sh rustup.sh
RUN cat rustup.sh | sh -s -- -y

ADD clean-layer.sh  /tmp/clean-layer.sh

RUN apt-get update && \
    apt-get install apt-transport-https && \
    apt-get install -y -f r-cran-rgtk2 && \
    apt-get install -y -f libv8-dev libgeos-dev libgdal-dev libproj-dev libsndfile1-dev \
    libtiff5-dev fftw3 fftw3-dev libfftw3-dev libjpeg-dev libhdf4-0-alt libhdf4-alt-dev \
    libhdf5-dev libx11-dev cmake libglu1-mesa-dev libgtk2.0-dev librsvg2-dev libxt-dev \
    patch libgit2-dev && \
    /tmp/clean-layer.sh

# TODO(b/324184434): necessary for mxnet, let's try to remove in the future.
RUN R -e "install.packages('DiagrammeR')"

RUN apt-get update && apt-get install -y build-essential git ninja-build ccache  libatlas-base-dev libopenblas-dev libopencv-dev python3-opencv && \
    cd /usr/local/share && git clone --recursive --depth=1 --branch v1.8.x https://github.com/apache/incubator-mxnet.git mxnet && \
    cd mxnet && cp config/linux.cmake config.cmake && rm -rf build && \
    mkdir -p build && cd build && cmake .. && cmake --build . --parallel $(nproc) && \
    cd .. && make -f R-package/Makefile rpkg && \
    /tmp/clean-layer.sh

    # Needed for "h5" library
RUN apt-get install -y libhdf5-dev && \
    # Needed for "topicmodels" library
    apt-get install -y libgsl-dev && \
    # Needed for "tesseract" library
    apt-get install -y libpoppler-cpp-dev libtesseract-dev tesseract-ocr-eng && \
    /tmp/clean-layer.sh

ADD packages packages
ADD packages_users packages_users
ADD package_installs.R /tmp/package_installs.R
RUN Rscript /tmp/package_installs.R && \
    bash -c "rm -Rf /tmp/Rtmp*"

# Used in the `rstats` Jenkins `Docker GPU Build` step to restrict the images being pruned.
LABEL kaggle-lang=r