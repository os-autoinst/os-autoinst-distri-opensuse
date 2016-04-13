# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "basetest";
use testapi;
use utils;
use lockapi;

sub run() {
    my $self = shift;

    # FIXME: configure fw
    assert_script_run "rcSuSEfirewall2 stop";

    #wait for adminserver
    mutex_lock("adminserver_configured");
    mutex_unlock("adminserver_configured");

    assert_script_run "ip a";

    script_output '
      set -x -e
      sed -i -e \'s|\(TFTP_DEFAULT_KERNEL_PARAMETERS.*$\)|\1 kiwidebug=1 |\' /usr/lib/SLEPOS/defaults
    ';

    type_string "posInitBranchserver 2>&1 | tee /dev/$serialdev\n";
    wait_serial "Please, select initialization mode:" and type_string "1\n";
    wait_serial "company name.*:"                     and type_string get_var('ORGANIZATION') . "\n";
    wait_serial "2 letter abbreviation.*:"            and type_string get_var('COUNTRY') . "\n";
    wait_serial "name of organizational unit.*:"      and type_string get_var('ORGANIZATIONAL_UNIT') . "\n";
    wait_serial "branch name.*:"                      and type_string get_var('LOCATION') . "\n";


    wait_serial "name or IP of the AdminServer.*:" and type_string get_var('ADMINSERVER_ADDR') . "\n";
    wait_serial "Branch Server access password:"   and type_string get_var('USER_PASSWORD') . "\n";

    wait_serial "Is Admin Server LDAP fingerprint correct" and type_string "Y\n" if get_var('SSL') eq 'yes';

    wait_serial "Use Branch LDAP on localhost" and type_string "Y\n";
    wait_serial "Enable secure connection"     and type_string "yes\n" if get_var('SSL') eq 'yes';
    wait_serial "Continue with configuration"  and type_string "\n";
    wait_serial "configuration successful";

}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
