# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: TPM2 test environment prepare
#          Install required packages and create user, start the abrmd service
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#64899, poo#103143, tc#1742297, tc#1742298

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use utils 'zypper_call';
use power_action_utils 'power_action';
use version_utils 'is_sle';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Install the tpm2.0 related packages
    # and then start the TPM2 Access Broker & Resource Manager
    zypper_call("in expect ibmswtpm2 tpm2.0-abrmd tpm2.0-abrmd-devel openssl tpm2-0-tss tpm2-tss-engine tpm2.0-tools");

    # Add user tss, tss is the default user to start tpm2.0 service
    # However, a daemon user may be created as well during tss related
    # packages installation, we can re-use it then with some changes.

    my $tss_user = "tss";
    my $tss_home = script_output("cat /etc/passwd | grep $tss_user | cut -d : -f6");

    # The home directory of the daemon user 'tss' may not be created on SLE,
    # However, it is there on TW due to package 'system-user-tss' installation
    # by default in newer releases, we can workaroud it by install this package
    # manually
    if (script_run("ls $tss_home") != 0) {
        record_soft_failure("bsc#1193305, the home directory of user $tss_user is not created, install 'system-user-tss' as a workaround");
        zypper_call("in system-user-tss");
    }

    # As we use TPM emulator, we should do some modification for tpm2-abrmd service
    # and make it connect to "--tcti=libtss2-tcti-mssim.so"
    assert_script_run("mkdir /etc/systemd/system/tpm2-abrmd.service.d");
    assert_script_run(
        "echo \"\$(cat <<EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/tpm2-abrmd --tcti=libtss2-tcti-mssim.so

[Unit]
ConditionPathExistsGlob=
EOF
        )\" > /etc/systemd/system/tpm2-abrmd.service.d/emulator.conf"
    );
    assert_script_run("systemctl daemon-reload");
    assert_script_run("systemctl enable tpm2-abrmd");

    # Start the emulator
    my $server = script_output("ls /usr/*/ibmtss/tpm_server | tail -1");
    die "missing tpm_server path\n" if ($server eq '');
    assert_script_run("su -s /bin/bash - $tss_user -c '$server &'");

    # Restart the tpm2-abrmd service
    assert_script_run("systemctl restart tpm2-abrmd");
    assert_script_run("systemctl is-active tpm2-abrmd");
}

# Since all tpm2.0 cases start after this case, mark it a milestone one
sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
