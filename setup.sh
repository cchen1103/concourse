#!/bin/bash

# setup concourse directory structure
[[ $1 ]] && (mkdir -p $1 && cd $1)

mkdir scripts tasks tools assets

cat >scripts/README.md <<README
This directory holds all concourse scripts for CI/CD

The scripts are called from concourse tasks stated in the tasks yaml files.
README

cat >tasks/README.md <<README
This directory holds all concourse tasks yaml files for CI/CD

The yaml files are used by concourse pipelines. The pipeline yaml files
are located in the concourse project directory and loaded through fly set-pipeline.

The pipeline auto-load scripts are named after:
main-pipeline.yml - setup the main CI/CD pipeline
pipeline-<...>.yml - each individual pipeline for particular purpose
README

cat >tools/README.md <<README
This directory holds all concourse binary files for CI/CD

The tools holding required binary file either pre-installed or transit installed binary or plug-ins
which are used by scripts under scripts directory.
README

cat >assets/README.md <<README
This directory holds all dynatic generated configuration files or tempaltes used for CI/CD
README

cat >main_pipeline_template.yml<<PIPELINE
---
resource_types:
# customized resources
;- name: pivnet
;  type: docker-image
;  source:
;    repository: pivotalcf/pivnet-resource
;    tag: latest-final

resources:
# concourse pipeline standard resources
;- name: ci-dev
;  type: git
;  source:
;    uri: https://github.cms.gov/{{git_user}}/ci-dev.git
;    branch: master
;    username: {{git_user}}
;    password: {{git_token}}
jobs:
# concourse jobs (groups of tasks)
;- name: <job name 1>
;  serial_groups: [<serials running group|optional>]
;  plan:
;  - aggregate:
;    - get: ci-dev #resource name
;      trigger: true|false
;    - get: ci-configs-dev # additional resources
;    - get: ci-utility
;  - task: <task name>
;    file: ci-dev/tasks/<task yml file>
;- name: <job name 2>
;  serial_groups: [<serials running group|optional>]
;  plan:
;  - aggregate:
;    - get: ci-dev #resource name
;      trigger: true|false
;      trigger: true|false
;    - get: ci-configs-dev #resource name
;      passed: [<job name>]
;      trigger: true|false
;  - task: <task name>
;    file: ci-dev/tasks/<task yml file>
;    params:
;      <ENV VARIABLE>: {{<passed in parameters from fly command>}}
;  - put: ci-configs-dev # update resource
;    params: {repository: <update direcorty>}
PIPELINE

cat >tasks/tasks_template.yml<<TASK
---
platform: linux

image_resource:
  type: docker-image
  source: {repository: python, tag: '3.5'}

;inputs:
;- name: ci-dev
;- name: ci-configs-dev

;outputs:
;- name: configs-updated

;run:
;  path: ci-dev/scripts/<script name>
TASK

cat >pipeline-setup-template.sh<<FLY
#!/bin/bash

# export env variables
GIT_USER=<git user>
GIT_TOKEN=<git token>
CONCOURSE_IP=`hostname -I | cut -f1 -d' '`
[[ ${CONCOURSE_IP} ]] || CONCOURSE_IP=127.0.0.1

./fly --target main-build login -c http://${CONCOURSE_IP}:8080

# setup main pipelines
./fly -t main-build set-pipeline -p main-build -c main-pipeline.yml --var git_user=${GIT_USER} --var git_token=${GIT_TOKEN}
# setup additional pipelines
./fly -t main-build set-pipeline -p <pipeline name> -c pipeline-<pipeline>.yml --var git_user=${GIT_USER} --var git_token=${GIT_TOKEN}

# add unpause all pipeline
./fly -t main-build unpause-pipeline --pipeline main-build
#./fly -t <additional target> unpause-pipeline --pipeline <additional pipeline>

# collect all old versions
#./fly -t cloudfoundry-build check-resource --resource <pipeline>/<resources> --from tag:<version number>
FLY

ip=`hostname -I | cut -f1 -d' '`
[[ $ip ]] || ip=127.0.0.1
./boot_concourse.sh ${ip}

echo "Open browse and got http://${ip}:8080 to start concourse"
