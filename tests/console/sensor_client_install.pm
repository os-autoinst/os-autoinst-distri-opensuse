use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils 'zypper_call';
use version_utils 'is_sle';

sub run {
    select_serial_terminal;

    zypper_call 'ar -p 90 -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/Velociraptor/SLE_15_SP4/ sensor';
    #   zypper_call "--gpg-auto-import-keys ref";
    zypper_call "se velociraptor-client";
    assert_script_run 'sleep 10';
    zypper_call "in velociraptor-client";

    assert_script_run 'sleep 10';
    assert_script_run 'systemctl enable velociraptor-client.service';
    assert_script_run 'systemctl start velociraptor-client.service';
    assert_script_run 'systemctl status velociraptor-client';
    assert_script_run 'sleep 10';
    #assert_script_run '';

    #assert_script_run 'kill $!';
    #assert_script_run 'cd -';
}

1;

