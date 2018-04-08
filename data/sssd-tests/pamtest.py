#!/usr/bin/env python3

'''
Call PAM service to test user credentials.
Return status 0 on success, 1 on error.
Invocation: <service_name> <user_name> <plain_password>
'''

import sys, pam

if len(sys.argv) != 1 + 3:
	sys.exit(1)

(_, service, user, password) = sys.argv

p = pam.pam()
try:
	ret=p.authenticate(user, password, service)
except Exception as e:
	print(e)
	sys.exit(1)
if ret: sys.exit(0)
else: sys.exit(1)

