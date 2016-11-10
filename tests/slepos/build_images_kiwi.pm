# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: image download and build SLEPOS test
# Maintainer: Pavel Sladek <psladek@suse.cz>

use base "basetest";
use strict;
use warnings;
use testapi;
use utils;


my $imsuffix = 'tar.bz2';

sub get_image {
    my ($im_hr, $target, $template, $linux32, $mod) = @_;
    if (defined $im_hr->{$target}) {
        download_image($im_hr, $target);
    }
    else {
        build_image($target, $template, $linux32, $mod);
    }
}



sub download_image {
    my ($im_hr, $target) = @_;
    my $asset = 'ASSET_' . $im_hr->{$target};
    bmwqemu::diag("image '$target' will be downloaded from $asset:");
    my $iurl = data_url($asset);
    script_output "wget $iurl -O - |tar -xj -C /", 1300;
    script_output "ls -l /var/lib/SLEPOS/system/images/$target/";
}



sub build_image {
    my ($target, $template, $linux32, $mod) = @_;
    bmwqemu::diag("image '$target' will be built:");
    $linux32 = $linux32 ? 'linux32' : '';
    $mod //= '';
    script_output "./kiwi_build_image.sh '$target' '$template' '$linux32' '$mod'", 2000;
    script_output "ls -l /var/lib/SLEPOS/system/images/$target/";
    upload_logs "/var/log/image_prepare-$target";
    upload_logs "/var/log/image_create-$target";
    script_output "tar -cjf $target.$imsuffix /var/lib/SLEPOS/system/images/$target/", 2000;
    upload_asset "$target.$imsuffix",                                                  'public';
}


sub run() {
    my $self = shift;

    script_output "
      set -x -e
      curl " . autoinst_url . "/data/slepos/kiwi_build_image.sh > kiwi_build_image.sh
      chmod 755 kiwi_build_image.sh
    ";

    my %img_h;    #asset number hashed by standard image name
    for my $n (0 .. 9) {    #process all assets for assumed image name
        next unless my $imgfile = get_var("ASSET_$n");
        my $imgname = $imgfile;
        $imgname =~ s/\Q.$imsuffix\E$//;
        $imgname =~ s/^\d+-//;
        $img_h{$imgname} = $n;
    }


    if (get_var('VERSION') =~ /^11/) {
        get_image(\%img_h, 'minimal-3.4.0',   'minimal-3.4.0',   'linux32');
        get_image(\%img_h, 'jeos-4.0.0',      'jeos-4.0.0',      'linux32');
        get_image(\%img_h, 'graphical-3.4.0', 'graphical-4.0.0', 'linux32');
        get_image(\%img_h, 'graphical-4.0.0', 'graphical-4.0.0', 'linux32', 's|</packages>|<package name=\"cryptsetup\"/><package name=\"liberation-fonts\"/></packages>|');
    }
    elsif (get_var('VERSION') =~ /^12/) {
        get_image(\%img_h, 'minimal-sles12-3.4.0',   'minimal-3.4.0');
        get_image(\%img_h, 'jeos-sles12-4.0.0',      'jeos-4.0.0');
        get_image(\%img_h, 'graphical-sles12-3.4.0', 'graphical-4.0.0');
        get_image(\%img_h, 'graphical-sles12-4.0.0', 'graphical-4.0.0', '', 's|</packages>|<package name=\"cryptsetup\"/><package name=\"liberation-fonts\"/></packages>|');
    }


}



sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
