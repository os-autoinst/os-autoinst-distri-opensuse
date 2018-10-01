# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Firefox: Externally handled content (Case#1436064)
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11test";
use testapi;
use version_utils 'sle_version_at_least';

sub run {
    my ($self) = @_;

    $self->start_firefox_with_profile;
    $self->firefox_open_url('http://mirror.bej.suse.com/dist/install/SLP/SLE-12-SP3-Server-GM/x86_64/dvd1/');

    assert_screen('firefox-extcontent-pageloaded');

    send_key "/";
    sleep 1;
    type_string "license.tar.gz\n";

    assert_screen('firefox-extcontent-opening', 60);

    send_key "alt-o";
    sleep 1;
    send_key "ret";

    assert_screen((sle_version_at_least('15')) ? 'firefox-extcontent-nautils' : 'firefox-extcontent-archive_manager');

    send_key "ctrl-q";

    $self->exit_firefox;
}
1;
