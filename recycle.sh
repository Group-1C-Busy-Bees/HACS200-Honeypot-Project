#!/bin/bash
# RECYCLE USAGE: ./recycle <container name> <external_ip> <minutes_to_run> <idle_time>

# Checking proper command usage
if [[ $# -ne 4 ]]
then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: improper usage of $(pwd)/recycle.sh <container name> <external_ip> <minutes_to_run> <idle time> (1)" >> scripts.log
    exit 1
fi

# STORING PARAMETERS AS VARS
CONTAINER_NAME="$1" # container name
EXTERNAL_IP="$2" # external ip
MAX_DURATION_TIME="$3" # max amount of time an attacker has in a honeypot
IDLE_TIME="$4" # attacker's current idle time

# INITIALIZING NEW GLOBAL VARIABLES 
CONTAINER_IP=$(sudo lxc-info -n "$CONTAINER_NAME" | grep "IP" | cut -d ' ' -f 14-) # grabs and stores container ip
LINE_COUNT=$((wc -l ~/MITM/logs/logins/$CONTAINER_NAME.log)) # grabs and stores log-in file line count
HP_CONFIG=$(shuf -n 1 ./honeypot_configs) # randomly selects a honeypot config

# TODO: CHANGE THIS TO WORK OFF OF LOGINS, CHANGE OTHER LOGIC ACCORDINGLY
if [[ $LINE_COUNT -ge 1 ]]
then
    # Output redirect so that the first line of the utility file contains: number of minutes to run container, idle time, container name, and start time of container
    echo ""$MAX_DURATION_TIME" "$IDLE_TIME" "$HP_CONFIG" $(date +%s)" > ./recycle_util_"$CONTAINER_NAME"
    START_TIME=$(date +%Y-%m-%dT%H:%M:%S%Z)
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: "$CONTAINER_NAME" STARTED at "$START_TIME"" >> scripts.log

    # set-up MITM
    sudo forever -l ~/attacker_logs/debug_logs/"$HP_CONFIG"/"$START_TIME" -a start ~/MITM/mitm.js -n "$CONTAINER_NAME" -i "$CONTAINER_IP" -p 32887 --auto-access --auto-access-fixed 2 --debug # does auto-access actually work
    sudo sysctl -w net.ipv4.conf.all.route_localnet=1

    # NAT rules for attacker to container (putting container online)
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"
    sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$EXTERNAL_IP"
    # housekeeping echo statement
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: nat rules set for "$CONTAINER_NAME"" >> scripts.log
    # NAT rules for MITM
    sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:64462 # incorrect destination (port number)???!?!?!
    # housekeeping echo statement
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: set-up mitm on "$CONTAINER_NAME" in $(pwd)/recycle.sh" >> scripts.log

    # while(true) until an attacker logs in
    while true; do
        LOGIN_TIME=$(grep "Opened shell for attacker" ~/attacker_logs/debug_logs/$HP_CONFIG/$START_TIME | cut -c 1-19) # grepping for attacker log-in cue
        if [ "$LOGIN_TIME" != "" ] # checking to see if attacker has connected to container
        then 
            LOGIN_EPOCH=$(date -d "$LOGIN_TIME" +"%s") # grabs log-in time
            echo " "$LOGIN_EPOCH"" >> ./recycle_util_"$CONTAINER_NAME" # puts log=in time into util file
            break 
        fi
    done

else # TODO: FIX LOGIC
# container is already up, does not need to be created
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
        
        # Checking to see if container needs to be recycled based on the following cases:
        # attacker has been in honeypot for 10 minutes
        # attacker has been idle for 2 minutes
        # attacker has logged out
        if [[ "$LOGOUT" -eq 1 || $(($CURRENT_TIME - $LAST_ACTION_EPOCH)) -ge $(($IDLE_TIME * 60)) || "$TIME_ELAPSED" -ge $(($TARGET_DURATION * 60)) ]]
            then # if it is time to recycle...
            # remove NAT rules for MITM
            sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:64462 # incorrect destination (port number)???!?!?!
            # remove NAT rules for container (take container offline)
            sudo iptables --table nat --delete POSTROUTING --source "$CONTAINER_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$EXTERNAL_IP"
            sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"
            # housekeeping echo statement
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: nat rules removed for "$CONTAINER_NAME"" >> scripts.log
            
            # Stop old container
            sudo lxc-stop -n "$CONTAINER_NAME"
            # echo statement is for housekeeping
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: "$CONTAINER_NAME" STOPPED at $(date +%Y-%m-%dT%H:%M:%S%Z)" >> scripts.log
            # Delete old container
            sudo lxc-remove -n "$CONTAINER_NAME"
            # echo statement is for housekeeping
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: "$CONTAINER_NAME" REMOVED at $(date +%Y-%m-%dT%H:%M:%S%Z)" >> scripts.log  
            # delete associated utility file
            rm ./recycle_util_"$CONTAINER_NAME"
            # manage logs (should be a script call)
            ./grab_logs $CONTAINER_NAME
            
            # copy new randomly selected honeypot config
            sudo lxc-copy -n "$HP_CONFIG" -N "$CONTAINER_NAME"
            # start up container 
            sudo lxc-start -n "$CONTAINER_NAME"
            
            # set-up container NAT rules (putting container back online again)
            sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"
            sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$EXTERNAL_IP"
            # set-up NAT rules for MITM
            sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:64462 # incorrect destination (port number)???!?!?!
            # housekeeping echo statement
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: nat rules set for "$CONTAINER_NAME"" >> scripts.log
            
            break # stop checking; container has been recycled
        fi
    done
fi

