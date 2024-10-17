#!/bin/bash
# Catching incorrect params for set up command
if [[ $# -ne 1 ]];
then
 	echo "[$(date +'%Y-%m-%d %H:%M:%S')] CRITICAL ERROR: incorrect params in $(pwd)/setup_little_med.sh (8)" >> scripts.log
	exit 8
fi

container_name=$1

sudo lxc-attach -n "$container_name" -- bash -c "mkdir Patients General Legal; cd Patients; mkdir Data; cd ../General; mkdir Historical; cd ../Public; mkdir Information Documents"

cp little_patient_files.csv /var/lib/lxc/"$CONTAINER_NAME"/rootfs/home/Patients/Data/patient_files.csv

cp little_hospital_hist.xls /var/lib/lxc/"$CONTAINER_NAME"/rootfs/home/General/Historical/hospital_hist.xls

cp little_insurance.csv /var/lib/lxc/"$CONTAINER_NAME"/rootfs/home/Legal/Information/insurance.csv

echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $(pwd)/setup_little_med.sh completed (0)" >> scripts.log
exit 0
