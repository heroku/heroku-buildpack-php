FROM heroku/heroku:18-build.v16

WORKDIR /app
ENV WORKSPACE_DIR=/app/support/build
ENV PATH=/app/support/build/_util:$PATH
ENV S3_BUCKET=lang-php
ENV S3_PREFIX=dist-heroku-18-develop/
ENV S3_REGION=s3
ENV STACK=heroku-18
ENV DEBIAN_FRONTEND=noninteractive

# pin to package versions from bionic-security for now so that the install doesn't bump libssl to 1.1.1
# RUN apt-get update && apt-get install -y python-pip
RUN apt-get update && apt-get install --no-install-recommends -y python-pip-whl=9.0.1-2 python-pip=9.0.1-2 python-setuptools python-wheel

COPY requirements.txt /app/requirements.txt

RUN pip install -r /app/requirements.txt

COPY . /app
