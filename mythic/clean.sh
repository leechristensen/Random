#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/common.sh"

common_check_mythic_dir


# Check if there are any containers and delete them
container_ids=$(docker ps -aq)
if [ -n "$container_ids" ]; then
    # echo "Containers found. Removing the following containers:"
    # echo "$container_ids"
    # Remove the containers

    sudo docker rm -fv $container_ids > /dev/null
#else
    # echo "No containers found."
fi

# Check if there are any volumes and delete them
volume_names=$(docker volume ls -q)
if [ -n "$volume_names" ]; then
    # echo "Volumes found. Removing the following volumes:"
    # echo "$volume_names"
    # Remove the volumes
    sudo docker volume rm $volume_names > /dev/null
#else
    # echo "No volumes found."
fi

docker buildx prune -a -f

sudo bash -c 'chown -R "${SUDO_USER}:${SUDO_USER}" .'
sudo git reset --hard HEAD > /dev/null
sudo git clean -f -d -x > /dev/null
sudo bash -c 'chown -R "${SUDO_USER}:${SUDO_USER}" .'
git reset --hard HEAD > /dev/null
git clean -f -d -x > /dev/null