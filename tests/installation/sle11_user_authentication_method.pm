# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "y2logsstep";
use strict;
use testapi;

sub run() {
    my $self = shift;

    assert_screen 'user-authentification-method', 40;
    if (match_has_tag('ldap-selected')) {
        send_key 'alt-o';
        assert_screen 'local-user-selected';
    }
    send_key $cmd{next};
}

1;
