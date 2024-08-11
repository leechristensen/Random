
#!/bin/bash

remove_older_docker_images() {
    echo Removing older Mythic docker image versions...
    # Get the list of image repositories starting with "ghcr.io/" and have "mythic" in their name
    repositories=$(docker images --format "{{.Repository}}" | grep "^ghcr.io/" | grep mythic | sort -u)

    for repo in $repositories; do
        # echo "Processing repository: $repo"
        
        # Get all tags for the current repository, sorted by version
        tags=$(docker images --format "{{.Tag}}" "$repo" | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$" | sort -V)
        
        # Count the number of tags
        tag_count=$(echo "$tags" | wc -l)
        
        # If there's more than one tag, remove all but the latest
        if [ "$tag_count" -gt 1 ]; then
            # Get all tags except the last one (latest version)
            tags_to_remove=$(echo "$tags" | sed '$d')
            
            for tag in $tags_to_remove; do
                # echo "Removing $repo:$tag"
                docker rmi "$repo:$tag" 2>&1 > /dev/null
            done
        #else
            # echo "Only one version found for $repo, skipping."
        fi
    done
}

update_env_var() {
    local var_name=$1
    local new_value=$2

    sed -i "s/^$var_name=\"[^\"]*\"/$var_name=\"$new_value\"/" ".env"
}

sudo make

# Generate the docker-compose and .env file
sudo ./mythic-cli 2>&1 >/dev/null

# Update config
update_env_var MYTHIC_ADMIN_USER a
update_env_var MYTHIC_ADMIN_PASSWORD a
update_env_var RABBITMQ_BIND_LOCALHOST_ONLY "false"
update_env_var RABBITMQ_PASSWORD "a"
update_env_var JUPYTER_TOKEN "a"
update_env_var HASURA_SECRET "a"

sudo ./mythic-cli start

sleep 5

echo
echo Starting HTTP C2 profile...
sudo ./mythic-cli install github https://github.com/MythicC2Profiles/http -b Mythic3.3

echo
echo Starting poseidon...
sudo ./mythic-cli install github https://github.com/MythicAgents/poseidon -b Mythic3.3

remove_older_docker_images

SCRIPT_DIR=$(dirname "$(realpath "$0")")
python "${SCRIPT_DIR}/create_payload.py"

echo "Done! You can now access Mythic at https://192.168.230.42:7443/new/callbacks"