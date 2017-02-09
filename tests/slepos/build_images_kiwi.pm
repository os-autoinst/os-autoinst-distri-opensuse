# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: SLEPOS test - download images using KIWI
# Maintainer: Pavel Sladek <psladek@suse.cz>

use base "basetest";
use strict;
use warnings;
use testapi;
use utils;


my $img_suffix = 'tar.bz2';

sub build_image {
    my ($target, $template, $type, $linux32, @mod) = @_;
    bmwqemu::diag("image '$target' will be built:");
    $linux32 = $linux32 ? 'linux32' : '';
    my $arch = $linux32 ? 'i686' : 'x86_64';
    my ($name, $ver) = split "-", $target;
    $type //= 'pxe';
    script_output "./kiwi_build_image.sh '$target' '$template' '$linux32'" . join('', map { " '$_'" } @mod), 2000;
    script_output "ls -l /var/lib/SLEPOS/system/images/$target/";
    upload_logs "/var/log/image_prepare-$target";
    upload_logs "/var/log/image_create-$target";
    if ($type eq 'pxe') {
        script_output "tar -cjf $target.$img_suffix /var/lib/SLEPOS/system/images/$target/", 2000;
        upload_asset "$target.$img_suffix",                                                  'public';
    }
    elsif ($type eq 'oem') {
        upload_asset "/var/lib/SLEPOS/system/images/$target/$name.$arch-$ver.raw", 'public';
    }
}

sub run() {
    script_output "
      set -x -e
      curl " . autoinst_url . "/data/slepos/kiwi_build_image.sh > kiwi_build_image.sh
      chmod 755 kiwi_build_image.sh
    ";

    my $images_ref = get_var_array('IMAGE_KIWI');
    foreach my $image (@{$images_ref}) {
        #todo:split versions code into specific subdirectories
        if (get_var('VERSION') =~ /^11/) {
            build_image('minimal-3.4.0', 'minimal-3.4.0', 'pxe', 'linux32') if ($image eq 'minimal-3.4.0');
            build_image('jeos-4.0.0',    'jeos-4.0.0',    'pxe', 'linux32') if ($image eq 'jeos-4.0.0');
            build_image('graphical-3.4.0', 'graphical-4.0.0', 'pxe', 'linux32', 's|</packages>|<package name=\"liberation-fonts\"/></packages>|')
              if ($image eq 'graphical-3.4.0');
            build_image('graphical-4.0.0', 'graphical-4.0.0', 'pxe', 'linux32',
                's|</packages>|<package name=\"cryptsetup\"/><package name=\"liberation-fonts\"/></packages>|')
              if ($image eq 'graphical-4.0.0');
            build_image(
                'comboserver-4.0.0', 'comboserver-4.0.0', 'oem', '',
                's|<type|<type vga=\"0x317\"|',
                's|</packages>|<package name=\"liberation-fonts\"/><package name=\"SuSEfirewall2\"/></packages>|'
            ) if ($image eq 'comboserver-4.0.0');
        }
        elsif (get_var('VERSION') =~ /^12/) {
            build_image('minimal-sles12-3.4.0', 'minimal-3.4.0', 'pxe') if ($image eq 'minimal-3.4.0');
            build_image('jeos-sles12-4.0.0',    'jeos-4.0.0',    'pxe') if ($image eq 'jeos-4.0.0');
            build_image('graphical-sles12-3.4.0', 'graphical-4.0.0', 'pxe', '', 's|</packages>|<package name=\"liberation-fonts\"/></packages>|')
              if ($image eq 'graphical-3.4.0');
            build_image('graphical-sles12-4.0.0', 'graphical-4.0.0', 'pxe', '',
                's|</packages>|<package name=\"cryptsetup\"/><package name=\"liberation-fonts\"/></packages>|')
              if ($image eq 'graphical-4.0.0');
        }
    }
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
