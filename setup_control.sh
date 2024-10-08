#!/bin/bash

# Catching incorrect params for set up command
if [[ $# -ne 1 ]];
then
	echo "Usage: ./setup_control <Container Name>"
	echo "ERROR: incorrect params in $(pwd)/setup_control.sh (5)" >> scripts.log
	exit 5
fi

container_name=$1

sudo lxc-attach -n "$container_name" -- bash -c "mkdir Directory1 Directory2 Directory3 | cd Directory1| mkdir Directory4 | cd ../Directory2 | mkdir Directory5 | cd ../Directory3 | mkdir Directory6 Directory7"

echo "SUCCESS: $(pwd)/setup_control.sh (0)" >> scripts.log
exit 0
