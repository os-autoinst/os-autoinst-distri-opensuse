# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";
use testapi;
use utils;
use autotest;

sub run() {
    for my $i (1 .. 3) {
        type_string "crm status\n";
        assert_screen 'cluster-status';
        clear_console;
        send_key 'ctrl-pgdn';
    }
}

1;
