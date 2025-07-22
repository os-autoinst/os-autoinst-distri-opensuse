# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Skip disk activation during installation
# Maintainer: Stephan Kulow <coolo@suse.de>

use base 'y2_installbase';
use testapi;

sub run {
    wait_screen_change { send_key $cmd{next} };
}

1;
