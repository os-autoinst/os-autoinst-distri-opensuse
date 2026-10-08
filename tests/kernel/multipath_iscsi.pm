# SUSE's openQA tests
#
# Copyright 2023-2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Smoke test for multipath over iscsi
# - Install open-iscsi
# - Start iscsid and multipathd services and check status
# Maintainer: QE Kernel <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use package_utils 'install_package';
use iscsi;
use serial_terminal 'select_serial_terminal';

sub run {
    # Set default variables for iscsi iqn and target
    my $iqn = get_var("ISCSI_IQN", "iqn.2016-02.de.openqa");
    my $target = get_var("ISCSI_TARGET", "10.0.2.1");

    select_serial_terminal;

    # Check connectivity to target inside multimachine network (supportserver)
    ping_size_check($target);

    # Install iscsi and make sure multipath-tools are installed
    install_package('open-iscsi multipath-tools', trup_apply => 1);

    # Start isci and multipath services
    systemctl 'start iscsid';
    systemctl 'start multipathd';
    systemctl 'status multipathd';

    # Connect to iscsi server and check paths
    iscsi_discovery $target;
    iscsi_login $iqn, $target;
    my $times = 10;
    ($times-- && sleep 1) while (script_run('multipathd -k"show multipaths status" | grep active') && $times);
    die "multipath not ready even after waiting 10s" unless $times;
    assert_script_run("multipathd -k\"show multipaths status\"");
    # Connection cleanup
    iscsi_logout $iqn, $target;
}

1;

=head1 Description

Smoke test for multipath over iSCSI. The test installs C<open-iscsi> and
C<multipath-tools>, starts C<iscsid> and C<multipathd>, then discovers and
logs in to the iSCSI target. It waits up to 10 seconds for C<multipathd> to
report an active multipath device, then logs out.

The iSCSI target has to be provided by another machine on the multimachine
network, usually a supportserver.

=head1 Configuration

=head2 ISCSI_TARGET

IP address of the iSCSI target. Defaults to C<10.0.2.1>.

=head2 ISCSI_IQN

IQN of the iSCSI target. Defaults to C<iqn.2016-02.de.openqa>.

=cut
