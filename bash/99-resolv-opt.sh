#!/bin/bash

grep "single-request-reopen" /etc/resolv.conf >/dev/null 2>&1
if [ $? -ne 0 ]; then
   echo "options single-request-reopen" >> /etc/resolv.conf
fi

exit
