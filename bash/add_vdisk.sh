#!/bin/bash

VM_NAME="vm01"
ADD_SIZE="100G"
VD_DEV="sdc"

# 空の仮想ディスク作成
VD_FILE=${VM_NAME}-${VD_DEV}.qcow2
cd /var/lib/libvirt/images
if [ -f ${VD_FILE} ]; then
   echo "${VD_FILE} : already exists"
   exit 1
fi
qemu-img create -f qcow2 ${VD_FILE} ${ADD_SIZE}

# オンラインで仮想マシンに接続
virsh attach-device ${VM_NAME} <(cat <<EOF
<disk type='file' device='disk'>
   <driver name='qemu' type='qcow2' cache='none'/>
   <source file='/var/lib/libvirt/images/${VD_FILE}'/>
   <target dev='${VD_DEV}' bus='virtio'/>
</disk>
EOF
)

# 設定の永続化
virsh attach-device ${VM_NAME} --config <(cat <<EOF
<disk type='file' device='disk'>
   <driver name='qemu' type='qcow2' cache='none'/>
   <source file='/var/lib/libvirt/images/${VD_FILE}'/>
   <target dev='${VD_DEV}' bus='virtio'/>
</disk>
EOF
)

exit 0
