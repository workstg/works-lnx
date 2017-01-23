#!/usr/bin/python
 
import sys
import json
import pycurl
from io import BytesIO
 
sfuser = 'admin'
sfpass = 'password'
api_endpoint = 'https://192.168.0.1/json-rpc/8.0'
api_params = {"method": "GetClusterCapacity", "params": {}, "id": "1" }
tmpfile = '/var/tmp/sfiops.txt'
 
def main():
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
      result = json.loads(response.getvalue())
 
   f = open(tmpfile, 'w')
   f.write('current,average,peak\n' + str(result['result']['clusterCapacity']['currentIOPS']) + ',' + str(result['result']['clusterCapacity']['averageIOPS']) + ',' + str(result['result']['clusterCapacity']['peakIOPS']))
 
   #print('Average IOPS {}'.format(result['result']['clusterCapacity']['averageIOPS']))
   #print('Current IOPS {}'.format(result['result']['clusterCapacity']['currentIOPS']))
   #print('Peak IOPS {}'.format(result['result']['clusterCapacity']['peakIOPS']))
   f.close()
 
if __name__ == "__main__":
   main()
 
sys.exit(0)