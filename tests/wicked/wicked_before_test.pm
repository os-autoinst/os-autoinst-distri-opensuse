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

use base 'wickedbase';
use strict;
use testapi;
use utils 'systemctl';
use version_utils qw(is_sle sle_version_at_least);

sub run {
    my ($self) = @_;
    select_console('root-console');
    $self->write_journal('Preparation for wicked test');
    my $service = (is_sle && sle_version_at_least('15')) ? 'firewalld' : 'SuSEfirewall2';
    $self->write_journal('Stopping firewall and checking that network is up');
    systemctl("stop $service");
    systemctl('is-active network');
    systemctl('is-active wicked');
    assert_script_run('[ -z "$(coredumpctl -1 --no-pager --no-legend)" ]');
    $self->write_journal('Setting debug level for wicked logs');
    assert_script_run('sed -e "s/^WICKED_DEBUG=.*/WICKED_DEBUG=\"all\"/g" -i /etc/sysconfig/network/config');
    assert_script_run('sed -e "s/^WICKED_LOG_LEVEL=.*/WICKED_LOG_LEVEL=\"debug\"/g" -i /etc/sysconfig/network/config');
    assert_script_run('cat /etc/sysconfig/network/config');
    $self->write_journal('Remember clean system state');
    my $snapshot_number = script_output('snapper create -p -d "clean system"');
    set_var('BTRFS_SNAPSHOT_NUMBER', $snapshot_number);
}

sub test_flags {
    return {fatal => 1};
}

1;
