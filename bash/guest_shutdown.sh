#!/bin/bash

VC_URL="https://vc.example.com"
VC_USER="Administrator@vsphere.local"
VC_PW="password"
VM_NAME="vm-1"

# Authentication
URL="${VC_URL}/rest/com/vmware/cis/session"
SESSION=$(curl -s -k -m 60 -X POST -H "Content-Type: application/json" -u ${VC_USER}:${VC_PW} ${URL} | jq -r .value)

if [ -z "${SESSION}" ]; then
   echo "[Error] vCenter Server not respond."
   exit 1
elif [[ "${SESSION}" =~ "error" ]]; then
   echo "[Error] Authentication error occued."
   exit 2
fi

# Get VM information
URL="${VC_URL}/rest/vcenter/vm?filter.names.1=${VM_NAME}"
VM_ID=$(curl -s -k -X GET -H "vmware-api-session-id: ${SESSION}" -H "Content-Type: application/json" ${URL} | jq -r .value[].vm)

# Check Guest Power State
URL="${VC_URL}/rest/vcenter/vm/${VM_ID}/guest/power"
VM_POWER=$(curl -s -k -X GET -H "vmware-api-session-id: ${SESSION}" -H "Content-Type: application/json" ${URL} | jq -r .value.state)

i=0
while [ "${VM_POWER}" != "NOT_RUNNING" ];
do
   # Guest Shutdown
   URL="${VC_URL}/rest/vcenter/vm/${VM_ID}/guest/power?action=shutdown"
   RES=$(curl -s -k -o /dev/null -w '%{http_code}\n' -X POST -H "vmware-api-session-id: ${SESSION}" -H "Content-Type: application/json" ${URL})
   sleep 10

   URL="${VC_URL}/rest/vcenter/vm/${VM_ID}/guest/power"
   VM_POWER=$(curl -s -k -X GET -H "vmware-api-session-id: ${SESSION}" -H "Content-Type: application/json" ${URL} | jq -r .value.state)

   if [ $i -ge 6 ]; then
      # Force Power Off
      URL="${VC_URL}/rest/vcenter/vm/${VM_ID}/power/stop"
      RES=$(curl -s -k -o /dev/null -w '%{http_code}\n' -X POST -H "vmware-api-session-id: ${SESSION}" -H "Content-Type: application/json" ${URL})
      if [ ${RES} -ne 200 ]; then
         echo "[Error] Failed to VM powered off."
         exit 4
      else
         echo "VM powered off."
         exit 0
      fi
   fi
   i=$(expr $i + 1)
done

exit
