# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use warnings;
use base "y2logsstep";
use testapi;

# poo#11438
sub run() {
    # After mounting partitions leave only 100M available
    select_console('install-shell');
    my $avail = script_output "btrfs fi usage -m /mnt | awk '/Free/ {print \$3}' | cut -d'.' -f 1";
    assert_script_run "fallocate -l " . ($avail - 100) . "m /mnt/FILL_DISK_SPACE";
    select_console('installation');
}

1;
# vim: set sw=4 et:
