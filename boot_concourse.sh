#!/bin/bash

set -x

# define concourse web url ip
web_url=127.0.0.1
[[ $1 ]] && web_url=$1

# verify docker is installed
if [ -n "$(command -v yum)" ]; then
    yum -y update
    yum -y install docker-engine
elif [ -n "$(command -v apt-get)" ]; then
    apt-get -y update
    apt-get -y install docker.io
fi

[ -d ~/concourse ] || mkdir ~/concourse
export PATH=$PATH:~/concourse
export CONCOURSE_EXTERNAL_URL=http://${web_url}:8080

curl -L "https://github.com/docker/compose/releases/download/1.10.1/docker-compose-$(uname -s)-$(uname -m)" \
   -o ~/concourse/docker-compose && chmod +x ~/concourse/docker-compose

# setup keys for concourse
cd ~/concourse
mkdir -p keys/web keys/worker
rm -rf keys/web/* keys/worker/*

ssh-keygen -t rsa -f ./keys/web/tsa_host_key -N ''
ssh-keygen -t rsa -f ./keys/web/session_signing_key -N ''
ssh-keygen -t rsa -f ./keys/worker/worker_key -N ''

cp keys/worker/worker_key.pub keys/web/authorized_worker_keys
cp keys/web/tsa_host_key.pub keys/worker

if [ -n "$(command -v systemctl)" ]; then
    systemctl enable docker
    systemctl start docker
elif [ -n "$(command -v service)" ]; then
    service docker start
fi

docker-compose up > /dev/null &
