# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test the google-guest-agent package
# Maintainer: qa-c team <qa-c@suse.de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal();

    # Service should be running out of the box
    assert_script_run('systemctl status google-guest-agent');

    # Override network config and confirm that it is effective
    assert_script_run(q(echo -e '[InstanceSetup]\nnetwork_enabled = false' > /etc/default/instance_configs.cfg));
    assert_script_run('sudo systemctl restart google-guest-agent');
    validate_script_output('sudo journalctl -u google-guest-agent', qr/network_enabled is false, skipping setup actions/);
}

1;
