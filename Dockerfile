FROM ruby:3.1.2-slim

RUN apt-get update -y && \
    apt-get install -y apcupsd

WORKDIR /app
COPY main.rb .

CMD ruby main.rb