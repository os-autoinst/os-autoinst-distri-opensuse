## Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: First installation using D-Installer current CLI (only for development purpose)
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;

use testapi;


sub run {

    assert_screen('alp-installer-ui', 120);

    assert_screen('alp-installing', 60);

    assert_screen('bedrock-login', 960);
}

1;
