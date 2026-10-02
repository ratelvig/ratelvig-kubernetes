#!/bin/bash
set -e

DIR=$(basename "$(dirname "$(pwd)")")
MSYS_NO_PATHCONV=1 docker run --name molecule-controller--${DIR} -it --rm \
-v "$HOME/.docker:/root/.docker" \
-v "$HOME/.ssh:/tmp/.ssh:ro" \
-v "$(pwd):/root/ansible/${DIR}" \
-v "//var/run/docker.sock:/var/run/docker.sock" \
-w /root/ansible/${DIR} \
labocbz/ansible-molecule:latest \
/bin/sh -c "mkdir -p /root/.ssh &&
cp /tmp/.ssh/id_rsa* /root/.ssh &&
cp /tmp/.ssh/ansible_id* /root/.ssh &&
chmod 0600 -R /root/.ssh &&
/bin/bash"
