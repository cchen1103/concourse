#!/bin/bash

set -uexo pipefail

# define concourse web url ip

compose_ver=1.11.2
web_url=127.0.0.1
concourse_path='~/concourse'

[ -d ${concourse_path} ] || mkdir ${concourse_path}
export COMPOSE_API_VERSION=1.18
export PATH=$PATH:${concourse_path}
export CONCOURSE_EXTERNAL_URL=http://${web_url}:8080

# install docker engine. Although both CentOS and Debian OS installation are provide,
# concourse in docker requires kernel version > 3.19.

curl -fsSL https://apt.dockerproject.org/gpg | sudo apt-key add -
add-apt-repository "deb https://apt.dockerproject.org/repo/ ubuntu-$(lsb_release -cs) main"
apt-get update && apt-get -y install docker-engine

curl -L "https://github.com/docker/compose/releases/download/${compose_ver}/docker-compose-$(uname -s)-$(uname -m)" \
   -o ${concourse_path}/docker-compose && chmod +x ${concourse_path}/docker-compose

# setup keys for concourse

cd ${concourse_path}
mkdir -p keys/web keys/worker
rm -rf keys/web/* keys/worker/*

ssh-keygen -t rsa -f ./keys/web/tsa_host_key -N ''
ssh-keygen -t rsa -f ./keys/web/session_signing_key -N ''
ssh-keygen -t rsa -f ./keys/worker/worker_key -N ''

cp keys/worker/worker_key.pub keys/web/authorized_worker_keys
cp keys/web/tsa_host_key.pub keys/worker

# start docker service

service docker start

# launch concourse in docker

docker-compose up > /dev/null &
