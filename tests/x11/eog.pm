# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: eog
# Summary: eye of gnome image viewer
# - Installs eog if necessary
# - Launch eog
# - Check if eog is running
# - Close eog
# Maintainer: QE Core <qe-core@suse.de>

use base "x11test";
use testapi;
use utils;


sub run {
    assert_gui_app('eog', exec_param => get_var('WALLPAPER'));
}

1;
