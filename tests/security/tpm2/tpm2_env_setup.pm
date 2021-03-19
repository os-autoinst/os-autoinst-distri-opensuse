# Copyright (C) 2020-2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
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
use power_action_utils "power_action";

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Add user tss, tss is the default user to start tpm2.0 service
    my $user   = "tss";
    my $passwd = "susetesting";
    assert_script_run "useradd -d /home/$user -m $user";
    assert_script_run "echo $user:$passwd | chpasswd";

    # Install the tpm2.0 related packages
    # and then start the TPM2 Access Broker & Resource Manager
    zypper_call "in ibmswtpm2 tpm2.0-abrmd tpm2.0-abrmd-devel openssl tpm2-0-tss tpm2-tss-engine tpm2.0-tools";

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
    assert_script_run "su - tss -c '/usr/lib/ibmtss/tpm_server&'";

    # Start the tpm2-abrmd service
    assert_script_run "systemctl start tpm2-abrmd";
    assert_script_run "systemctl is-active tpm2-abrmd";
}

# Since all tpm2.0 cases start after this case, mark it a milestone one
sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
