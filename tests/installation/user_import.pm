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

sub run() {
    my $self = shift;

    assert_screen 'import-user-data';
    send_key 'alt-i';
    send_key 'alt-e';
    assert_screen 'import-user-data-selection';
    send_key 'alt-a';
    assert_screen 'import-user-data-selected-user';
    send_key $cmd{ok};

    send_key $cmd{next};
}

1;
