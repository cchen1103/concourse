#!/bin/bash

instruction() {

	printf "\n"
	printf "\n%4s%-60s" '' 'Concourse Pipeline Templates.'
	printf "\n"
	printf "\n%4s%-60s" '' 'This script is intend to setup a concourse pipeline template under a working directory.'
	printf "\n%4s%-60s" '' 'User just need to focus on configure the pipeline. A setup_pipe.sh script is automatically'
	printf "\n%4s%-60s" '' 'installed at the base directory to help user push all pipelines into concourse.'
	printf "\n"
	printf "\n%4s%-60s" '' '- pipeline: base directory'
	printf "\n%4s%-60s" '' '- tasks: tasks directory'
	printf "\n%4s%-60s" '' '- scripts: scripts directory'
	printf "\n" 
	printf "\n%4s%-60s" '' 'After all the work, please remember to create a repo for your CI/CD project and check in'
	printf "\n%4s%-60s" '' 'your work.'
	printf "\n"

}

set_path() {

	local base_dir

	read -p 'Project name: ' PROJECT
	read -p 'Base working directory: ' base_dir

	local base_path=$(eval echo ${base_dir})
	if [[ ! -d ${base_path} ]]; then
		printf "create %s directory..." "${base_dir}"
		mkdir -p ${base_path}
	fi

	BASE_PATH=$(pwd ${base_path})
}

template_pipeline_setup() {

	local base_path="$1"; shift

	cat > ${base_path}/setup_pipe_linux.sh <<SETUP_PIPE
	#!/bin/bash

	# export env variables
	[[ -e env.yml ]] || (printf "env.yml not found\n" && exit -1)

	export CONCOURSE_IP=\$(hostname -I | cut -d' ' -f1)

	./fly --target ${PROJECT} login -c http://\${CONCOURSE_IP}:8080

	# setup all dev ci pipelines
	for pipe in \$(ls -1 *.pipe); do
	    pipe_name=\$(echo \${pipe} |cut -f1 -d'.')
	    ./fly -t ${PROJECT} set-pipeline -p \${pipe_name} -c \${pipe} --load-vars-from env.yml

	    # start all pipelines
	    ./fly -t ${PROJECT} unpause-pipeline --pipeline \${pipe_name}
	done
SETUP_PIPE

	chmod 0755 ${base_path}/setup_pipe.sh

}

template_path_setup() {

	local base_path="$1"; shift

	[[ -d ${base_path}/tasks ]] || mkdir ${base_path}/tasks
	[[ -d ${base_path}/scripts ]] || mkdir ${base_path}/scripts

}

template_env_setup() {

	local base_path="$1"; shift

	cat > ${base_path}/env.yml <<ENV
	---
	# git resources credentials

	git_user: dummy_user
	git_token: dummy_token

	# additional local environment variables such as cert, pem key, password, etc.
ENV

}

main() {

	# error out on any failure
	set -ueo pipefail

	# show instruction
	instruction

	printf "create project directory ...\n"
	set_path

	printf "create pipeline setup scripts ...\n"
	template_pipeline_setup ${BASE_PATH}

	printf "create pipeline path strcuture ...\n"
	template_path_setup ${BASE_PATH}

	printf "create local environment yml file ...\n"
	template_env_setup ${BASE_PATH}

	printf "template created successfully\n"
}

main

