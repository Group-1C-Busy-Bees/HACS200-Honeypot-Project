#!/bin/bash

# Checking proper command usage
if [[ $# -ne 3 ]]
then
    echo "usage: ./recycle <number of minutes to run container> <external IP address> <container name>" 
    echo "ERROR: incorrect params in $(pwd)/recycle.sh (1)" >> scripts.log
    exit 1
fi

# Storing container name to a variable
CONTAINER_NAME=$3 
# Storing external IP to a variable
EXTERNAL_IP=$2
# Gets container IP address
CONTAINER_IP=$(sudo lxc-info -n $CONTAINER_NAME | grep "IP" | cut -d ' ' -f 14-)

# Checking if utility file does NOT exist
if [[ ! -e ./recycle_util_$CONTAINER_NAME ]]
then
    # Select random config from honeypot_configs
    HP_CONFIG=$(shuf -n 1 ./honeypot_configs)
    # runs selected config script
    ./setup_"$HP_CONFIG"

    # Output redirect so that the first line of the utility file contains:
    # number of minutes to run container, container name, and start time of container
    echo "$1 $CONTAINER_NAME $(date +%s)" > ./recycle_util_$CONTAINER_NAME
    echo "STATUS: Container $CONTAINER_NAME started at $(date +%Y-%m-%dT%H:%M:%S%Z)" >> scripts.log

    # set up NAT rules
    sudo ip addr add $EXTERNAL_IP/16 brd + dev eth0
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination $EXTERNAL_IP --jump DNAT --to-destination $CONTAINER_IP
    sudo iptables --table nat --insert POSTROUTING --source $CONTAINER_IP --destination 0.0.0.0/0 --jump SNAT --to-source $EXTERNAL_IP
else # container is already up, does not need to be created
    # Calculating a container’s uptime
    CURRENT_TIME=$(date +%s)
    START_TIME=$(cat ./recycle_util_$CONTAINER_NAME | cut -d ' ' -f3)
    TIME_ELAPSED=$((CURRENT_TIME - START_TIME))
    TARGET_DURATION=$(cat ./recycle_util_$CONTAINER_NAME | cut -d ' ' -f1)

    # Checking to see if it is time to recycle
    if [[ $TIME_ELAPSED -ge $(($TARGET_DURATION * 60)) ]]
        then
        # remove NAT rules & delete container
        sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination $EXTERNAL_IP --jump DNAT --to-destination $CONTAINER_IP
        sudo iptables --table nat --delete POSTROUTING --source $CONTAINER_IP --destination 0.0.0.0/0 --jump SNAT --to-source $EXTERNAL_IP
        sudo ip addr delete $EXTERNAL_IP/16 brd + dev eth0

        # ALSO MAKE SURE TO SAVE MITM/SNOOPY LOGS BEFORE DELETING, MIGHT GO HERE

        # Stop and delete container
        sudo lxc-stop -n "$CONTAINER_NAME"
        sudo lxc-destroy -n "$CONTAINER_NAME"

        # echo statement is purely for housekeeping
        echo "STATUS: Container $CONTAINER_NAME STOPPED at $(date +%Y-%m-%dT%H:%M:%S%Z)" >> scripts.log

        # delete utility file
        rm ./recycle_util_$CONTAINER_NAME
        echo "STATUS: Container $CONTAINER_NAME RECYCLED at $(date +%Y-%m-%dT%H:%M:%S%Z)" >> scripts.log
    else
        # echo statement is purely for housekeeping
        echo "STATUS: Container $CONTAINER_NAME not ready to be recycled" >> scripts.log
    fi
fi

# set up MITM
MITM_PORT=8080
sudo forever -l /var/lib/lxc/$CONTAINER_NAME/rootfs/var/log/auth.log -a
start /home/student/MITM/mitm.js -n $CONTAINER_NAME -i $CONTAINER_IP -p $MITM_PORT --auto-access --auto-access-fixed 2 --debug
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_NAME"
sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$EXTERNAL_IP"
sudo ip addr add "$EXTERNAL_IP"/16 brd + dev "eth0"
# are these port numbers right? 
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --protocol tcp --dport $MITM_PORT --jump DNAT --to-destination "$EXTERNAL_IP":"$MITM_PORT"

echo "SUCCESS: $(pwd)/recycle.sh (0)" >> scripts.log
exit 0
