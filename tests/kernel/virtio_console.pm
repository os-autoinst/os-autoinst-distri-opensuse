# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Log into and run a script on a virtio serial terminal
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;
use utils;

my $multiline_script = <<'FIN.';
echo line one
echo line two
echo line three
FIN.

sub run {
    my $self = shift;
    $self->wait_boot;

    select_console('root-virtio-terminal');
    my $output = script_output($multiline_script);
}

1;

=head1 Configuration

=head2 Example

BOOT_HDD_IMAGE=1
DESKTOP=textmode
HDD_1=SLES-%VERSION%-%ARCH%-minimal_with_sdk_installed.qcow2
VIRTIO_CONSOLE_TEST=1

=head2 VIRTIO_CONSOLE_TEST

Just activates the test

=cut
