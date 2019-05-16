# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Root password settings
# Maintainer: Martin Kravec <mkravec@suse.com>

use strict;
use warnings;
use base qw(installation_user_settings y2_installbase);
use caasp 'send_alt';
use testapi;

sub run {
    my ($self) = @_;
    send_alt 'password';
    $self->type_password_and_verification;
    assert_screen "rootpassword-typed";
}

1;
