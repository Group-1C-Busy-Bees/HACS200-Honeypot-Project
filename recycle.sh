#!/bin/bash
# COMMAND USAGE: ./recycle <container name> <external_ip>

# Checking proper command usage
if [[ $# -ne 2 ]]
then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: improper usage of $(pwd)/recycle.sh <container name> <external_ip> (1)" >> scripts.log
    exit 1
fi

CONTAINER_NAME="$1" # container name
EXTERNAL_IP="$2" # external ip
MAX_DURATION=600 # max amount of time an attacker has in a honeypot (in seconds)
MAX_IDLE_TIME=120 # attacker's maximum idle time (in seconds)

# When a container is created, the honeypot (hp) configuration it was given is stored into its 
# corresponding recycle utility file (file name structure: recycle_util_<CONTAINER NAME>). In the
# if statement below we are checking to see if the utility file the util file only has the hp
# configuration. Depending on what is currently in the util file, it determines what will happen 
# next. Here is a simplified outline of the logic we used:
# if the util file only has the hp config
# then check corresponding MITM login logs
#     if MITM login logs indicate no login
#     then exit (do nothing)
#     else (the case that login logs indicates a login) add login time to util file
# else (the case that util file has hp config AND a login time)
# calculate attacker's duration inside container
# calculate attacker's idle time
# check if attacker logged out
# if the attacker has been in the container for 10 minutes OR idle for 2 minutes OR has logged out
# then recycle hp container
# else exit (do nothing)

# checking what contents are in util file
if [[ $(wc -l ./recycle_util_"$CONTAINER_NAME" | cut -d ' ' -f1) -eq 1 ]]
then
    if [[ $(wc -l ~/MITM/logs/logins/"$CONTAINER_NAME".log | cut -d ' ' -f1) -lt 1 ]]
    then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: $CONTAINER_NAME is waiting for an attacker." >> scripts.log
        exit 2 # still no attacker
    else
        LOG_PRE=$(cat ~/MITM/logs/logins/"$CONTAINER_NAME".log | cut -d';' -f1 | cut -d' ' -f2)
        # Login time in epoch for easy math
        LOGIN_EPOCH=$(date -d "$LOG_PRE" +"%s")
        LOGIN_TIME=$(cat ~/MITM/logs/logins/"$CONTAINER_NAME".log | cut -d';' -f3)
        # put login time, also the name of MITM logs, into util file
        echo "login:"$LOGIN_TIME"" >> ./recycle_util_"$CONTAINER_NAME" 
        # convert to epoch time and also stick in util file for later calculations of time elapsed, etc
        echo "epoch:"$LOGIN_EPOCH"" >> ./recycle_util_"$CONTAINER_NAME"
    fi
else
    # check the current time, see if container needs to be recycled.
    # Calculating how long attacker has been inside container
    CURRENT_TIME=$(date +%s)
    LOGIN_EPOCH=$(grep "epoch" ./recycle_util_$CONTAINER_NAME | cut -d ':' -f2)
    LOGIN_TIME=$(grep "login" ./recycle_util_$CONTAINER_NAME | cut -d ':' -f2)
    TIME_ELAPSED=$((CURRENT_TIME - LOGIN_EPOCH))
    
    # Calculating idle time
    ID_PRE=$(tail -n 1 ~/MITM/logs/keystrokes/"$LOGIN_TIME".log | cut -d ' ' -f2)
    LAST_ACTION_EPOCH=$(date -d "$ID_PRE" +"%s")
    CURRENT_IDLE_TIME=$((CURRENT_TIME - LAST_ACTION_EPOCH))
    
    # Check for logout
    LOGOUT=$(wc -l ~/MITM/logs/logouts/"$CONTAINER_NAME".log | cut -d ' ' -f1)

    # Check if container should be recycled
    # recycle container if 1 of 3 conditions are met:
    # 1. Attacker logged out
    # 2. Attacker's idle time >= 2 minutes
    # 3. Attacker has spent >= 10 minutes inside container
    if [[ $LOGOUT -eq 1 || $CURRENT_IDLE_TIME -ge $MAX_IDLE_TIME || $TIME_ELAPSED -ge $MAX_DURATION ]]
    then
        # met 1 of 3 conditions? recycle.
        # stop MITM forever process
        MITM_FOREVER_INDEX=$(sudo forever list | grep "$CONTAINER_NAME" | awk '{print $2}' | grep -oE "[0-9]+");
        sudo forever stop "$MITM_FOREVER_INDEX";

        # remove NAT rules for MITM
        sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:32887 # is this right?
        # remove NAT rules for container (take container offline)
        sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"
        sudo iptables --table nat --delete POSTROUTING --source "$CONTAINER_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$EXTERNAL_IP"
        # housekeeping echo statement
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: nat rules removed for "$CONTAINER_NAME"" >> scripts.log
                
        # Stop old container
        sudo lxc-stop -n "$CONTAINER_NAME";
        # echo statement is for housekeeping
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: "$CONTAINER_NAME" STOPPED at $(date +%Y-%m-%dT%H:%M:%S%Z)" >> scripts.log
        # Delete old container
        sudo lxc-remove -n "$CONTAINER_NAME";
        # echo statement is for housekeeping
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: "$CONTAINER_NAME" REMOVED at $(date +%Y-%m-%dT%H:%M:%S%Z)" >> scripts.log  
        # delete associated utility file
        rm ./recycle_util_"$CONTAINER_NAME"
        # manage logs (should be a script call)
        ./grab_logs $CONTAINER_NAME;
        
        HP_CONFIG=$(shuf -n 1 ./setup/honeypot_configs)
        # create new version of the util file with the honeypot config in it
        echo "config:"$HP_CONFIG"" >> ./recycle_util_"$CONTAINER_NAME"
        # copy new randomly selected honeypot config
        sudo lxc-copy -n "$HP_CONFIG" -N "$CONTAINER_NAME";
        # start up container 
        sudo lxc-start -n "$CONTAINER_NAME";
        sudo systemctl restart lxc-net; # DO WE NEED THIS
        sudo lxc-attach -n "$CONTAINER_NAME" -- apt install openssh-server -y;
        
        # set-up MITM and auto-access
        # does auto-access actually work
        sudo forever -l ~/attacker_logs/debug_logs/"$HP_CONFIG"/"$(date -Iseconds)" -a start ~/MITM/mitm.js -n "$CONTAINER_NAME" -i "$CONTAINER_IP" -p 32887 --auto-access --auto-access-fixed 2 --debug; 
        sudo sysctl -w net.ipv4.conf.all.route_localnet=1 # DO WE NEED THIS
        
        # set-up container NAT rules (putting container back online again)
        sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"
        sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$EXTERNAL_IP"
        # set-up NAT rules for MITM
        sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:32887 # is this right?
        # housekeeping echo statement
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: recycled "$CONTAINER_NAME"" >> scripts.log
    else
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $CONTAINER_NAME not ready to be recycled" >> scripts.log
        # if no, exit
        exit 3
    fi
fi
