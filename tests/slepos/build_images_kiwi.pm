# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "basetest";
use testapi;
use utils;

sub build_image {
    my ($target, $template, $linux32, $mod) = @_;

    $linux32 = $linux32 ? 'linux32' : '';
    $mod //= '';

    script_output "./kiwi_build_image.sh '$target' '$template' '$linux32' '$mod'", 1000;
    script_output "ls -l /var/lib/SLEPOS/system/images/$target/";
    upload_logs "/var/log/image_prepare-$target";
    upload_logs "/var/log/image_create-$target";
    script_output "tar -cjf $target.tar.bz2 /var/lib/SLEPOS/system/images/$target/", 300;
    upload_asset "$target.tar.bz2",                                                  'public';
}

sub run() {
    my $self = shift;

    script_output "
      set -x -e
      curl " . autoinst_url . "/data/slepos/kiwi_build_image.sh > kiwi_build_image.sh
      chmod 755 kiwi_build_image.sh
    ";
    if (get_var('VERSION') =~ /^11/) {
        build_image('minimal-3.4.0', 'jeos-4.0.0', 'linux32');
        build_image('graphical-3.4.0', 'graphical-4.0.0', 'linux32', 's|</packages>|<package name=\"cryptsetup\"/><package name=\"liberation-fonts\"/></packages>|');
    }
    elsif (get_var('VERSION') =~ /^12/) {
        build_image('minimal-3.4.0', 'jeos-5.0.0');
        build_image('graphical-3.4.0', 'graphical-5.0.0', '', 's|</packages>|<package name=\"cryptsetup\"/><package name=\"liberation-fonts\"/></packages>|');
    }
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
