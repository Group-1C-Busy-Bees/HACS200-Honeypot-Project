#!/bin/bash
# Catching incorrect params for set up command
if [[ $# -ne 1 ]];
then
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: incorrect params in $(pwd)/setup_little_fin.sh (6)" >> scripts.log
	exit 6
fi

container_name=$1

sudo lxc-attach -n "$container_name" -- bash -c "mkdir Customer_Service Services Activity; cd Customer_Service; mkdir Resources; cd ../Services; mkdir Credit_Card Retirement; cd ../Activity; mkdir Transfers"

cp little_bankacc_customer.csv /var/lib/lxc/"$CONTAINER_NAME"/rootfs/home/Customer_Service/bankacc_customer.csv

cp little_creditcard_info.csv /var/lib/lxc/"$CONTAINER_NAME"/rootfs/home/Services/Credit_Card/creditcard_info.csv 

cp little_moneytransfer_hist.xls /var/lib/lxc/"$CONTAINER_NAME"/rootfs/home/Activity/Transfers/moneytransfer_hist.xls

echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $(pwd)/setup_little_fin.sh completed (0)" >> scripts.log
exit 0
