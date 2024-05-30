FROM heroku/heroku:22-build.v127

ARG TARGETARCH

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

RUN pip install wheel
RUN pip install -r /app/requirements.txt

ARG S5CMD_VERSION=2.2.2
RUN curl -sSLO https://github.com/peak/s5cmd/releases/download/v${S5CMD_VERSION}/s5cmd_${S5CMD_VERSION}_linux_${TARGETARCH}.deb
# copy/paste relevant shasums from s5cmd_checksums.txt in the release, remember to preserve the "\\n\" at the end of each line
RUN printf "\
392c385320cd5ffa435759a95af77c215553d967e4b1c0fffe52e4f14c29cf85  s5cmd_${S5CMD_VERSION}_linux_amd64.deb\\n\
939bee3cf4b5604ddb00e67f8c157b91d7c7a5b553d1fbb6890fad32894b7b46  s5cmd_${S5CMD_VERSION}_linux_arm64.deb\\n\
" | shasum -c - --ignore-missing

RUN dpkg -i s5cmd_${S5CMD_VERSION}_linux_${TARGETARCH}.deb

COPY . /app
