#!/usr/bin/python

import sys
import string
from datetime import datetime

statcmd = "/usr/bin/ssh 3paradm@3par_mgt statvv -rw -d 60 -iter 1"
iops = []

def main():
   global iops
   results = dict()
   at_total = False
   
   for line in exec_cmd(statcmd):
      #print line # For debug
      split = string.split(line)
      
      if(at_total & len(split) > 0):
         results[split[1]] = split[2]
      if(len(split) == 1):
         at_total = True
   iops.append(results)
   
   #print datetime.now().strftime("%A, %d. %B %Y %I:%M%p") # For debug
   print "total,read,write"
   
   for result in iops:
      print result['t']+","+result['r']+","+result['w']

def exec_cmd(cmd):
   from subprocess import Popen, PIPE
   p = Popen(cmd.split(' '), stdout=PIPE, stderr=PIPE)
   out, err = p.communicate()
   return [ s for s in out.split('\n') if s ]

if __name__ == '__main__':
    main()
