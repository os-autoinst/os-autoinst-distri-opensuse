# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic SLEPOS test
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "basetest";
use strict;
use warnings;
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

    type_string "posInitBranchserver 2>&1 | tee /dev/$serialdev\n";
    wait_serial "Please, select initialization mode:" and type_string "1\n" unless get_var('SLEPOS') =~ /^combo/;
    wait_serial "company name.*:"                     and type_string get_var('ORGANIZATION') . "\n";
    wait_serial "2 letter abbreviation.*:"            and type_string get_var('COUNTRY') . "\n";
    wait_serial "name of organizational unit.*:"      and type_string get_var('ORGANIZATIONAL_UNIT') . "\n";
    wait_serial "branch name.*:"                      and type_string get_var('LOCATION') . "\n";


    wait_serial "name or IP of the AdminServer.*:" and type_string get_var('ADMINSERVER_ADDR') . "\n";
    wait_serial "Branch Server access password:"   and type_string get_var('USER_PASSWORD') . "\n";

    wait_serial "Is Admin Server LDAP fingerprint correct" and type_string "Y\n" if get_var('SSL') eq 'yes';

    wait_serial "Use Branch LDAP on localhost" and type_string "Y\n" unless get_var('SLEPOS') =~ /^combo/;
    wait_serial "Enable secure connection"     and type_string "yes\n" if get_var('SSL') eq 'yes' && get_var('SLEPOS') !~ /^combo/;
    wait_serial "Continue with configuration"  and type_string "\n";
    wait_serial "configuration successful";
}

sub test_flags {
    return {fatal => 1};
}

1;
