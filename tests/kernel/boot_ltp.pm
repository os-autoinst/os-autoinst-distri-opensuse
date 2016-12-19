# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Waits for the guest to boot and sets some variables for LTP
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;

sub run {
    my $self = shift;
    $self->wait_boot;

    if (get_var('VIRTIO_CONSOLE')) {
        select_console('root-virtio-terminal');
    }
    else {
        select_console('root-console');
    }

    assert_script_run('export LTPROOT=/opt/ltp; export TMPDIR=/tmp PATH=$LTPROOT/testcases/bin:$PATH');
}

sub test_flags {
    return {
        fatal     => 1,
        milestone => 1
    };
}

1;

=head1 Configuration

See run_ltp.pm.

=cut
