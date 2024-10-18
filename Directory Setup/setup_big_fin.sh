#!/bin/bash
# Catching incorrect params for set up command
if [[ $# -ne 1 ]];
then
 	echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: incorrect params in $(pwd)/setup_big_fin.sh (2)" >> scripts.log
	exit 2
fi

CONTAINER_NAME="$1"

sudo lxc-attach -n "$CONTAINER_NAME" -- bash -c "mkdir Customer_Service Services Activity ; cd Customer_Service ; mkdir Resources ; cd ../Services ; mkdir Credit_Card Retirement ; cd ../Activity ; mkdir Transfers"

# THE FOLLOWING COMMANDS NEED SUPERUSER (SU) PERMS 
cp big_bankacc_customer.csv /var/lib/lxc/"$CONTAINER_NAME"/rootfs/home/bankacc_customer.csv

cp big_creditcard_info.csv /var/lib/lxc/"$CONTAINER_NAME"/rootfs/home/creditcard_info.csv 

cp big_moneytransfer_hist.xls /var/lib/lxc/"$CONTAINER_NAME"/rootfs/home/moneytransfer_hist.xls

echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $(pwd)/setup_big_fin.sh complete (0)" >> scripts.log
exit 0
