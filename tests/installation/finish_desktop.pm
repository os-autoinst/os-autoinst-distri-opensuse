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
use strict;

# using this as base class means only run when an install is needed
sub run() {
    my $self = shift;

    # live may take ages to boot
    my $timeout = 600;
    assert_screen "generic-desktop", $timeout;

    ## duplicated from second stage, combine!
    if (check_var('DESKTOP', 'kde')) {
        send_key "esc";
        assert_screen "generic-desktop", 25;
    }
}

sub test_flags() {
    return {fatal => 1};
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_logs();
}

1;
# vim: set sw=4 et:
