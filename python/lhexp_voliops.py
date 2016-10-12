#!/usr/bin/python

import subprocess
import xml.etree.ElementTree as ET

lh_cluster = 'cluster01'
statcmd = '/usr/bin/sshpass -p password /usr/bin/ssh -p 16022 admin@lefthand_vip getPerformanceStats interval=10000 output=XML'
tmpfile = '/root/scripts/voliops.txt'

def main():
   ret  =  subprocess.check_output(statcmd.split(' '))
   #print ret # For debug
   root = ET.fromstring(ret)
   
   es = root.findall(".//cluster[@name='" + lh_cluster + "']/counter[@name='ClusterIoTotal']")
   for e in es:
      totalio = e.attrib['value']
   
   es = root.findall(".//cluster[@name='" + lh_cluster + "']/counter[@name='ClusterIoReads']")
   for e in es:
      readio = e.attrib['value']
   
   es = root.findall(".//cluster[@name='" + lh_cluster + "']/counter[@name='ClusterIoWrites']")
   for e in es:
      writeio = e.attrib['value']
   
   f = open(tmpfile, 'w')
   #print datetime.now().strftime("%A, %d. %B %Y %I:%M%p") # For debug
   #print 'total,read,write'
   #print totalio + "," + readio + "," + writeio
   f.write('total,read,write\n' + totalio + ',' + readio + ',' + writeio)
   f.close()

if __name__ == '__main__':
   main()
