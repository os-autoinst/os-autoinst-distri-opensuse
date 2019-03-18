# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1479153 Firefox: Smoke Test
# Maintainer: wnereiz <wnereiz@github>

use strict;
use warnings;
use base "x11test";
use testapi;
use utils 'type_string_slow';

sub run {
    my ($self) = @_;

    $self->start_clean_firefox;

    # Exit
    $self->exit_firefox;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
