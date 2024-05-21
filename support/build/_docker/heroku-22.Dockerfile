FROM heroku/heroku:22-build.v84

WORKDIR /app
ENV WORKSPACE_DIR=/app/support/build
ENV S3_BUCKET=lang-php
ENV S3_PREFIX=dist-heroku-22-develop/
ENV S3_REGION=us-east-1
ENV STACK=heroku-22
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y python3-pip python3-venv

ENV VIRTUAL_ENV=/app/.venv
RUN python3 -m venv "$VIRTUAL_ENV"

ENV PATH="/app/support/build/_util:$VIRTUAL_ENV/bin:$PATH"

COPY requirements.txt /app/requirements.txt

RUN pip install -r /app/requirements.txt

COPY . /app
