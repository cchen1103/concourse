#!/bin/bash

# stop the script whenever we have a failure
set -ueo pipefail

# if TRACE is set, print out each command that executes
[[ $TRACE ]] && set -x

# this script requires to be run in previlige mode
check_privilege() {
	if [[ "$EUID" -ne 0 ]]; then
	  printf "Please run in previliged mode" 1>&2
	  exit -1
	fi
}

# install docker engine. Although both CentOS and Debian OS installation are provide,
# concourse in docker requires kernel version > 3.19.

install_docker() {
	
	local ubuntu_rel=$(lsb_release -cs)

	curl -fsSL https://apt.dockerproject.org/gpg | sudo apt-key add -
	add-apt-repository "deb https://apt.dockerproject.org/repo/ ubuntu-${ubuntu_rel} main"
	apt-get update
	apt-get -y install docker-engine
}

# install docker compose which is used to create concourse containers

install_compose() {

	local compose_ver="$1"; shift
	local installation_path="$1"; shift
	local os=$(uname -s)
	local platform=$(uname -m)

	[[ -d ${installation_path} ]] || mkdir ${installation_path}

	curl -L "https://github.com/docker/compose/releases/download/${compose_ver}/docker-compose-${os}-${platform}" \
   		-o ${installation_path}/docker-compose
	chmod +x ${installation_path}/docker-compose

}

# generate self signed key pairs for concourse worker, concourse db and concourse web

generate_keys() {

	local installation_path="$1"; shift

	cd ${installation_path}

	[[ -d ./keys/web ]] || mkdir -p ./keys/web
	[[ -d ./keys/worker ]] || mkdir -p ./keys/worker

	# remove all old key pairs
	[[ $(ls -A ./keys/web) ]] && rm -rf ./keys/web/*
	[[ $(ls -A ./keys/worker) ]] && rm -rf ./web/worker/*

	# generate new keys
	ssh-keygen -t rsa -f ./keys/web/tsa_host_key -N ''
	ssh-keygen -t rsa -f ./keys/web/session_signing_key -N ''
	ssh-keygen -t rsa -f ./keys/worker/worker_key -N ''

	# copy public keys to appropreted path
	cp ./keys/worker/worker_key.pub ./keys/web/authorized_worker_keys
	cp ./keys/web/tsa_host_key.pub ./keys/worker

}

# main script starts here

main() {

	printf "\n%s\n" "install concourse in docker container ..."

	# define concourse web url ip
	local compose_version=1.11.2
	local installation_path=${1:-~/concourse}

	printf "\n%s\n" "check running mode ..."

	check_privilege

	printf "\n%s\n" "install docker engine ..."

	install_docker

	printf "\n%s\n" "install compose ..."

	install_compose ${compose_version} ${installation_path}

	printf "\n%s\n" "generate self-signed key for concourse ..."

	generate_keys ${installation_path}

	printf "\n%s\n" "start docker engine ..."

	service docker start

	printf "\n%s\n" "start concourse ..."

	nohup docker-compose up > /dev/null &

	printf "\n%s\n" "installation completed successfully ..."
	printf "%4s%-16s%s\n" '' "installed at:" "${installation_path}"
	printf "%4s%-16s%s\n" '' "concourse url:" "http://$(hostname -I | cut -f1 -d' '):8080"

}

main 

# set the back compatability to the compose api
# export all environment variables and path needed to run concourse

export COMPOSE_API_VERSION=1.18
export PATH=$PATH:${installation_path}
export CONCOURSE_EXTERNAL_URL=http://127.0.0.1:8080

