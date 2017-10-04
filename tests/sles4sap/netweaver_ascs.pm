# SUSE's SLES4SAP openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Checks NetWeaver's ASCS installation as performed by sles4sap/nw_ascs_install
# Requires: sles4sap/nw_ascs_install
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "x11test";
use strict;
use testapi;

sub run {
    my ($self) = @_;
    my $pscmd = "ps auxw | grep ASCS | grep -vw grep";
    $pscmd = "$pscmd | wc -l ; $pscmd";

    x11_start_program('xterm');
    assert_screen('xterm');

    # The SAP Admin was set in sles4sap/nw_ascs_install
    my $sapadmin = get_var('SAPADM');
    die "netweaver_ascs: coulnd't determine the SAP Administrator's username"
      unless ($sapadmin);

    # Allow SAP Admin user to inform status via $testapi::serialdev
    assert_script_sudo("chown $sapadmin /dev/$testapi::serialdev", 5);

    type_string "su - $sapadmin\n";
    type_string "$testapi::password\n" unless ($testapi::username eq 'root');

    assert_script_run("sapcontrol -nr 00 -function GetVersionInfo", 20);
    assert_screen('netweaver-version-info', 10);

    type_string "clear\n";
    assert_script_run("sapcontrol -nr 00 -function GetInstanceProperties | grep ^SAP", 20);
    assert_screen('netweaver-instance-properties', 10);

    type_string "clear\n";
    assert_script_run("sapcontrol -nr 00 -function Stop", 20);
    assert_screen('netweaver-stop-instance', 10);

    type_string "clear\n";
    assert_script_run("sapcontrol -nr 00 -function StopService", 20);
    assert_screen('netweaver-stop-service', 10);

    type_string "clear\n";
    type_string "$pscmd\n";
    check_screen('netweaver-service-started', 30);

    type_string "clear\n";
    assert_script_run("sapcontrol -nr 00 -function StartService QAD", 20);
    assert_screen('netweaver-start-service', 10);

    type_string "clear\n";
    type_string "$pscmd\n";
    assert_screen('netweaver-service-started', 20);

    type_string "clear\n";
    assert_script_run("sapcontrol -nr 00 -function Start", 20);
    assert_screen('netweaver-start-instance', 10);

    type_string "clear\n";
    type_string "$pscmd\n";
    assert_screen('netweaver-instance-started', 20);

    # Rollback changes to $testapi::serialdev and close the window
    type_string "exit\n";
    assert_script_sudo("chown $testapi::username /dev/$testapi::serialdev", 5);
    send_key 'alt-f4';
}

1;
# vim: set sw=4 et:
