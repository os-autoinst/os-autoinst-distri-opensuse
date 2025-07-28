# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic SLEPOS test
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "basetest";
use testapi;
use utils;
use lockapi;

sub run {
    script_output '
      sed -i -e \'s|^FW_ROUTE=.*|FW_ROUTE="yes"|\' -e \'s|^FW_MASQUERADE=.*|FW_MASQUERADE="yes"|\' -e \'s|^FW_DEV_INT=.*|FW_DEV_INT="eth1"|\'  -e \'s|^FW_DEV_EXT=.*|FW_DEV_EXT="any eth0"|\' /etc/sysconfig/SuSEfirewall2
      for port in 69 53 67 21 30000:30400 ; do
        yast2 firewall services add tcpport=$port udpport=$port zone=EXT
      done
      rcSuSEfirewall2 restart

      sed -i -e \'s|\(TFTP_DEFAULT_KERNEL_PARAMETERS.*$\)|\1 kiwidebug=1 |\' /usr/lib/SLEPOS/defaults
      sed -i -e \'s|vga=0x314|vga=0x317|\' /usr/lib/SLEPOS/defaults
      cat /usr/lib/SLEPOS/defaults
      ip a
    ';

    #wait for adminserver
    mutex_lock("adminserver_configured");
    mutex_unlock("adminserver_configured");

    enter_cmd "posInitBranchserver 2>&1 | tee /dev/$serialdev";
    wait_serial "Please, select initialization mode:" and enter_cmd "1" unless get_var('SLEPOS') =~ /^combo/;
    wait_serial "company name.*:" and enter_cmd get_var('ORGANIZATION') . "";
    wait_serial "2 letter abbreviation.*:" and enter_cmd get_var('COUNTRY') . "";
    wait_serial "name of organizational unit.*:" and enter_cmd get_var('ORGANIZATIONAL_UNIT') . "";
    wait_serial "branch name.*:" and enter_cmd get_var('LOCATION') . "";


    wait_serial "name or IP of the AdminServer.*:" and enter_cmd get_var('ADMINSERVER_ADDR') . "";
    wait_serial "Branch Server access password:" and enter_cmd get_var('USER_PASSWORD') . "";

    wait_serial "Is Admin Server LDAP fingerprint correct" and enter_cmd "Y" if get_var('SSL') eq 'yes';

    wait_serial "Use Branch LDAP on localhost" and enter_cmd "Y" unless get_var('SLEPOS') =~ /^combo/;
    wait_serial "Enable secure connection" and enter_cmd "yes" if get_var('SSL') eq 'yes' && get_var('SLEPOS') !~ /^combo/;
    wait_serial "Continue with configuration" and send_key 'ret';
    wait_serial "configuration successful";
}

sub test_flags {
    return {fatal => 1};
}

1;
