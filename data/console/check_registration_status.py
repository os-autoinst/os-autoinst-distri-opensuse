#!/usr/bin/env python
import sys
import json
import subprocess

# Read the distribution info
with open('/etc/os-release') as f:
    dist = {}
    for line in f:
        k,v = line.rstrip().split('=')
        v = v.strip('"')
        dist[k] = v

dist['BASE_VERSION'] = dist['VERSION_ID'].split('.')[0]
print("Current system: %(NAME)s %(VERSION_ID)s [base version: %(BASE_VERSION)s]" % dist)

cmd = ['SUSEConnect', '-s']
proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
stdout, stderr = proc.communicate()

if proc.returncode != 0:
    print("Error executing command: %s" % ' '.join(cmd))
    print("stderr: %s" % stderr)
    print("stdout: %s" % stdout)

# SUSEConnect status of every product (base product, extension or module),
# should has the same version with current system, either "Not Registered"
# or "Registered" products.
# Return the account of missing matched product
ret = 0
for prod in json.loads(stdout, encoding="utf-8"):
    prod['base_version'] = prod['version'].split('.')[0]
    prod['result'] = 'match'

    # Module version is not service pack specific
    if prod['identifier'].find('module') != -1:
        if dist['BASE_VERSION'] != prod['base_version']:
            prod['result'] = 'mismatch'
    else:
        if dist['VERSION_ID'] != prod['version']:
            # Live Patching is seen as Module before SLE12SP3, then seen as extension since SLE12SP3
            # So its version should equal the base product's base version before SLE12SP3, while equal 
            # the base product's version since SLE12SP3. 
            if dist['VERSION_ID'] >= '12.3':
                prod['result'] = 'mismatch'
            else:
                if dist['BASE_VERSION'] != prod['version']:
                   prod['result'] = 'mismatch'

    if prod['result'] == 'mismatch':
        ret += 1
    print("Product %(identifier)s with version %(version)s is %(status)s [%(result)s]" % prod)

sys.exit(ret)
