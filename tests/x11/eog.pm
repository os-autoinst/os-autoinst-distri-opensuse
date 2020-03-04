# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: eye of gnome image viewer
# - Installs eog if necessary
# - Launch eog
# - Check if eog is running
# - Close eog
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;


sub run {
    if (is_sle('15-SP2+')) {
        record_soft_failure('bsc#1165520 - eog not installed by default anymore with system role GNOME and WE activated');
        zypper_call('in eog');
    }
    assert_gui_app('eog', exec_param => get_var('WALLPAPER'));
}

1;
