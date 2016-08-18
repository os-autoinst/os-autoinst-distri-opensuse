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

# Maintainer: okurz@suse.de
# Summary: Live-CD installer since 2016 seems to have an additional step
# 'network settings' after welcome
sub run() {
    assert_screen 'inst-network_settings-livecd';
    # ne'x't
    send_key 'alt-x';
    # wait for key import dialog during initialization
    assert_screen 'import-untrusted-gpg-key-B88B2FD43DBDC284', 120;
    # 'T'rust
    wait_screen_change { send_key 'alt-t'; };
    # LIVECD installer assumes online repos at this point
    # continuing with 'n'ext
    wait_still_screen;
    wait_screen_change { send_key 'alt-n'; };
}

1;
# vim: set sw=4 et:
