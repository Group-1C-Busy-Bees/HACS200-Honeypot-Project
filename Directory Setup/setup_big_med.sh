#!/bin/bash
# Catching incorrect params for set up command
if [[ $# -ne 1 ]];
then
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: incorrect params in $(pwd)/setup_big_med.sh (3)" >> scripts.log
	exit 3
fi

CONTAINER_NAME=$1

sudo lxc-attach -n "$CONTAINER_NAME" -- bash -c "mkdir Patients General Public; cd Patients; mkdir Data; cd ../General; mkdir Historical; cd ../Public; mkdir Information Documents"

cp big_patient_files.csv /var/lib/lxc/"$CONTAINER_NAME"/rootfs/home/Patients/Data/patient_files.csv

cp big_hospital_hist.xls /var/lib/lxc/"$CONTAINER_NAME"/rootfs/home/General/Historical/hospital_hist.xls

cp big_insurance.csv /var/lib/lxc/"$CONTAINER_NAME"/rootfs/home/Legal/Information/insurance.csv

echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $(pwd)/setup_big_med.sh completed (0)" >> scripts.log
exit 0
