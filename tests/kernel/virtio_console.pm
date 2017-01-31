# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Stress test the virtio serial terminal for debugging OpenQA and QEMU
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;
use utils;

my $multiline_script = <<'FIN.';
for i in $(seq %d); do
  sleep 0.$i;
  head -n 1 /dev/urandom | base64;
done
FIN.

sub run {
    my $self = shift;
    my $m    = get_var('VIRTIO_CONSOLE_TEST_M') || 10;
    my $n    = get_var('VIRTIO_CONSOLE_TEST_N') || 10;
    $self->wait_boot;

    select_console('root-virtio-terminal');
    for my $i (0 .. $m) {
        script_run("echo '#$i'");
        script_output(sprintf($multiline_script, $n));
    }
}

1;

=head1 Configuration

=head2 Example

BOOT_HDD_IMAGE=1
DESKTOP=textmode
HDD_1=SLES-%VERSION%-%ARCH%-minimal_with_sdk_installed.qcow2
VIRTIO_CONSOLE_TEST=1

=head2 VIRTIO_CONSOLE_TEST

Just activates the test. For this test to stress the system `m x n > 10000`
where `m` is the outer loop and `n` the inner loop.

=head2 VIRTIO_CONSOLE_M

The number of times the host loops.

=head2 VIRTIO_CONSOLE_N

The number of times the guest loops.

=cut
