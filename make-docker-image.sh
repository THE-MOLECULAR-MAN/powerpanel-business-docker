#!/bin/bash

# bail on any errors
set -e

# clean up old versions:
echo "Removing exited containers..."
sudo docker ps -a | grep Exit | cut -d ' ' -f 1 | xargs sudo docker rm

echo "Pruning containers ..."
sudo docker container prune --force

echo "Pruning images..."
sudo docker image     prune --force --all

echo "Pruning volumes..."
sudo docker volume prune --force

# hadolint --failure-threshold error Dockerfile

echo "Building image..."
# the -t is the tag name
#sudo docker build --no-cache -t tim-powerpanelbusiness-mgmt .
sudo docker build -t tim-powerpanelbusiness-mgmt .

echo "Running image as new container..."
sudo docker run -p 127.0.0.1:8000:3052/tcp --name tim-test -it tim-powerpanelbusiness-mgmt # /bin/bash

echo "make-docker-image.sh finished successfully"
