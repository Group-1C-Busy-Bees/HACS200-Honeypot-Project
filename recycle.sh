#!/bin/bash
# Checking proper command usage
if [[ $# -ne 2 ]]
then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: improper usage of $(pwd)/recycle.sh <container name> <external_ip> (1)" >> scripts.log
    exit 1
fi

CONTAINER_NAME="$1" # container name
EXTERNAL_IP="$2" # external ip
MAX_DURATION=600 # max amount of time an attacker has in a honeypot (seconds)
MAX_IDLE_TIME=120 # attacker's maximum idle time (seconds)

# the util file only has hp config, does not have login time recorded and therefore no attacker
if [[ $(wc -l ./recycle_util_"$CONTAINER_NAME”) -eq 1 ]]
then
  if [[ $(wc -l ~/MITM/logs/logins/"$CONTAINER_NAME".log) -lt 1 ]]
  then 
    exit 2 # still no attacker
  else
    LOG_PRE=$(cat ~/MITM/logs/logins/”$CONTAINER_NAME”.log | cut -d';' -f1 | cut -d' ' -f2)
    # Login time in epoch for easy math
    LOGIN_EPOCH=$(date -d "$LOG_PRE" +"%s")
    LOGIN_TIME=$(cat ~/MITM/logs/logins/"$CONTAINER_NAME".log | cut -d';' -f3)
    # put login time, also the name of MITM logs, into util file
    echo “login:“$LOGIN_TIME”” >> ./recycle_util_"$CONTAINER_NAME" 
    # convert to epoch time and also stick in util file for later calculations of time elapsed, etc
    echo “epoch:“$LOGIN_EPOCH”” >> ./recycle_util_"$CONTAINER_NAME"
  fi
else
  # check the current time, see if container needs to be recycled.
  # Calculating how long attacker has been inside container
  CURRENT_TIME=$(date +%s)
  LOGIN_EPOCH=$(grep “epoch” ./recycle_util_$CONTAINER_NAME | cut -d ':' -f2)
  TIME_ELAPSED=$(($CURRENT_TIME - $LOGIN_EPOCH))

  # Calculating idle time
  LOG_NAME=$(grep “login” ./recycle_util_$CONTAINER_NAME | cut -d ' ' -f2)
  LAST_ACTION=$(tail -n 1 ~/attacker_logs/debug_logs/$HP_CONFIG/$START_TIME | cut -c 1-19)
  LAST_ACTION_EPOCH=$(date -d "$LAST_ACTION" +"%s")

  # Check for logout
  LOGOUT=$(grep "Honeypot ended shell" ~/attacker_logs/$HP_CONFIG/$START_TIME | wc -l)


  # if container should be recycled
  if [[ “$LOGOUT” -eq 1 || $(($CURRENT_TIME - $LAST_ACTION_EPOCH)) -ge $MAX_IDLE_TIME || "$TIME_ELAPSED" -ge $MAX_DURATION ]]
    then
    # if yes, recycle
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
    
    HP_CONFIG=$(shuf -n 1 ./honeypot_configs)
    # create new version of the util file with the honeypot config in it
    touch ./recycle_util_"$CONTAINER_NAME"
    echo config:"$HP_CONFIG" >> ./recycle_util_"$CONTAINER_NAME"
    # copy new randomly selected honeypot config
    sudo lxc-copy -n "$HP_CONFIG" -N "$CONTAINER_NAME"
    # start up container 
    sudo lxc-start -n "$CONTAINER_NAME"
    
    # set-up MITM and auto-access
    sudo forever -l ~/attacker_logs/debug_logs/"$HP_CONFIG"/"$START_TIME" -a start ~/MITM/mitm.js -n "$CONTAINER_NAME" -i "$CONTAINER_IP" -p 32887 --auto-access --auto-access-fixed 2 --debug # does auto-access actually work
    sudo sysctl -w net.ipv4.conf.all.route_localnet=1
       
    # set-up container NAT rules (putting container back online again)
     sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"
     sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$EXTERNAL_IP"
     # set-up NAT rules for MITM
     sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:64462 # incorrect destination (port number)???!?!?!
     # housekeeping echo statement
     echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: recycled "$CONTAINER_NAME"" >> scripts.log

    # if no, exit
    exit 3
fi
