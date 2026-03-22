# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test toolbox command and container image availability
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base qw(opensusebasetest);
use testapi;
use serial_terminal qw(select_serial_terminal);

sub run {
    my ($self) = @_;

    select_serial_terminal();

    # Skip the test in multi-machine mode
    if (get_var('PARALLEL_WITH')) {
        record_info('SKIP', 'Skip test - Network is not up at this stage');
        $self->result('skip');
        return;
    }

    record_info('Toolbox Info', 'Verify toolbox script is installed');

    assert_script_run('which toolbox');
    assert_script_run('file -Ls $(which toolbox) | grep -iq "shell script"');

    record_info('Toolbox Run', 'Start toolbox, pull image, and exit cleanly');

    validate_script_output(
        'echo exit | toolbox',
        sub { m/Entering container/i },
        timeout => 240
    );

    record_info('Podman Verify', 'Verify the toolbox image was stored on the host');

    validate_script_output('podman images', sub { m/toolbox/i });
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
