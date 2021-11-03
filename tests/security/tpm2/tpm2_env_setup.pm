# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: TPM2 test environment prepare
#          Install required packages and create user, start the abrmd service
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#64899, tc#1742297, tc#1742298

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

    # Add user tss, tss is the default user to start tpm2.0 service
    my $user = "tss";
    my $passwd = "susetesting";
    assert_script_run "useradd -d /home/$user -m $user";
    assert_script_run "echo $user:$passwd | chpasswd";

    # Install the tpm2.0 related packages
    # and then start the TPM2 Access Broker & Resource Manager
    zypper_call "in expect ibmswtpm2 tpm2.0-abrmd tpm2.0-abrmd-devel openssl tpm2-0-tss tpm2-tss-engine tpm2.0-tools";

    # As we use TPM emulator, we should do some modification for tpm2-abrmd service
    # and make it connect to "--tcti=libtss2-tcti-mssim.so"
    assert_script_run "mkdir /etc/systemd/system/tpm2-abrmd.service.d";
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
    assert_script_run "systemctl daemon-reload";
    assert_script_run "systemctl enable tpm2-abrmd";

    # Reboot the node to make the changes take effect
    power_action('reboot', textmode => 1);
    $self->wait_boot(textmode => 1);
    $self->select_serial_terminal;

    # Start the emulator
    my $server = script_output('ls /usr/*/ibmtss/tpm_server | tail -1');
    die 'missing tpm_server path\n' if ($server eq '');
    assert_script_run "su - tss -c '$server &'";

    # Restart the tpm2-abrmd service
    assert_script_run "systemctl restart tpm2-abrmd";
    assert_script_run "systemctl is-active tpm2-abrmd";
}

# Since all tpm2.0 cases start after this case, mark it a milestone one
sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
