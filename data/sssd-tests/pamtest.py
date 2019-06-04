#!/usr/bin/env python3

'''
Call PAM service to test user credentials.
Return status 0 on success, 1 on error.
Invocation: <service_name> <user_name> <plain_password>
'''

import sys

usePAM = True
try:
	import PAM as pam
except ImportError:

	usePAM = False
	import pam

if usePAM:
	def pamconv(auth, qlist):
		resp = []
		for (query,hint) in qlist:
			if hint == pam.PAM_PROMPT_ECHO_ON or hint == pam.PAM_PROMPT_ECHO_OFF:
				resp.append((password, 0))
			elif hint == pam.PAM_PROMPT_ERROR_MSG or hint == pam.PAM_PROMPT_TEXT_INFO:
				print(query)
				resp.append(('', 0));
			else:
				return None
		return resp

if len(sys.argv) != 1 + 3:
	sys.exit(1)

(_, service, user, password) = sys.argv

p = pam.pam()

if usePAM:
	p.start(service)
	p.set_item(pam.PAM_USER, user)
	p.set_item(pam.PAM_CONV, pamconv)
	try:
		p.authenticate()
		p.acct_mgmt()
	except Exception as e:
		print(e)
		sys.exit(1)
else:
	try:
		ret=p.authenticate(user, password, service)
	except Exception as e:
		print(e)
		sys.exit(1)
	if ret: sys.exit(0)
	else: sys.exit(1)

