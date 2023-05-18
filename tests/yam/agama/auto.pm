## Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: First installation using D-Installer current CLI (only for development purpose)
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base yam::agama::agama_base;
use strict;
use warnings;

use testapi 'assert_screen';


sub run {
    assert_screen('agama-main-page', 120);
    assert_screen('agama-installing', 60);

    my @tags = ("welcome-to", "login");
    assert_screen \@tags, 960;
}

1;
