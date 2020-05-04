# docker-rcran
A dockerfile to install a list of packages from CRAN.

## Packages

The packages list is found in the `packages` and `packages_user` files.

The first one includes packages that should always be installed, and the second one packages used on Kaggle in the past 60 days (automatically generated).

If you want to make sure a package is always available, add it to `packages` and `test_build.R` file.


## Build

To build this image, use [Google Cloud Build](https://cloud.google.com/cloud-build/):

```
gcloud builds submit --async
```

This build takes ~1 hour. This is why the `--async` option is used.

## Images

The intermediate image (`gcr.io/$PROJECT_ID/rcran-build:temp`) is pushed to GCR before running the test
so that a developer can pull the image in order to debug a test failure.

The final image (`gcr.io/kaggle-images/rcran`) is pushed at the end of the build. Make sure you have access
to that project otherwise your build may fail.
