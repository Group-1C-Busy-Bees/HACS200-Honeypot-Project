#!/bin/bash
# COMMAND USAGE: ./recycle <container name> <external_ip> <mitm_port>

# Checking proper command usage
if [[ $# -ne 3 ]]
then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: improper usage of $(pwd)/recycle.sh <container name> <external_ip> <mitm_port> for $1, $2, $3 (1)" >> /home/student/scripts.log
    exit 1
fi

CONTAINER_NAME="$1" # container name
EXTERNAL_IP="$2" # external ip
MITM_PORT="$3"
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
if [[ $(wc -l /home/student/recycle_util_"$CONTAINER_NAME" 2>/dev/null | cut -d ' ' -f1) -eq 1 ]]
then
    # grabbing the file path for the forever log
    FOREVER_LOG=$(sudo forever list --plain 2>/dev/null | grep "\-n $CONTAINER_NAME" | awk '{print $20}')

    # EMERGENCY KICK CASE ONLY
    # CASE: THERE'S NOTHING IN THE LOGINS FILE BUT SOMEONE'S FAILED TO GET IN
    # MEANS MITM HAS DONE AN OOPSIE
    if [[ $(wc -l /home/student/MITM/logs/logins/"$CONTAINER_NAME".log 2>/dev/null | cut -d ' ' -f1) -lt 1 ]]
    then
      # emergency kick start case
      if [[ $(cat $FOREVER_LOG | grep "Authentication Failed" | wc -l) -gt 0 ]]
      then
          /home/student/emergency_kickstart $CONTAINER_NAME $EXTERNAL_IP $MITM_PORT
          echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: "$CONTAINER_NAME" EMERGENCY RECYCLED at $(date +%Y-%m-%dT%H:%M:%S%Z)" >> /home/student/scripts.log
          exit 73
      fi
    fi

    # the case that NO attacker has logged into the container
    if [[ $(cat $FOREVER_LOG | grep 'Adding the following credentials:' | wc -l | cut -d' ' -f1) -lt 1 ]]
    then
         #echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: $CONTAINER_NAME is waiting for an attacker." >> scripts.log
        exit 2 # still no attacker
    else
    # the case that an attacker HAS logged into the container
        LOG_PRE=$(cat $FOREVER_LOG | grep 'Adding the following credentials:' | cut -d' ' -f2)
        # Login time in epoch for easy math
        LOGIN_EPOCH=$(date -d "$LOG_PRE" +"%s")
        LOGIN_TIME=$(cat /home/student/MITM/logs/logins/"$CONTAINER_NAME".log | head -n 1 | cut -d';' -f3)
        # put login time, also the name of MITM logs, into util file
        echo "login:$LOGIN_TIME" >> /home/student/recycle_util_"$CONTAINER_NAME"
        # convert to epoch time and also stick in util file for later calculations of time elapsed, etc
        echo "epoch:$LOGIN_EPOCH" >> /home/student/recycle_util_"$CONTAINER_NAME"
        ATTACKER_IP=$(head -n 1 /home/student/MITM/logs/logins/"$CONTAINER_NAME".log | cut -d';' -f2)
        sudo iptables --insert INPUT -d 10.0.3.1 -p tcp --dport "$MITM_PORT" --jump DROP
        sudo iptables --insert INPUT -s "$ATTACKER_IP" -d 10.0.3.1 -p tcp --dport "$MITM_PORT" --jump ACCEPT
        echo "attacker:$ATTACKER_IP" >> /home/student/recycle_util_"$CONTAINER_NAME"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: attacker connected to $CONTAINER_NAME" >> /home/student/scripts.log
        exit 2
    fi
else
    # check the current time, see if container needs to be recycled.
    # Calculating how long attacker has been inside container
    CURRENT_TIME=$(date +%s)
    LOGIN_EPOCH=$(grep "epoch" /home/student/recycle_util_$CONTAINER_NAME | head -n 1| cut -d ':' -f2)
    LOGIN_TIME=$(grep "login" /home/student/recycle_util_$CONTAINER_NAME | head -n 1 | cut -d ':' -f2)
    TIME_ELAPSED=$((CURRENT_TIME - LOGIN_EPOCH))

    # Calculating idle time
    if [[ $(wc -l /home/student/MITM/logs/keystrokes/"$LOGIN_TIME".log 2>/dev/null | cut -d' ' -f1) -ne 0 ]]
    then
      ID_PRE=$(tail -n 1 /home/student/MITM/logs/keystrokes/"$LOGIN_TIME".log | cut -d ' ' -f2)
      LAST_ACTION_EPOCH=$(date -d "$ID_PRE" +"%s")
    else
      LAST_ACTION_EPOCH=$LOGIN_EPOCH
    fi
    CURRENT_IDLE_TIME=$(($CURRENT_TIME - $LAST_ACTION_EPOCH))

    # Check for logout
    LOGOUT=$(wc -l /home/student/MITM/logs/logouts/"$CONTAINER_NAME".log | cut -d ' ' -f1)

    # Check if container should be recycled
    # recycle container if 1 of 3 conditions are met:
    # 1. Attacker logged out
    # 2. Attacker's idle time >= 2 minutes
    # 3. Attacker has spent >= 10 minutes inside container
    if [[ $LOGOUT -ge 1 ]] || [[ $CURRENT_IDLE_TIME -ge $MAX_IDLE_TIME ]] || [[ $TIME_ELAPSED -ge $MAX_DURATION ]]
    then
        # met 1 of 3 conditions? recycle.
        # stop MITM forever process
        MITM_FOREVER_UID=$(sudo forever list 2>/dev/null | grep "$CONTAINER_NAME" | awk '{print $3}');
        sudo forever stop "$MITM_FOREVER_UID";

        CONTAINER_IP=$(sudo lxc-info -n "$CONTAINER_NAME" -iH) # GETS CONTAINER IP
        # remove NAT rules for MITM
        sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --protocol tcp --dport 22 --jump DNAT --to-destination 10.0.3.1:"$MITM_PORT" # is this right?
        # remove NAT rules for container (take container offline)
        sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"
        sudo iptables --table nat --delete POSTROUTING --source "$CONTAINER_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$EXTERNAL_IP"
        ATTACKER_IP=$(grep "attacker" /home/student/recycle_util_$CONTAINER_NAME | head -n 1| cut -d ':' -f2)
        sudo iptables --delete INPUT -d 10.0.3.1 -p tcp --dport "$MITM_PORT" --jump DROP
        sudo iptables --delete INPUT -s "$ATTACKER_IP" -d 10.0.3.1 -p tcp --dport "$MITM_PORT" --jump ACCEPT
        # housekeeping echo statement
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: nat rules removed for "$CONTAINER_NAME"" >> /home/student/scripts.log

        # Stop old container
        sudo lxc-stop -n "$CONTAINER_NAME";
        # echo statement is for housekeeping
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: "$CONTAINER_NAME" STOPPED at $(date +%Y-%m-%dT%H:%M:%S%Z)" >> /home/student/scripts.log
        # Delete old container
        sudo lxc-destroy -n "$CONTAINER_NAME";
        # echo statement is for housekeeping
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] STATUS: "$CONTAINER_NAME" REMOVED at $(date +%Y-%m-%dT%H:%M:%S%Z)" >> /home/student/scripts.log
        # delete associated utility file
        # manage logs (should be a script call)
        sudo /home/student/grab_logs $CONTAINER_NAME;

        HP_CONFIG=$(shuf -n 1 /home/student/setup/honeypot_configs)
        # create new version of the util file with the honeypot config in it
        # echo "IGNORE THIS GRACE IS TESTING MEOWMEOW"
        echo "config:"$HP_CONFIG"" > /home/student/recycle_util_"$CONTAINER_NAME"
        sudo chmod 777 /home/student/recycle_util_"$CONTAINER_NAME"
        # copy new randomly selected honeypot config and start container
        sudo lxc-copy -n "$HP_CONFIG" -N "$CONTAINER_NAME"; sleep 5; sudo lxc-start -n "$CONTAINER_NAME";

        sleep 5;

        # DO WE NEED TO INSTALL OPENSSH AGAIN? OPENSSH IS INSTALLED ON STANDBY CONTAINERS
        sudo systemctl restart lxc-net;
        sudo lxc-attach -n "$CONTAINER_NAME" -- sudo apt update -y;
        sudo lxc-attach -n "$CONTAINER_NAME" -- sudo apt-get install ssh -y;

        sleep 5;

        # set-up MITM and auto-access
        CONTAINER_IP=$(sudo lxc-info -n "$CONTAINER_NAME" -iH) # GETS CONTAINER IP
        # does auto-access actually work
        sudo forever -l /home/student/attacker_logs/debug_logs/"$HP_CONFIG"/"$(date -Iseconds)" -a start /home/student/MITM/mitm.js -n "$CONTAINER_NAME" -i "$CONTAINER_IP" -p "$MITM_PORT" --mitm-ip 10.0.3.1 --auto-access --auto-access-fixed 1 --debug;
        sudo sysctl -w net.ipv4.conf.all.route_localnet=1 # DO WE NEED THIS
        sleep 5;

        # set-up container NAT rules (putting container back online again)
        sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"
        sudo iptables --table nat --insert POSTROUTING --source "$CONTAINER_IP" --destination 0.0.0.0/0 --jump SNAT --to-source "$EXTERNAL_IP"
        # set-up NAT rules for MITM
        sudo iptables --table nat --insert PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --protocol tcp --dport 22 --jump DNAT --to-destination 10.0.3.1:"$MITM_PORT" # is this right?
        # housekeeping echo statement
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: recycled "$CONTAINER_NAME"" >> /home/student/scripts.log
        exit 3
    else
        # echo "[$(date +'%Y-%m-%d %H:%M:%S')] $CONTAINER_NAME not ready to be recycled" >> scripts.log
        # if no, exit
        exit 27
    fi
fi
