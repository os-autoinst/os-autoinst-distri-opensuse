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
      for port in 389 636 873 ; do
        yast2 firewall services add tcpport=$port udpport=$port zone=EXT
      done

      rcSuSEfirewall2 restart

      sed -i -e \'s|\(TFTP_DEFAULT_KERNEL_PARAMETERS.*$\)|\1 kiwidebug=1 |\' /usr/lib/SLEPOS/defaults
      sed -i -e \'s|vga=0x314|vga=0x317|\' /usr/lib/SLEPOS/defaults
      cat /usr/lib/SLEPOS/defaults
    ';

    enter_cmd "posInitAdminserver 2>&1 | tee /dev/$serialdev";
    wait_serial "company name.*:" and enter_cmd get_var('ORGANIZATION') . "";
    wait_serial "2 letter abbreviation.*:" and enter_cmd get_var('COUNTRY') . "";
    wait_serial "LDAP administrator password.*:" and enter_cmd get_var('ADMINPASS') . "";
    wait_serial "password again.*:" and enter_cmd get_var('ADMINPASS') . "";
    wait_serial "Enable secure connection" and enter_cmd get_var('SSL') . "";
    wait_serial "Please enter LDAP configuration database password" and send_key 'ret';
    wait_serial "Recreate LDAP database?" and enter_cmd "yes";
    wait_serial "Enable SUSE Manager integration.*" and enter_cmd "no";
    wait_serial "Continue with configuration" and send_key 'ret';
    wait_serial "configuration successful";

    script_output "
      set -x -e
      export POS_FORCE_VERBOSITY=info
      posAdmin --validate 2>&1 | tee /dev/$serialdev
      curl " . autoinst_url . "/data/slepos/slepos_ldap_data.xml > slepos_ldap_data.xml
      posAdmin --import --type XML --file slepos_ldap_data.xml
      posAdmin --validate
    ";
    mutex_create("adminserver_configured");
}

sub test_flags {
    return {fatal => 1};
}

1;
