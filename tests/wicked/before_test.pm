# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
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
use serial_terminal 'select_virtio_console';

sub run {
    my ($self) = @_;
    select_virtio_console();
    my $enable_command_logging = 'export PROMPT_COMMAND=\'logger -t openQA_CMD "$(history 1 | sed "s/^[ ]*[0-9]\+[ ]*//")"\'';
    assert_script_run("echo \"$enable_command_logging\" >> /root/.bashrc");
    assert_script_run($enable_command_logging);
    systemctl("stop " . opensusebasetest::firewall);
    systemctl("disable " . opensusebasetest::firewall);
    record_info('INFO', 'Checking that network is up');
    systemctl('is-active network');
    systemctl('is-active wicked');
    assert_script_run('[ -z "$(coredumpctl -1 --no-pager --no-legend)" ]');
    record_info('INFO', 'Setting debug level for wicked logs');
    assert_script_run('sed -e "s/^WICKED_DEBUG=.*/WICKED_DEBUG=\"all\"/g" -i /etc/sysconfig/network/config');
    assert_script_run('sed -e "s/^WICKED_LOG_LEVEL=.*/WICKED_LOG_LEVEL=\"debug\"/g" -i /etc/sysconfig/network/config');
    assert_script_run('cat /etc/sysconfig/network/config');
    #preparing directories for holding config files
    assert_script_run('mkdir -p /data/{static_address,dynamic_address}');
    #download script for check interface status
    $self->get_from_data('wicked/check_interfaces.sh', '/data/check_interfaces.sh', executable => 1) if check_var('WICKED', 'basic');
    if (check_var('WICKED', 'advanced')) {
        $self->setup_static_network($self->get_ip(is_wicked_ref => check_var('IS_WICKED_REF', 1), type => 'host'));
    }
    $self->get_from_data('wicked/ifbind.sh', '/bin/ifbind.sh', executable => 1);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

