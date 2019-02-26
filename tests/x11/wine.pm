# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test wine with a simple Windows program
#   I decided for about the most simple and small Windows programs I could
#   find because one of the things I dislike about the MS Windows ecoysystem
#   is bloated applications.
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use warnings;
use testapi;

sub run {
    select_console 'x11';
    # Actually only wine should suffice for the tiny app but maybe it really
    # requires .NET because on startup wine asks if it should install a
    # wine-mono package
    ensure_installed 'wine wine-mono', timeout => 360;
    x11_start_program('xterm');
    my $cmd = <<'EOF';
wget http://keir.net/download/timer.zip
unzip timer.zip
EOF
    assert_script_run($_) foreach (split /\n/, $cmd);
    script_run 'wine timer.exe', 0;
    assert_screen([qw(wine-timer wine-package-install-mono-cancel)], 600);
    if (match_has_tag 'wine-package-install-mono-cancel') {
        assert_and_click 'wine-package-install-mono-cancel';
        assert_screen 'wine-timer', 600;
    }
    wait_screen_change { send_key 'alt-f4' };
    send_key 'alt-f4';
}

1;
