## Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: First installation using D-Installer current CLI (only for development purpose)
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;

use testapi;
use utils;

sub run {
    my $path = data_url(get_var('AGAMA_AUTO'));
    set_var('EXTRABOOTPARAMS', "agama.auto=\"$path\"");
}

1;
