# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Reboot after autoyast installation
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base 'y2_installbase';
use testapi;

sub run {
    assert_screen("grub2", get_var('AUTOUPGRADE') ? 5900 : 900);
}

1;
