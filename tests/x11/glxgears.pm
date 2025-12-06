# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: Mesa-demo-x
# Summary: glxgears can start
# - Handle installing of Mesa-demo-x (if necessary)
# - Launch glxgears and check if it is running
# - Close glxgears
# Maintainer: QE Core <qe-core@suse.de>

use base "x11test";
use testapi;

sub run {
    select_console 'x11';
    ensure_installed 'Mesa-demo-x';
    # 'no_wait' for screen check because glxgears will be always moving
    x11_start_program('glxgears', match_no_wait => 1);
    send_key 'alt-f4';
}

1;
