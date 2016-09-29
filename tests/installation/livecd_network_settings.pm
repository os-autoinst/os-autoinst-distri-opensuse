# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Add test for live installer based on Kde-Live
#    The live installer was missing for some time from the media and the left overs
#    in tests showed to be out of date. Changing all necessary references to ensure
#    the live medium can be booted, the net installer can be run from the plasma
#    session and the installed Tumbleweed system boots correctly. In the process an
#    issue with the live installer has been found and is worked around while
#    recording a reference to the bug.
#
#    Adds new variable 'LIVE_INSTALLATION'. 'LIVETEST' must not be set but only
#    'LIVECD'.
#
#    Verification run: http://lord.arch/tests/3043
# G-Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

# Maintainer: okurz@suse.de
# Summary: Live-CD installer since 2016 seems to have an additional step
# 'network settings' after welcome
sub run() {
    assert_screen 'inst-network_settings-livecd';
    send_key $cmd{next};
    # wait for key import dialog during initialization
    assert_screen 'import-untrusted-gpg-key-B88B2FD43DBDC284', 120;
    # 'T'rust
    wait_screen_change { send_key 'alt-t'; };
    # LIVECD installer assumes online repos at this point
    wait_still_screen;
    wait_screen_change { send_key $cmd{next}; };
}

1;
# vim: set sw=4 et:
