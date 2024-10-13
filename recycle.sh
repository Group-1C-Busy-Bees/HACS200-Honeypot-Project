#!/bin/bash

# Checking proper command usage
if [[ $# -ne 3 ]]
then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: incorrect params in $(pwd)/recycle.sh (1)" >> scripts.log
    exit 1
fi

# Storing container name to a variable
CONTAINER_NAME="$3"
# Storing external IP to a variable
EXTERNAL_IP="$2"
# Gets container IP address
CONTAINER_IP=$(sudo lxc-info -n "$CONTAINER_NAME" | grep "IP" | cut -d ' ' -f 14-)

# Checking if utility file does NOT exist
if [[ ! -e ./recycle_util_"$CONTAINER_NAME" ]]
then
    # Select random config from honeypot_configs
    HP_CONFIG=$(shuf -n 1 ./honeypot_configs)
    # runs selected config script
    ./setup_"$HP_CONFIG"

    # Output redirect so that the first line of the utility file contains:
    # number of minutes to run container, container name, and start time of container
    echo "$1 "$CONTAINER_NAME" $(date +%s)" > ./recycle_util_"$CONTAINER_NAME"
    echo "STATUS: "$CONTAINER_NAME" STARTED at $(date +%Y-%m-%dT%H:%M:%S%Z)" >> scripts.log

    # set up NAT rules
    sudo ip addr add "$EXTERNAL_IP"/16 brd + dev eth0
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"
    sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$EXTERNAL_IP"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: nat rules set for "$CONTAINER_NAME"" >> scripts.log
else # container is already up, does not need to be created
    # Calculating a container’s uptime
    CURRENT_TIME=$(date +%s)
    START_TIME=$(cat ./recycle_util_"$CONTAINER_NAME" | cut -d ' ' -f3)
    TIME_ELAPSED=$((CURRENT_TIME - START_TIME))
    TARGET_DURATION=$(cat ./recycle_util_"$CONTAINER_NAME" | cut -d ' ' -f1) # should be 10

    # Checking to see if it is time to recycle
    if [[ "$TIME_ELAPSED" -ge $(("$TARGET_DURATION" * 60)) ]]
        then
        # remove NAT rules & delete container
        sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"
        sudo iptables --table nat --delete POSTROUTING --source "$CONTAINER_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$EXTERNAL_IP"
        sudo ip addr delete "$EXTERNAL_IP"/16 brd + dev eth0

        echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: nat rules removed for "$CONTAINER_NAME"" >> scripts.log
        # ALSO MAKE SURE TO SAVE MITM/SNOOPY LOGS BEFORE DELETING, MIGHT GO HERE

        # Stop and delete container
        sudo lxc-stop -n "$CONTAINER_NAME"
        sudo lxc-destroy -n "$CONTAINER_NAME"

        # echo statement is purely for housekeeping
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: "$CONTAINER_NAME" STOPPED at $(date +%Y-%m-%dT%H:%M:%S%Z)" >> scripts.log

        # delete utility file
        rm ./recycle_util_"$CONTAINER_NAME"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: "$CONTAINER_NAME" RECYCLED at $(date +%Y-%m-%dT%H:%M:%S%Z)" >> scripts.log
    else
        # echo statement is purely for housekeeping
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: "$CONTAINER_NAME" not ready to be recycled" >> scripts.log
    fi
fi


# create new container to replace one that we recently deleted
if sudo lxc-ls | grep -q "$CONTAINER_NAME"; 
then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: "$CONTAINER_NAME" may not have been properly handled in $(pwd)/recycle.sh (100)" >> scripts.log
    exit 100
else
    sudo lxc-create -n “"$CONTAINER_NAME"” -t download -- -d ubuntu -r focal -a amd64
    sudo lxc-start -n “"$CONTAINER_NAME"”
    sudo systemctl restart lxc-net
    sudo lxc-attach “"$CONTAINER_NAME"” -- apt install openssh-server -y
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: "$CONTAINER_NAME" created in $(pwd)/recycle.sh" >> scripts.log
fi

# install MITM
DAY=`date +%Y-%m-%d`
sudo forever -l ~/attacker_logs/$DAY/"$CONTAINER_NAME".logs/`date +%s` -a start ~/MITM/mitm.js -n "$CONTAINER_NAME" -i "$CONTAINER_IP" -p 32887 --auto-access --auto-access-fixed 4 --debug
sudo sysctl -w net.ipv4.conf.all.route_localnet=1

sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"
sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$EXTERNAL_IP"
sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:32887
sudo ip addr add "$EXTERNAL_IP"/16 brd + dev eth0
echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: installed mitm on "$CONTAINER_NAME" in $(pwd)/recycle.sh" >> scripts.log
echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $(pwd)/recycle.sh completed (0)" >> scripts.log
exit 0
