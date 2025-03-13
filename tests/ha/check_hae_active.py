# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check that SUT has the HA Extension Enabled. If it's not, soft fail and work around
# Maintainer: qe-sap@suse.com

from testapi import *
import json

perl.require("registration")
perl.require("serial_terminal")
perl.require("utils")
perl.require("suseconnect_register")

def check_suseconnect(self):
    '''
    Check that SUT has suseconnect-ng installed. Install it if it's not there
    '''
    no_suseconnect = int(script_run("which SUSEConnect"))
    if (no_suseconnect):
        record_soft_failure("bsc#1238913 - SUSEConnect is not installed by default")
        perl.utils.zypper_call("in suseconnect-ng")

def check_product_registration(self):
    '''
    Check SUT is correctly registered to the SCC proxy. Re-register if it's not registered to
    the proxy, if it's not registered or if it's missing /etc/SUSEConnect
    '''
    # Retval 0 means file exists
    etc_suseconnect_exists = (int(script_run("test -f /etc/SUSEConnect")) == 0)
    scc_proxy_reg = False
    scc_url = get_var("SCC_URL", f"http://all-{get_required_var('BUILD')}.proxy.scc.suse.de")

    if (etc_suseconnect_exists):
        suseconnect_config = script_output("cat /etc/SUSEConnect")
        record_info("/etc/SUSEConnect", suseconnect_config)
        scc_proxy_reg = any([scc_url in _ for _ in suseconnect_config.split("\n")])

    is_registered = any([_["status"] == "Registered" for _ in json.loads(script_output("SUSEConnect --status"))])
    
    if (not(etc_suseconnect_exists and is_registered and scc_proxy_reg)):
        if (not etc_suseconnect_exists):
            record_soft_failure("bsc#1239316 - Missing /etc/SUSEConnect config file")

        if (not scc_proxy_reg):
            record_info('Softfail', "Not registered to the SCC proxy", "result", "softfail")

        perl.registration.cleanup_registration()
        perl.suseconnect_register.suseconnect_registration()

def check_ha_registered(self):
    '''
    Check the HA Extension is active. Activate it is it's not
    '''
    ha_registered = any([(product["identifier"] == "sle-ha" and product["subscription_status"] == "ACTIVE")
                         for product in json.loads(script_output("SUSEConnect --status"))])

    if (not ha_registered):
        record_soft_failure("jsc#TEAM-10163 - HA Extension not active. Activating it")
        perl.registration.register_addons_cmd()
        perl.utils.zypper_call("lr -u")

def run(self):
    perl.serial_terminal.select_serial_terminal()

    self.check_suseconnect()
    self.check_product_registration()
    self.check_ha_registered()

    # At this time SUT should be registered. The following commands are only for information purposes
    record_info("SCC Status", script_output("SUSEConnect --status"))
    record_info("SCC Extensions", script_output("SUSEConnect --list-extensions"))

    record_info("ha_sles", "Installing 'ha_sles' pattern")
    perl.utils.zypper_call("in -t pattern ha_sles")

def test_flags(self):
    return {'fatal': 1, 'milestone': 1}

