#!/usr/bin/env python

'''
Call PAM service to test user credentials.
Return status 0 on success, 1 on error.
Invocation: <service_name> <user_name> <plain_password>
'''

import sys, PAM

if len(sys.argv) != 1 + 3:
	sys.exit(1)

(_, service, user, password) = sys.argv

def pamconv(auth, qlist):
	resp = []
	for (query,hint) in qlist:
		if hint == PAM.PAM_PROMPT_ECHO_ON or hint == PAM.PAM_PROMPT_ECHO_OFF:
			resp.append((password, 0))
		elif hint == PAM.PAM_PROMPT_ERROR_MSG or hint == PAM.PAM_PROMPT_TEXT_INFO:
			print query
			resp.append(('', 0));
		else:
			return None
	return resp

pam = PAM.pam()
pam.start(service)
pam.set_item(PAM.PAM_USER, user)
pam.set_item(PAM.PAM_CONV, pamconv)

try:
	pam.authenticate()
	pam.acct_mgmt()
except Exception as e:
	print(e)
	sys.exit(1)

