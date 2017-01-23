#!/usr/bin/python

import sys
import time
import json
import pycurl
from io import BytesIO

sfuser = 'admin'
sfpass = 'password'
api_endpoint = 'https://192.168.0.1/json-rpc/8.0'
api_params = {"method": "GetClusterStats", "params": {}, "id": "1" }
delta = 30
tmpfile = '/var/tmp/sfiops.txt'

def main():
   data1 = get_clusterstats()
   time.sleep(delta)
   data2 = get_clusterstats()

   
   rio = (data2['result']['clusterStats']['readOps'] - data1['result']['clusterStats']['readOps']) / delta
   wio = (data2['result']['clusterStats']['writeOps'] - data1['result']['clusterStats']['writeOps']) / delta
   tio = rio + wio
   f = open(tmpfile, 'w')
   f.write('total,read,write\n' + str(tio) + ',' + str(rio) + ',' + str(wio))

   #print('Total IOPS {}'.format(tio))
   #print('Read IOPS {}'.format(rio))
   #print('Write IOPS {}'.format(wio))
   f.close()

def get_clusterstats():
   response = BytesIO()

   conn = pycurl.Curl()
   conn.setopt(pycurl.URL, api_endpoint)
   conn.setopt(pycurl.SSL_VERIFYPEER, False)
   conn.setopt(pycurl.SSL_VERIFYHOST, False)
   conn.setopt(pycurl.HTTPAUTH, pycurl.HTTPAUTH_BASIC)
   conn.setopt(pycurl.USERPWD, "%s:%s" % (sfuser, sfpass))
   conn.setopt(pycurl.POST, 1)
   conn.setopt(pycurl.HTTPHEADER, ['Accept: application/json', 'Content-Type: application/json'])
   conn.setopt(pycurl.POSTFIELDS, json.dumps(api_params))
   conn.setopt(pycurl.WRITEFUNCTION, response.write)
   conn.perform()

   http_code = conn.getinfo(pycurl.HTTP_CODE)
   if not http_code is 200:
      sys.exit(1)
   else:
      return json.loads(response.getvalue())

if __name__ == "__main__":
   main()

sys.exit(0)
