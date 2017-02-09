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

sub run() {
    script_output '
      for port in 389 636 873 ; do
        yast2 firewall services add tcpport=$port udpport=$port zone=EXT
      done

      rcSuSEfirewall2 restart

      sed -i -e \'s|\(TFTP_DEFAULT_KERNEL_PARAMETERS.*$\)|\1 kiwidebug=1 |\' /usr/lib/SLEPOS/defaults
      sed -i -e \'s|vga=0x314|vga=0x317|\' /usr/lib/SLEPOS/defaults
      cat /usr/lib/SLEPOS/defaults
    ';

    type_string "posInitAdminserver 2>&1 | tee /dev/$serialdev\n";
    wait_serial "company name.*:"                                   and type_string get_var('ORGANIZATION') . "\n";
    wait_serial "2 letter abbreviation.*:"                          and type_string get_var('COUNTRY') . "\n";
    wait_serial "LDAP administrator password.*:"                    and type_string get_var('ADMINPASS') . "\n";
    wait_serial "password again.*:"                                 and type_string get_var('ADMINPASS') . "\n";
    wait_serial "Enable secure connection"                          and type_string get_var('SSL') . "\n";
    wait_serial "Please enter LDAP configuration database password" and type_string "\n";
    wait_serial "Recreate LDAP database?"                           and type_string "yes\n";
    wait_serial "Enable SUSE Manager integration.*"                 and type_string "no\n";
    wait_serial "Continue with configuration"                       and type_string "\n";
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

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
