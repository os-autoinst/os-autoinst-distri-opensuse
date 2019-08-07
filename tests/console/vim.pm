# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test vim editor display including syntax highlighting
# - Check if vim is installed
# - Check if vim-data is installed (should not be on JeOS (cexcept openSUSE
# aarch64))
# - Run "vim /etc/passwd"
# - Check if file is opened correctly (with syntax hightlight)
# - Force exit vim (":q!")
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use version_utils qw(is_jeos is_opensuse);

sub run {
    assert_script_run 'rpm -qi vim';
    # vim-data package must not be present on JeOS (except on aarch64 openSUSE)
    assert_script_run('! rpm -qi vim-data') if (is_jeos() && !(check_var('ARCH', 'aarch64') && is_opensuse()));
    type_string "vim /etc/passwd\n";
    my $jeos = is_jeos() ? '-jeos' : '';
    assert_screen "vim-showing-passwd$jeos";
    wait_screen_change { type_string ":q!\n" };
}

1;
