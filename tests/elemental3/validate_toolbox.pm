# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test toolbox command and container image availability
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base qw(opensusebasetest);
use testapi;
use serial_terminal qw(select_serial_terminal);

sub run {
    select_serial_terminal();

    record_info('Toolbox Info', 'Verify toolbox script is installed');

    assert_script_run('which toolbox');
    assert_script_run('file $(which toolbox) | grep -i "shell script"');

    record_info('Toolbox Run', 'Start toolbox, pull image, and exit cleanly');

    validate_script_output(
        'echo exit | toolbox',
        sub { m/Entering container/i },
        timeout => 240
    );

    record_info('Podman Verify', 'Verify the toolbox image was stored on the host');

    validate_script_output('podman images', sub { m/toolbox/i });
}

1;
