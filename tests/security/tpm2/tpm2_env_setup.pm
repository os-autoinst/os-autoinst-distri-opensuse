# Copyright 2020-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: TPM2 test environment prepare
#          Install required packages and create user, start the abrmd service
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#64899, poo#103143, poo#105732, poo#107908, tc#1742297, tc#1742298

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use utils;
use power_action_utils 'power_action';
use version_utils 'is_sle';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Install the tpm2.0 related packages
    # and then start the TPM2 Access Broker & Resource Manager
    quit_packagekit;
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
        # The package is only present on SLE >= 15.sp3, so for the previous versions
        # we have to create the user manually.
        if (is_sle('>=15-SP3')) {
            record_info("bsc#1193305, the home directory of user $tss_user is not created, install 'system-user-tss' as a workaround");
            zypper_call("in system-user-tss");
        } else {
            record_info("Due to bsc#1193305, the home directory of user $tss_user must be manually created.");
            assert_script_run("mkdir $tss_home && chmod 0750 $tss_home");
            assert_script_run("chown $tss_user:$tss_user $tss_home");
        }
    }

    # We can use swtpm device during our test with qemu backend to simulate "real"
    # tpm2 device, and we can also user TPM emulator.
    # As we use TPM emulator, we should do some modification for tpm2-abrmd service
    # and make it connect to "--tcti=libtss2-tcti-mssim.so"
    if (get_var('QEMUTPM', '') ne 'instance' || get_var('QEMUTPM_VER', '') ne '2.0') {
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

        # Start the emulator
        my $server = script_output("ls /usr/*/ibmtss/tpm_server | tail -1");
        die "missing tpm_server path\n" if ($server eq '');
        assert_script_run("su -s /bin/bash - $tss_user -c '$server &'");
    }

    # Restart the tpm2-abrmd service
    assert_script_run("systemctl enable tpm2-abrmd");
    assert_script_run("systemctl restart tpm2-abrmd");
    assert_script_run("systemctl is-active tpm2-abrmd");
}

# Since all tpm2.0 cases start after this case, mark it a milestone one
sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
