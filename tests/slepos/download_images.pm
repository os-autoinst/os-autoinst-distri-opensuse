# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: download images SLEPOS test
# Maintainer: Pavel Sladek <psladek@suse.cz>

use base "basetest";
use strict;
use warnings;
use testapi;
use utils;


my $img_suffix = 'tar.bz2';

sub download_image {
    my ($n)    = @_;
    my $asset  = 'ASSET_' . $n;
    my $target = get_var("$asset");    #i.e graphical-4.0.0.tar.bz2 or 00011400-graphical-4.0.0.tar.bz2
    $target =~ s/^\d+-//;              #remove if private assets reference
    $target =~ s/\Q.$img_suffix\E$//;  #remove suffix
    bmwqemu::diag("image '$target' will be downloaded from $asset:");
    my $iurl = data_url("$asset");
    script_output "wget $iurl -O - |tar -xj -C /", 1300;
    script_output "ls -l /var/lib/SLEPOS/system/images/$target/";
}


sub run() {
    my $self    = shift;
    my $indexes = get_var_array("IMAGE_DOWNLOAD");
    for my $n (@{$indexes}) {          #process all referenced assets for image filename
        download_image($n);
    }
}


sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
