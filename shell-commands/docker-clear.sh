#!/bin/bash

# Uncomment the next line if running the script directly!
# chmod +x docker-clear.sh

# =================================================================
# This script removes all containers and docker images.
#
# $ docker-clear
# =================================================================


# Remove All Containers
docker rm -f $(docker ps -aq)

# Remove All Images
docker rmi -f $(docker images -q)

# Prune Volumes
docker system prune --volumes -f
docker volume rm $(docker volume ls -qf dangling=true)
