FROM ubuntu:14.04

MAINTAINER Kisel Jan "jdkrot@gmail.com"

COPY timeout /usr/local/bin/
COPY dups_check.sh /tmp/
RUN apt-get update && apt-get upgrade --yes
RUN apt-get install --yes python2.7

RUN apt-get install --yes python-pip python-dev build-essential protobuf-compiler python-html2text python-numpy
RUN easy_install pip && pip install --upgrade pip && pip install --upgrade mmh3 protobuf
