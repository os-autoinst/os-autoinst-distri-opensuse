# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Boot into MS Windows from grub
# Maintainer: GraceWang <gwang@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    $self->{in_boot_desktop} = 1;

    assert_screen "grub-boot-windows", 300;
    send_key "esc";
    assert_screen "windows-login", 300;
    type_password;
    send_key "ret";
    assert_screen 'windows-desktop', 120;
}

sub test_flags {
    return {fatal => 1};
}

1;
