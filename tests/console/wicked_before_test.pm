# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Do basic checks to make sure system is ready for wicked testing
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils qw(systemctl setup_static_network);
use mm_network;

sub run {
    my ($self) = @_;
    select_console('root-console');
    assert_script_run "rcSuSEfirewall2 stop";
    systemctl('is-active network');
    systemctl('is-active wicked');
    assert_script_run('[ -z "$(coredumpctl -1 --no-pager --no-legend)" ]');
    assert_script_run('sed -e "s/^WICKED_DEBUG=.*/WICKED_DEBUG=\"all\"/g" -i /etc/sysconfig/network/config');
    assert_script_run('sed -e "s/^WICKED_LOG_LEVEL=.*/WICKED_LOG_LEVEL=\"debug\"/g" -i /etc/sysconfig/network/config');
    assert_script_run('cat /etc/sysconfig/network/config');
    my %ip = (
        RISKY_REF => '10.0.2.10/15',
        RISKY_SUT => '10.0.2.11/15',
    );
    $self->setup_static_network($ip{get_required_var('WICKED')});
    my $snapshot_number = script_output('snapper create -p -d "clean system"');
    set_var('BTRFS_SNAPSHOT_NUMBER', $snapshot_number);
}

1;
