#!/bin/bash

echo
echo '    Concourse Pipeline Templates.'
echo
echo '    This script is intend to setup a concourse pipeline template under a working directory.'
echo '    User just need to focus on configure the pipeline. A setup_pipe.sh script is automatically'
echo '    installed at the base directory to help user push all pipelines into concourse.'
echo
echo '    - pipeline: base directory'
echo '    - tasks: tasks directory'
echo '    - scripts: scripts directory'
echo 
echo '    After all the work, please remember to create a repo for your CI/CD project and check in'
echo '    your work.'
echo

read -p 'Project name: ' project
read -p 'Base working directory: ' base_dir

[ -d $(eval echo ${base_dir}) ] || (echo "create ${base_dir} directory..." && mkdir -p $(eval echo ${base_dir}))

echo
echo "create pipeline setup script ..."

cat > $(eval echo ${base_dir})/setup_pipe.sh <<SETUP_PIPE
#!/bin/bash

# export env variables
[ -e env.yml ] || (echo "env.yml not found" && exit -1)

CONCOURSE_IP=`hostname -I | cut -d' ' -f1`
[[ \${CONCOURSE_IP} ]] || CONCOURSE_IP=127.0.0.1

./fly --target ${project} login -c http://\${CONCOURSE_IP}:8080

# setup all dev ci pipelines

for pipe in \$(ls -1 *.pipe); do
    pipe_name=\$(echo \${pipe} |cut -f1 -d'.')
    ./fly -t ${project} set-pipeline -p \${pipe_name} -c \${pipe} --load-vars-from env.yml

    # start all pipelines
    ./fly -t ${project} unpause-pipeline --pipeline \${pipe_name}
done
SETUP_PIPE

chmod +x $(eval echo ${base_dir})/setup_pipe.sh

echo
echo "create env.yml template ..."

cat > $(eval echo ${base_dir})/env.yml <<ENV
---
# git resources credentials

git_user: dummy_user
git_token: dummy_token

# additional environment variables
ENV

echo
echo "create pipeline directory structure ..."

[ -d $(eval echo ${base_dir})/tasks ] || mkdir $(eval echo ${base_dir})/tasks
[ -d $(eval echo ${base_dir})/scripts ] || mkdir $(eval echo ${base_dir})/scripts

echo
echo "template created successfully"

