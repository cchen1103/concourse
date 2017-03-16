#!/bin/bash

# if TRACE is set, print out each command that executes
[[ $TRACE ]] && set -x

# usage intructions
usage() {

	cat <<- EOF

	usage: $PROGNAME options

	    This script install CI/CD concourse tool in docker containers.

	OPTIONS:
	    -p --path 			specify installation path, default at ~/concourse
	    -x --debug			debug
	    -h --help			show this help

	EXAMPLES:
	    Install to default directory, i.e. ~/concourse
	    $PROGNAME -- install to ~/concourse directory

	    Install specified path, i.e. /usr/local/bin
	    $PROGNAME --path /usr/local/bin

	    Show each shell command that executes
	    $PROGNAME --debug

	    Show help message
	    $PROGNAME --help
	EOF

}

# parse arguments
opt_parser() {

	local arg=
	for arg; do
		local delim=""
		case "${arg}" in
			--path)	args="${args}-p ";;
			--debug) args="${args}-x ";;
			--help) args="${args}-h ";;
			*) [[ "${arg:0:1}" == "-" ]] || delim="\""
				args="${args}${delim}${arg}${delim} ";;
		esac
	done

    #Reset the positional parameters to the short options
    eval set -- $args

    while getopts "hxp:" OPTION
    do
         case $OPTION in
         h)
             usage
             exit 0
             ;;
         x)
             readonly DEBUG='-x'
             set -x
             ;;
         p)
             readonly INSTALLATION_PATH=$OPTARG
             ;;
        esac
    done

}

# this script requires to be run in previlige mode
check_privilege() {

	if [[ "$EUID" -ne 0 ]]; then
	  printf "\nPlease run in previliged mode\n" 1>&2
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
	[[ $(ls -A ./keys/worker) ]] && rm -rf ./keys/worker/*

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

	set -eo pipefail

	opt_parser $ARGS

	printf "\n%s\n" "install concourse in docker container ..."

	local compose_version=1.11.2
	local installation_path=${INSTALLATION_PATH:-~/concourse}

	printf "\n%s\n" "check running mode ..."

	check_privilege

	printf "\n%s\n" "install docker engine ..."

	install_docker

	printf "\n%s\n" "install compose ..."

	install_compose ${compose_version} ${installation_path}

	printf "\n%s\n" "generate self-signed key for concourse ..."

	generate_keys ${installation_path}

	printf "\n%s\n" "start docker engine ..."

	[[ $(service docker status | grep running) ]] || service docker start

	printf "\n%s\n" "start concourse ..."

	nohup docker-compose up > /dev/null &

	printf "\n%s\n" "installation completed successfully ..."
	printf "%4s%-16s%s\n" '' "installed at:" "${installation_path}"
	printf "%4s%-16s%s\n" '' "concourse url:" "http://$(hostname -I | cut -f1 -d' '):8080"

	# set the back compatability to the compose api
	# export all environment variables and path needed to run concourse

	export COMPOSE_API_VERSION=1.18
	export PATH=$PATH:${installation_path}
	export CONCOURSE_EXTERNAL_URL=http://127.0.0.1:8080

}

# set immutable input argument

readonly ARGS="$@"
readonly PROGNAME=$(basename $0)

main


