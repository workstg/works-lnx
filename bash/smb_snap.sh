#!/bin/bash

VG="vg01"
LV="lv01"
BASEMNT="/export"

SNAPMNT="${BASEMNT}/.snap"
SNAPSIZE="30G"
SNAPFREC="${BASEMNT}/.snap-old"

SHAREDIR=("share1" "share2" "share3")

# Unmount old snapshot
[ -d ${SNAPMNT} ] || mkdir -p ${SNAPMNT}
if mountpoint -q ${SNAPMNT}; then
   umount ${SNAPMNT}
   if [ $? -ne 0 ]; then
      sleep 15
      umount ${SNAPMNT}
      if [ $? -ne 0 ]; then
         # 古いスナップショットのアンマウントに失敗
         exit 1
      fi
   fi
fi

# Create snapshot
SNAPNAME=$(TZ=GMT date +GMT-%Y.%m.%d-%H.%M.%S)
sync
/sbin/lvcreate -s -L ${SNAPSIZE} -n ${SNAPNAME} /dev/${VG}/${LV}

mount -o nouuid,ro /dev/${VG}/${SNAPNAME} ${SNAPMNT}
if [ $? -ne 0 ]; then
   # スナップショットのマウントに失敗
   exit 2
fi

# Delete old snapshot
if [ -f ${SNAPFREC} ]; then
   SNAPOLD=$(cat ${SNAPFREC})
   /sbin/lvremove -f /dev/${VG}/${SNAPOLD}
   if [ $? -ne 0 ]; then
      # 古いスナップショットの削除に失敗
      exit 3
   fi
fi

# Create VSS link
for DIR in ${SHAREDIR[@]}
do
   if [ -d ${BASEMNT}/${DIR}/.snap ]; then
      rm -f ${BASEMNT}/${DIR}/.snap/GMT*
      ln -s ${SNAPMNT}/${DIR} ${BASEMNT}/${DIR}/.snap/${SNAPNAME}
   fi
done

echo -n $SNAPNAME > $SNAPFREC

exit 0