FROM heroku/heroku:16-build

WORKDIR /app
ENV WORKSPACE_DIR=/app/support/build
ENV PATH=/app/support/build/_util:$PATH
ENV S3_BUCKET=lang-php
ENV S3_PREFIX=dist-heroku-16-develop/
ENV S3_REGION=s3
ENV STACK=heroku-16

RUN apt-get update && apt-get install -y python-pip

COPY requirements.txt /app/requirements.txt

RUN pip install -r /app/requirements.txt

COPY . /app
