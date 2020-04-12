# docker-rcran
A dockerfile to install a list of packages from CRAN. 
This list is found in the `packages` file and includes packages used on Kaggle in the past 60 days.
If you want to make sure a package is always available, add it to the `test_build.R` file.

To build this image, use [Google Cloud Build](https://cloud.google.com/cloud-build/):

```
gcloud builds submit --async
```

This build takes O(hours). This is why the `--async` option is used.

The intermediate image (`gcr.io/$PROJECT_ID/rcran-build:temp`) is pushed to GCR before running the test
so that a developer can pull the image in order to debug a test failure.

The final image (`gcr.io/kaggle-images/rcran`) is pushed at the end of the build. Make sure you have access
to that project otherwise your build may fail.