# Yomi's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install QEMU and launch the inner minion
# Maintainer: Alberto Planas <aplanas@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;

sub install_qemu {
    zypper_call 'in qemu';
    zypper_call 'in qemu-x86';
    zypper_call 'in qemu-tools';
    zypper_call 'in ovmf';
}

sub assert_script_run_qemu {
    my ($command) = @_;
    assert_script_run "ssh -oStrictHostKeyChecking=no -p 10022 localhost '$command'";
}

sub start_qemu {
    my ($scenario) = @_;

    assert_script_run 'qemu-img create -f qcow2 hda.qcow2 24G';

    assert_script_run 'curl -O ' . autoinst_url . '/data/yomi/run_qemu';
    assert_script_run 'chmod a+x run_qemu';
    type_string "nohup ./run_qemu $scenario 2>&1 | tee -i /dev/$serialdev &\n";

    wait_serial('localhost login:', 360) || die 'login not found, QEMU not launched';

    script_run 'reset && clear';
}

sub start_minion {
    # Remove all the keys
    assert_script_run 'salt-key -yD';

    assert_script_run_qemu 'echo "master: 10.0.2.2" > /etc/salt/minion.d/master.conf';
    assert_script_run_qemu 'echo minion > /etc/salt/minion_id';
    assert_script_run_qemu '> /var/log/salt/minion';
    assert_script_run_qemu 'systemctl restart salt-minion.service';

    # Give some time for the minion to connect
    sleep 20;

    # Only list the keys, as will be accepted by autosign
    assert_script_run 'salt-key -L';

    # Validate the connection to the minion
    script_run "salt -l debug minion test.ping";
    assert_screen 'yomi-test-ping', 120;
}

sub run {
    select_console 'root-console';

    # Get the name of the scenario from the test name
    my $scenario = get_var('TEST', 'simple');

    install_qemu;
    start_qemu $scenario;
    start_minion;
}

sub test_flags {
    return {fatal => 1};
}

1;
