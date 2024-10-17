#!/bin/bash
# RECYCLE USAGE: ./recycle <container name> <external_ip> <minutes_to_run> <idle_time>

# Checking proper command usage
if [[ $# -ne 4 ]]
then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: improper usage of $(pwd)/recycle.sh <container name> <external_ip> <minutes_to_run> <idle time> (1)" >> scripts.log
    exit 1
fi

# Storing container name to a variable
CONTAINER_NAME="$1"
# Storing external IP to a variable
EXTERNAL_IP="$2"
# Storing container max duration to a variable
MAX_DURATION_TIME="$3"
# Storing current idle 
IDLE_TIME="$4"
# Gets container IP address
CONTAINER_IP=$(sudo lxc-info -n "$CONTAINER_NAME" | grep "IP" | cut -d ' ' -f 14-)
# Gets login file line count
$LINE_COUNT=$((wc -l ~/MITM/logs/logins/$CONTAINER_NAME.log))

# if attacker has been in container for 10 minutes OR if attacker has been idle for 2 minutes OR if attacker has logged out
    # manage logs
    # remove NAT rules
    # start by-standing container
    # set up NAT rules for by-standing container
    # stop conatiner
    # delete container
    # create new container
    # randomly select honeypot config
    # run selected honeypot config script
#  else if attacker still has time to do stuff
    # return 
    

# Checking if utility file does NOT exist aka no container exists (technically should never run?)
# TODO: CHANGE THIS TO WORK OFF OF LOGINS, CHANGE OTHER LOGIC ACCORDINGLY
if [[ $LINE_COUNT -ge 1 ]]
then
    # Select random config from honeypot_configs
    HP_CONFIG=$(shuf -n 1 ./honeypot_configs)
    # runs selected config script which sets up container with randomly selected honeypot configuration
    ./setup_"$HP_CONFIG"

    # Output redirect so that the first line of the utility file contains: number of minutes to run container, idle time, container name, and start time of container
    echo ""$MAX_DURATION_TIME" "$IDLE_TIME" "$HP_CONFIG" $(date +%s)" > ./recycle_util_"$CONTAINER_NAME"
    START_TIME=`date +%Y-%m-%dT%H:%M:%S%Z`
    echo " $START_TIME" >> scripts.log

    # set up NAT rules
    sudo ip addr add "$EXTERNAL_IP"/16 brd + dev eth0
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"
    sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$EXTERNAL_IP"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: nat rules set for "$CONTAINER_NAME"" >> scripts.log

    # set-up MITM
    DAY=`date +%Y-%m-%d`
    sudo forever -l ~/attacker_logs/debug_logs/$HP_CONFIG/$START_TIME -a start ~/MITM/mitm.js -n "$CONTAINER_NAME" -i "$CONTAINER_IP" -p 32887 --auto-access --auto-access-fixed 4 --debug
    sudo sysctl -w net.ipv4.conf.all.route_localnet=1

    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:32887
    sudo ip addr add "$EXTERNAL_IP"/16 brd + dev eth0
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: set-up mitm on "$CONTAINER_NAME" in $(pwd)/recycle.sh" >> scripts.log
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $(pwd)/recycle.sh completed (0)" >> scripts.log

    while true; do
        LOGIN_TIME=`grep "Opened shell for attacker" ~/attacker_logs/debug_logs/$HP_CONFIG/$START_TIME | cut -c 1-19`
        if [ $LOGIN_TIME != "" ]
        then 
            LOGIN_EPOCH=`date -d "$LOGIN_TIME" +"%s"`
            echo " $LOGIN_EPOCH" >> ./recycle_util_$CONTAINER_NAME
            break
        fi
    done

else # container is already up, does not need to be created
    while true; do # check if container needs to be recycled until it does need to be recyled
        # Calculating how long attacker has been inside
        CURRENT_TIME=$(date +%s)
        LOGIN_TIME=$(cat ./recycle_util_$CONTAINER_NAME | cut -d ' ' -f6)
        TIME_ELAPSED=$((CURRENT_TIME - LOGIN_TIME))
        TARGET_DURATION=$(cat ./recycle_util_$CONTAINER_NAME | cut -d ' ' -f1)
    
        # Calculating idle time
        LOG_NAME=$(cat ./recycle_util_$CONTAINER_NAME | cut -d ' ' -f5)
        LAST_ACTION=$(tail -n 1 ~/attacker_logs/debug_logs/$HP_CONFIG/$START_TIME | cut -c 1-19) # should these be backticks or $()? -grace 10/16
        LAST_ACTION_EPOCH=$(date -d "$LAST_ACTION" +"%s")
        IDLE_TIME=$(cat ./recycle_util_$CONTAINER_NAME | cut -d ' ' -f2)
    
        # Check for logout
        LOGOUT=$(grep "Honeypot ended shell" ~/attacker_logs/$HP_CONFIG/$START_TIME | wc -l)
        
        # Checking to see if it is time to recycle
        if [[ $LOGOUT -eq 1 || $(($CURRENT_TIME - $LAST_ACTION_EPOCH)) -ge $(($IDLE_TIME * 60)) || $TIME_ELAPSED -ge $(($TARGET_DURATION * 60)) ]]
            then # if it is time to recycle
            # remove NAT rules
            sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"
            sudo iptables --table nat --delete POSTROUTING --source "$CONTAINER_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$EXTERNAL_IP"
            sudo ip addr delete "$EXTERNAL_IP"/16 brd + dev eth0

            # housekeeping echo statement
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: nat rules removed for "$CONTAINER_NAME"" >> scripts.log

            # Stop old container
            sudo lxc-stop -n "$CONTAINER_NAME"
                            
            # echo statement is for housekeeping
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: "$CONTAINER_NAME" STOPPED at $(date +%Y-%m-%dT%H:%M:%S%Z)" >> scripts.log

            # delete utility file
            rm ./recycle_util_"$CONTAINER_NAME"
            
            # manage logs (should be a script call)

            # set up stand-by and old containers for recycling
            STANDBY_CONTAINER="${CONTAINER_NAME}_SB"
            DEL_CONTAINER="${CONTAINER_NAME}_DEL"
            sudo lxc move "$CONTAINER_NAME" "$DEL_CONTAINER" # need to test if this works
            sudo lxc move "$STANDBY_CONTAINER" "$CONTAINER_NAME" # need to test if this works
            
            # start stand-by container
            sudo lxc-start -n "$CONTAINER_NAME"
            
            # set-up stand-by container's NAT rules
            sudo ip addr add "$EXTERNAL_IP"/16 brd + dev eth0
            sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"
            sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$EXTERNAL_IP"
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: nat rules set for "$CONTAINER_NAME"" >> scripts.log
            
            # start mitm logs?
    
            # Delete old container
            sudo lxc-destroy -n "$DEL_CONTAINER"
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: "$CONTAINER_NAME" RECYCLED at $(date +%Y-%m-%dT%H:%M:%S%Z)" >> scripts.log          
            
            # create new container to replace one that we recently deleted
            if sudo lxc-ls | grep -q "$STANDBY_CONTAINER"; 
            then
                echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: "$STANDBY_CONTAINER" may not have been properly handled in $(pwd)/recycle.sh (100)" >> scripts.log
                exit 100
            else
                sudo lxc-create -n "$STANDBY_CONTAINER" -t download -- -d ubuntu -r focal -a amd64
                sudo lxc-start -n "$STANDBY_CONTAINER"
                sudo systemctl restart lxc-net # do we still need this?
                sudo lxc-attach -n "$STANDBY_CONTAINER" -- apt install openssh-server -y
                sudo lxc-stop -n "$STANDBY_CONTAINER" # new stand-by container should be idle when created
                echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: "$STANDBY_CONTAINER" created in $(pwd)/recycle.sh" >> scripts.log
            fi
            break # stop checking; container has been recycled
        fi
    done
fi

