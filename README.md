# docker-rcran
A dockerfile to install all of CRAN

To build this image, use [Google Cloud Build](https://cloud.google.com/cloud-build/):

```
gcloud builds submit --async
```

This build takes O(hours), it's why the `--async` option is used.

The intermediate image (`gcr.io/$PROJECT_ID/rcran-build:temp`) is pushed to GCR before running the test
so that a developer can pull the image in order to debug a test failure.

The final image (`gcr.io/kaggle-images/rcran`) is pushed at the end of the build, make sure you have access
to that project otherwise your build may fail.