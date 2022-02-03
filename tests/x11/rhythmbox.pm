# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rhythmbox
# Summary: Startup of rhythmbox
# Maintainer: QE Core <qe-core@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils "zypper_call";
use x11utils 'start_root_shell_in_xterm';

sub run {
    if (!script_run "rpm -q libtdb1") {
        record_soft_failure("Missing dependency for rhythmbox - bsc#1195510");
        start_root_shell_in_xterm();
        zypper_call "in libtdb1";
        enter_cmd "killall xterm";
    }
    x11_start_program('rhythmbox');
    send_key "alt-f4";
}

1;
