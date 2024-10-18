#!/bin/bash

# List of all containers
containers=(
    big_fin
    big_med
    big_tech
    container1
    container2
    container3
    container4
    control
    little_fin
    little_med
    little_tech
)

# Stop containers 1 to 4
for i in {1..4}; do
    container_name="container$i"
    if lxc-info -n "$container_name" | grep -q 'RUNNING'; then
        echo "Stopping $container_name..."
        lxc-stop -n "$container_name"
    else
        echo "$container_name is not running."
    fi
done

# Destroy all containers
for container in "${containers[@]}"; do
    if lxc-info -n "$container" &> /dev/null; then
        echo "Destroying $container..."
        lxc-destroy -n "$container"
    else
        echo "$container does not exist."
    fi
done

echo "All specified containers have been stopped and destroyed."

