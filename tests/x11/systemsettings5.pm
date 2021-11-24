# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemsettings5
# Summary: Like 'systemsettings' but for plasma5 (and more recent)
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    x11_start_program('systemsettings5', target_match => 'test-systemsettings-1');
    send_key "alt-f4";
}

1;
