# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nautilus
# Summary: Test initial startup of nautilus
# - Start nautilus
# - Check if nautilus was launched
# - Close nautilus
# Maintainer: QE Core <qe-core@suse.de>

use base "x11test";
use testapi;

sub run {
    x11_start_program('nautilus');
    send_key "alt-f4";
}

1;
