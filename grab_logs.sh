#!/bin/bash
if [ $# -ne 1 ]
then
        echo "[usage] grab_logs <container_name>"
        exit 1
fi

#This script saves the session stream file and authentication log associated with a container name
#It also deletes all login/out files associated with it to ensure that mistakes do not occur
#Keylogger files are left alone because they don't have naming overlap problems
cont_name=$1
date_time=$(cat /home/student/MITM/logs/logins/$1.log | head -n 1 | cut -d';' -f3)
date=$(echo $date_time | cut -d'_' -f1-3)
cont_type=$(grep "config" ./recycle_util_$cont_name | cut -d ':' -f2)

#saving the authentication log
sudo mv /home/student/MITM/logs/authentication_attempts/$1.log /home/student/attacker_logs/$date/auth

#saving the session stream file
sudo mv /home/student/MITM/logs/session_streams/$date_time.log.gz /home/student/attacker_logs/$date/streams/$cont_type

#moving somewhat less important files
sudo mv /home/student/MITM/logs/logins/$1.log /home/student/attacker_logs/$date/logins
sudo mv /home/student/MITM/logs/logouts/$1.log /home/student/attacker_logs/$date/logouts
