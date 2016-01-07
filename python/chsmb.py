#!/usr/bin/env python
# -*- Coding: utf-8 -*-

SMBCONF = "/etc/samba/smb.conf"

import os
import sys
import shutil
import ConfigParser
from argparse import ArgumentParser

def getsection(target_file):
   config = ConfigParser.RawConfigParser()
   config.read(target_file)
   return config.sections()

def getuser(target_file, target_section):
   config = ConfigParser.ConfigParser()
   config.read(target_file)
   vusers = config.get(target_section, "valid users")
   vlist = vusers.split(", ")
   return "\n".join(vlist)

def adduser(target_file, target_section, target_user):
   config = ConfigParser.ConfigParser()
   config.read(target_file)
   vlist = config.get(target_section, "valid users")
   vlist = vlist + ", "
   vlist = vlist + target_user
   config.set(target_section, "valid users", vlist)

   file = open(target_file, "w")
   config.write(file)
   file.close()

def remuser(target_file, target_section, target_user):
   config = ConfigParser.ConfigParser()
   config.read(target_file)
   rlist = ""
   vlist = config.get(target_file, "valid users")
   vusers = vlist.split(", ")
   for vuser in vusers:
      if vuser == target_user:
         continue
      if len(rlist) != 0:
         rlist = rlist + ", "
      rlist = rlist + vuser

   config.set(target_section, "valid users", rlist)

   file = open(target_file, "w")
   config.write(file)
   file.close()

def bkconf(target_file)
   bkf = target_file + ".1"
   shutil.copy(target_file, bkf)

if __name__ == '__main__':
   desc = u'{0} [Args] [Options]\nDetailed options -h or --help'.format(__file__)
   argparser = ArgumentParser(description=desc)
   argparser.add_argument('-s', '--section', type=str, dest="section", required=True, help='set target section')
   argparser.add_argument('-a', '--add', type=str, dest="add_user", help='add user')
   argparser.add_argument('-r', '--remove', type=str, dest='remove_user', help='remove user')
   args = argparser.parse_args()

   if args.section == 'show':
      print getsection(SMBCONF)
      sys.exit()

   if args.add_user is None and args.remove_user is None:
      print getuser(SMBCONF, args.section)
      sys.exit()

   if args.add_user is not None:
      bkconf(SMBCONF)
      adduser(SMBCONF, args.section, args.add_user)

   if args.remove_user is not None:
      bkconf(SMBCONF)
      remuser(SMBCONF, args.section, args.remove_user)

   sys.exit()
