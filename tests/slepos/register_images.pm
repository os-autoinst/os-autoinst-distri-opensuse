# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic SLEPOS test for registering images
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "basetest";
use strict;
use warnings;
use testapi;
use utils;
use lockapi;
use slepos_images;

my $img_suffix = 'tar.bz2';

sub run() {

    my $kiwi_images_ref    = get_var_array('IMAGE_KIWI');
    my $creator_images_ref = get_var_array('IMAGE_CREATOR');
    my $dwl_images_idx_ref = get_var_array('IMAGE_DOWNLOAD');
    my @dwl_images;
    my @kiwi_images;
    my @creator_images;
    my $pxe_done = 0;
    foreach my $idx (@$dwl_images_idx_ref) {
        my $target = get_image_from_asset(get_asset_name($idx));
        @dwl_images = (@dwl_images, $target);
    }
    @kiwi_images    = @{$kiwi_images_ref}    if defined $kiwi_images_ref;
    @creator_images = @{$creator_images_ref} if defined $creator_images_ref;

    foreach my $img (@kiwi_images, @dwl_images) {
        if (!$pxe_done) {
            assert_script_run "registerImages --gzip --move --include-boot --ldap /var/lib/SLEPOS/system/images/$img";
            $pxe_done = 1;
        }
        else {
            assert_script_run "registerImages --gzip --ldap /var/lib/SLEPOS/system/images/$img";
        }
    }
    if (!$pxe_done) {
        die "Error: no image with valid pxe files present (note that pxe files from images supplied by image creator (via IMAGE_CREATOR) are ignored)";
    }
    foreach my $img (@creator_images) {    #due to bsc#1029872, creator images must not be used for pxe files
        assert_script_run "registerImages --gzip --ldap /var/lib/SLEPOS/system/images/$img";
    }

    #image specific configurations
    my $graphical_present = 0;
    foreach my $img (@creator_images, @kiwi_images, @dwl_images) {
        $graphical_present = 1 if ($img =~ /^graphical-/);
    }
    if ($graphical_present) {
        assert_script_run "curl " . autoinst_url . "/data/slepos/xorg.conf > /srv/SLEPOS/config/xorg.conf";
        assert_script_run
"posAdmin.pl --base cn=graphical,cn=default,cn=global,o=myorg,c=us --add --scConfigFileTemplate --cn xorg_conf --scConfigFile '/etc/X11/xorg.conf' --scMust TRUE --scBsize 1024 --scConfigFileData /srv/SLEPOS/config/xorg.conf";
    }

    mutex_create("images_registered");
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
