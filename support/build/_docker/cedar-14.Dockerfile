FROM heroku/cedar:14

WORKDIR /app
ENV WORKSPACE_DIR=/app/support/build
ENV PATH=/app/support/build/_util:$PATH
ENV S3_BUCKET=lang-php
ENV S3_PREFIX=dist-cedar-14-develop/
ENV S3_REGION=s3
ENV STACK=cedar-14
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y python-pip

RUN apt-get install -y libc-client2007e libmcrypt4

COPY requirements.txt /app/requirements.txt

RUN pip install -r /app/requirements.txt

COPY . /app
