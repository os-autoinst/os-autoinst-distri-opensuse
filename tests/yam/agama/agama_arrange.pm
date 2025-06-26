## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Set AGAMA_VERSION variable from value read in info file
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::patch_agama_base;
use strict;
use warnings;
use testapi;

sub set_agama_version {
    my $info_file = script_output("cat /var/log/build/info");
    if ($info_file =~ /^Image.version:\s+(?<major_version>\d+)\./m) {
        set_var("AGAMA_VERSION", $+{'major_version'});
        record_info('AGAMAVERSION', $+{'major_version'});
    }
}

sub run {
    select_console 'install-shell';
    set_agama_version();
}

1;
