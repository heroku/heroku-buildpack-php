FROM heroku/heroku:24-build.v160

ARG TARGETARCH

USER root

WORKDIR /app
ENV WORKSPACE_DIR=/app/support/build
ENV S3_BUCKET=lang-php
ENV S3_PREFIX=dist-heroku-24-${TARGETARCH}-develop/
ENV S3_REGION=us-east-1
ENV STACK=heroku-24
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y python3-pip python3-venv

ENV VIRTUAL_ENV=/app/.venv
RUN python3 -m venv "$VIRTUAL_ENV"

ENV PATH="/app/support/build/_util:$VIRTUAL_ENV/bin:$PATH"

COPY requirements.txt /app/requirements.txt

RUN pip install wheel
RUN pip install -r /app/requirements.txt

ARG S5CMD_VERSION=2.3.0
RUN curl -sSLO https://github.com/peak/s5cmd/releases/download/v${S5CMD_VERSION}/s5cmd_${S5CMD_VERSION}_linux_${TARGETARCH}.deb
# copy/paste relevant shasums from s5cmd_checksums.txt in the release, remember to preserve the "\\n\" at the end of each line
RUN printf "\
81d02a17a13797dc5949adb99734ad4217d005638a7827f36d435945527b2e69  s5cmd_${S5CMD_VERSION}_linux_amd64.deb\\n\
344a0476206d9558fe8704a9fa939589c61a6ddf16368d8a8c0c8ee61759c63f  s5cmd_${S5CMD_VERSION}_linux_arm64.deb\\n\
" | shasum -c - --ignore-missing

RUN dpkg -i s5cmd_${S5CMD_VERSION}_linux_${TARGETARCH}.deb

COPY . /app
