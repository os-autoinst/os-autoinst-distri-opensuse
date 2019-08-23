# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic functionality of gedit
# - Launch gedit and check if it is running
# - Type "If you can see this text gedit is working." and check
# - Close gedit
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    x11_start_program('gedit');
    $self->enter_test_text('gedit');
    assert_screen 'test-gedit-1';
    send_key 'alt-f4';
    assert_screen 'gedit-save-changes';
    send_key 'alt-w';
}

1;
