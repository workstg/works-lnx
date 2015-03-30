#!/bin/bash
SWITCH=$1        # "on" or "off"
DEVICE=$2        # "eth0", "br0", etc.
RATE=$3        # for example "1000m"
 
if [ "$SWITCH" = "on" -o "$SWITCH" = "off" ]; then
   echo "--- Initialize $DEVICE and ifb0 ---"
   tc qdisc del dev $DEVICE ingress handle ffff:
   tc qdisc del dev ifb0 root handle 1: htb
   sleep 3
   rmmod ifb
else
   echo "Usage: $0 <on|off> <interface> <rate>"
fi
  
if [ "$SWITCH" = "on" ]; then
   echo "--- Load ifb module ---"
   sleep 3
   modprobe ifb
   sleep 3
   ip link set dev ifb0 up
  
   echo "--- Mirror $DEVICE to ifb0 ---"
   modprobe act_mirred
   sleep 3
   tc qdisc add dev $DEVICE ingress handle ffff:
   tc filter add dev $DEVICE parent ffff: protocol ip u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev ifb0
  
   echo "--- Traffic Shape ifb0 ---"
   tc qdisc add dev ifb0 root handle 1: htb default 10
   tc class add dev ifb0 parent 1:1 classid 1:10 htb rate ${RATE}bit
fi
 
exit