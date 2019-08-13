# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Startup, basic input, shutdown of oowriter
# - Launch oowriter
# - Type 'Hello World!'
# - Close oowriter
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils 'type_string_slow';

sub run {
    my ($self) = shift;

    $self->libreoffice_start_program('oowriter');
    # clicking the writing area to make sure the cursor addressed there
    wait_screen_change { assert_and_click('ooffice-writing-area', timeout => 10) };
    # auto-correction does not handle super-fast typing well
    type_string_slow 'Hello World!';
    assert_screen 'test-ooffice-2';
    send_key "alt-f4";
    assert_screen "ooffice-save-prompt";
    assert_and_click 'dont-save-libreoffice-btn';    # _Don't save
}

1;
