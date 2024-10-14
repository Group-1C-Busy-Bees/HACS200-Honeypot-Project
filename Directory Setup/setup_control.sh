#!/bin/bash

# Catching incorrect params for set up command
if [[ $# -ne 1 ]];
then
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: incorrect params in $(pwd)/setup_control.sh (5)" >> scripts.log
	exit 5
fi

container_name=$1

sudo lxc-attach -n "$container_name" -- bash -c "mkdir Directory1 Directory2 Directory3 | cd Directory1| mkdir Directory4 | cd ../Directory2 | mkdir Directory5 | cd ../Directory3 | mkdir Directory6 Directory7"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $(pwd)/setup_control.sh completed (0)" >> scripts.log
exit 0
