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


sub run() {
    my $self = shift;

    script_output "
      set -x -e
      curl " . autoinst_url . "/data/slepos/kiwi_build_image.sh > kiwi_build_image.sh
      chmod 755 kiwi_build_image.sh
    ";

    script_output "./kiwi_build_image.sh minimal-3.4.0 jeos-4.0.0  linux32 ", 1000;
    script_output "ls -l /var/lib/SLEPOS/system/images/minimal-3.4.0/";
    upload_logs "/var/log/image_prepare-minimal-3.4.0";
    upload_logs "/var/log/image_create-minimal-3.4.0";
    upload_asset '/var/lib/SLEPOS/system/images/minimal-3.4.0/minimal.i686-3.4.0.md5';
    upload_asset '/var/lib/SLEPOS/system/images/minimal-3.4.0/minimal.i686-3.4.0.gz';
    script_output "./kiwi_build_image.sh graphical-3.4.0 graphical-4.0.0 linux32 's|</packages>|<package name=\"cryptsetup\"/><package name=\"liberation-fonts\"/></packages>|' ", 1000;
    script_output "ls -l /var/lib/SLEPOS/system/images/graphical-3.4.0/";
    upload_logs "/var/log/image_prepare-graphical-3.4.0";
    upload_logs "/var/log/image_create-graphical-3.4.0";
    upload_asset '/var/lib/SLEPOS/system/images/graphical-3.4.0/graphical.i686-3.4.0.md5';
    upload_asset '/var/lib/SLEPOS/system/images/graphical-3.4.0/graphical.i686-3.4.0.gz';
    #script_output "./kiwi_build_image.sh minimal-3.4.1 minimal-3.4.0 linux32 's|<locale>en_US<locale>|<locale>cs_CZ</locale>|' ", 1000;
    #script_output "./kiwi_build_image.sh minimal-3.4.2 minimal-3.4.0 linux32 's|>pxe<| luks=\"luks-c291cmNlcyA5MjIgMCBSIAovTWVkaWFCb3ggWy0yOC4zNDYgLTI4LjM0NiA1MzIuMzQ2IDY0MC4z\">pxe<|' ", 1000;
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
