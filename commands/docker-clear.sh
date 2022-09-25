#!/bin/bash

# Uncomment the next line if running the script directly!
# chmod +x docker-clear.sh

# =================================================================
# This script removes all containers and docker images.
#
# $ docker-clear
# =================================================================


# Remove All Containers
docker rm $(docker ps -aq) -f

# Remove All Images
docker rmi $(docker images -q)
