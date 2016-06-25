# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;

# Btrfs understands short commands like "btrfs d st"
# Compare autocompleted commands as strings
sub compare_commands {
    for my $i (1 .. 2) {
        type_string shift;
        type_string "\" > /tmp/command$i";
        send_key "home";
        type_string "echo \"\n";
    }
    assert_script_run "diff /tmp/command\[12\]";
}

sub run() {
    select_console 'root-console';

    compare_commands("btrfs device stats ",                  "btrfs d\tst\t");
    compare_commands("btrfs subvolume get-default ",         "btrfs su\tg\t");
    compare_commands("btrfs filesystem usage ",              "btrfs fi\tu\t");
    compare_commands("btrfs inspect-internal min-dev-size ", "btrfs i\tm\t");

    # Check loading of complete function
    assert_script_run "complete | grep '_btrfs btrfs'";

    # Getting minimum device size is working and returning at least 1MB
    assert_script_run "btrfs inspect-internal min-dev-size / | grep -E '^[0-9]{6,} bytes'";
}

1;
# vim: set sw=4 et:
