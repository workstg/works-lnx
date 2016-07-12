#!/bin/bash

VG="vg01"
LV="lv01"
BASEMNT="/export"

SNAPMNT="${BASEMNT}/.snap"
SNAPSIZE="30G"
SNAPFREC="${BASEMNT}/.snap-old"
SNAPLIMIT="6"

SHAREDIR=("share1" "share2" "share3")

[ -d ${SNAPMNT} ] || mkdir -p ${SNAPMNT}

# Create snapshot
SNAPNAME=$(TZ=GMT date +GMT-%Y.%m.%d-%H.%M.%S)
echo ${SNAPNAME} >> ${SNAPFREC}
sync
/sbin/lvcreate -s -L ${SNAPSIZE} -n ${SNAPNAME} /dev/${VG}/${LV}
mkdir ${SNAPMNT}/${SNAPNAME}
mount -o nouuid,ro /dev/${VG}/${SNAPNAME} ${SNAPMNT}/${SNAPNAME}
if [ $? -ne 0 ]; then
   # スナップショットのマウントに失敗
   exit 2
fi

# Unmount and delete old snapshot
while [ "$(cat ${SNAPFREC} | wc -l)" -gt "${SNAPLIMIT}" ]
do
   SNAPOLD=$(head -1 ${SNAPFREC})
   if mountpoint -q ${SNAPMNT}/${SNAPOLD}; then
      umount ${SNAPMNT}/${SNAPOLD}
      if [ $? -ne 0 ]; then
         sleep 15
         umount ${SNAPMNT}/${SNAPOLD}
         if [ $? -ne 0 ]; then
            # 古いスナップショットのアンマウントに失敗
            exit 1
         fi
      fi
      rm -rf ${SNAPMNT}/${SNAPOLD}
   fi
   /sbin/lvremove -f /dev/${VG}/${SNAPOLD}
   if [ $? -ne 0 ]; then
      # 古いスナップショットの削除に失敗
      exit 3
   fi
   sed -i '1d' ${SNAPFREC}
done

# Create VSS link
for DIR in ${SHAREDIR[@]}
do
   if [ -d ${BASEMNT}/${DIR}/.snap ]; then
      rm -f ${BASEMNT}/${DIR}/.snap/*
      while read LINE
      do
         ln -s ${SNAPMNT}/${LINE}/${DIR} ${BASEMNT}/${DIR}/.snap/${LINE}
      done < ${SNAPFREC}  
   fi
done

exit 0