FROM heroku/cedar:14

WORKDIR /app
ENV WORKSPACE_DIR=/app/support/build

RUN apt-get update
RUN apt-get install -y python-pip

RUN pip install 'bob-builder>=0.0.10' 's3cmd>=1.6.0'

ADD . /app
