# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: display checksums for contents of /boot files.
#          It focuses on vmlinu*, initrd*, config*, symvers* and sysctl*
#          files in /boot
# Maintainer: Alvaro Carvajal <acarvajal@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    my $checksums = script_output "md5sum /boot/vmlinu* /boot/initrd* /boot/config* /boot/symvers* /boot/sysctl*";
    record_info "/boot checksums", $checksums;
}

1;
