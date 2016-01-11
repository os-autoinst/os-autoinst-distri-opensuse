# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    # support test for help and release note button
    # just did the check after the welcome test
    # 120 secs sounds long here but live installer is
    # slowly to show the page next the welcome page
    assert_screen "good-buttons", 120;
}

1;
# vim: set sw=4 et:
