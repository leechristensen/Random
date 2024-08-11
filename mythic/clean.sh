#!/bin/bash

# Check if there are any containers and delete them
container_ids=$(docker ps -aq)
if [ -n "$container_ids" ]; then
    echo "Containers found. Removing the following containers:"
    echo "$container_ids"
    # Remove the containers
    sudo docker rm -fv $container_ids
else
    echo "No containers found."
fi

# Check if there are any volumes and delete them
volume_names=$(docker volume ls -q)
if [ -n "$volume_names" ]; then
    echo "Volumes found. Removing the following volumes:"
    echo "$volume_names"
    # Remove the volumes
    sudo docker volume rm $volume_names
else
    echo "No volumes found."
fi

sudo git clean -f -d -x
sudo git reset --hard HEAD
