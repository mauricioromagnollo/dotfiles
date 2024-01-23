#!/bin/bash

chmod +x clear-ubuntu.sh

# =========================================================
function main() {
  clear-docker
  clear-snap
  clear-temporary-files
  clear-apt
  clear-log-files
  clear-cache-files
  clear-yarn
  clear-npm
}
# =========================================================

function clear-docker() {
  # Remove All Containers
  docker rm -f $(docker ps -aq)

  # Remove All Images
  docker rmi -f $(docker images -aq)

  # Remove All Networks
  docker network rm $(docker network ls -q)

  # Remove All Volumes
  docker system prune --volumes -af
  docker volume rm $(docker volume ls -qf dangling=true)
}

function clear-snap() {
  # Clean Snap Packages
  sudo snap list --all | grep disabled | awk '{print $1, $3}' | while read snapname revision; do sudo snap remove "$snapname" --revision="$revision"; done
}

function clear-temporary-files() {
  # Remove Temporary Files
  sudo rm -rf /tmp/*
  sudo rm -rf /var/tmp/*
}

function clear-apt() {
  # Remove Packages
  sudo apt-get clean
  sudo apt-get autoclean
  sudo apt-get autoremove -y
}

function clear-log-files() {
  sudo find /var/log -type f -mtime +7 -exec rm {} \;
  # sudo find /var/log -type f -size +100M -exec truncate -s 0 {} \;
}

function clear-cache-files() {
  rm -rf ~/.cache/*
  sudo rm -rf /var/cache/*
}

function clear-yarn() {
  # Remove Yarn Cache
  yarn cache clean
}

function clear-npm() {
  # Remove NPM Cache
  npm cache clean --force
}

main