# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Cleanup before testing pidgin
# - remove pidgin package
# - ensure that package was really removed
# Maintainer: Zhaocong Jia <zcjia@suse.com> Grace Wang <grace.wang@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;

sub remove_pkg {
    my @packages = qw(pidgin);
    x11_start_program('xterm');

    # Remove packages
    assert_script_sudo "zypper -n rm @packages", 180;
    assert_script_run "zypper --no-refresh if @packages|grep 'not installed'";
    enter_cmd "exit";
}

sub run {
    remove_pkg;
}

1;
