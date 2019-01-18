# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Test to see if mouse is hidden - to be run before/as part of installation_mode
# G-Maintainer: Richard Brown <rbrownccb@opensuse.org>

use base "opensusebasetest";
use testapi;
use strict;
use warnings;

sub run {
    my $self = shift;
    if (check_screen('mouse-not-hidden', 120)) {
        die 'Mouse Stuck Detected';
    }
    $self->result('ok');
}

sub test_flags {
    return {fatal => 1};
}

1;
