# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Root password settings
# Maintainer: Martin Kravec <mkravec@suse.com>

use strict;
use warnings;
use parent qw(installation_user_settings y2logsstep);
use testapi;
use utils 'is_caasp';

sub run {
    my ($self) = @_;

    if (is_caasp '2.0+') {
        check_var('VIDEOMODE', 'text') ? send_key 'alt-a' : send_key 'alt-w';
    }
    else {
        send_key 'alt-a';
    }
    $self->type_password_and_verification;
    assert_screen "rootpassword-typed";
}

1;
# vim: set sw=4 et:
