# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Build SLEPOS images using image creator
# Maintainer: Pavel Sladek <psladek@suse.cz>

use base "basetest";
use strict;
use warnings;
use testapi;
use utils;
use slepos_images;


my %template_done;

sub build_image {
    my ($image, $template, $template_idx, $packages_ar) = @_;

    my ($imagebase, $version) = split_image_name($image);
    diag("image to be built using image creator: '$image' ");

    #add virtual drivers unless already done
    if (!$template_done{$template}) {
        select_console('root-console');
        wait_still_screen;
        save_screenshot;

        prepare_template($template);
        $template_done{$template} = 1;

        select_console('x11');
        wait_still_screen;
    }

    # assume image creator is started, and on the add image screen
    #add image
    mouse_hide;
    save_screenshot;
    assert_and_click('image-creator-addimage');
    wait_still_screen(3);
    send_key('alt-s');
    save_screenshot;
    assert_and_click('image-creator-list-templates');
    #select image template
    save_screenshot;
    send_key('end');
    for (my $i = 0; $i < $template_idx; $i++) {
        send_key('up');
    }
    wait_still_screen(3);
    save_screenshot;
    send_key('ret');

    assert_and_click('image-creator-imagename');
    type_string($imagebase);
    wait_still_screen(3);
    save_screenshot;
    #todo: uncheck 32bit for (get_var('VERSION') =~ /^12/) {
    assert_and_click('image-creator-next1');
    assert_screen(['import-untrusted-gpg-key', 'image-creator-image-configuration']);
    if (match_has_tag('import-untrusted-gpg-key')) {
        send_key('alt-i');
    }
    assert_and_click('image-creator-version');
    send_key('shift-home');
    send_key('delete');
    type_string($version);
    assert_and_click('image-creator-users');
    assert_and_click('image-creator-edit-user');    #assume root is selected
    assert_screen('image-creator-edit-user-dialog');
    send_key('alt-p');
    type_password;
    send_key('tab');
    type_password;
    save_screenshot;
    send_key('alt-o');

    #add user
    assert_and_click('image-creator-add-user');
    assert_screen('image-creator-add-user-dialog');
    type_string($username);                         #login name
    send_key('tab');
    type_string($realname);                         #fullname
    send_key('tab');
    type_password;
    send_key('tab');
    type_password;
    send_key('tab');
    type_string('/home/' . $username);              #home directory
    save_screenshot;
    send_key('alt-o');

    #add packages
    #TODO: allow general packages also via variable
    assert_and_click('image-creator-configuration-tab');
    assert_screen('image-creator-image-configuration');
    for my $package (@$packages_ar) {
        send_key('alt-a');
        assert_and_click('image-creator-package-search-tab');     #assume pattern selection is default selection
        assert_screen('image-creator-package-search');
        assert_and_click('image-creator-package-search-mode');    #exact match
        send_key('down');
        send_key('down');
        send_key('ret');
        assert_and_click('image-creator-package-search-dialog');
        type_string($package);
        send_key('ret');
        wait_still_screen;
        assert_and_click('package-checkbox');
        save_screenshot;
        send_key('alt-a');
        assert_screen(['changed-packages', 'image-creator-image-configuration']);
        if (match_has_tag('changed-packages')) {
            send_key('alt-o');
            assert_screen('image-creator-image-configuration');
        }

    }

    #start image build
    assert_screen('image-creator-image-configuration');
    send_key('alt-f');
    if (check_screen('image-create-confirmation')) {
        send_key('alt-y');
    }
    if (check_screen('imagepath-create-confirmation')) {
        assert_and_click('yes-checkbox');
    }

    my $buildtime    = 0;
    my $maxbuildtime = 1500;
    my $checktime    = 20;     #should also not exceed screen lock time
    my $timeout      = 0;
    while (!check_screen('image-created', $checktime) && !$timeout) {
        $buildtime += $checktime;
        $timeout = 1 if $buildtime > $maxbuildtime;
        mouse_set(($buildtime / 2) % 800, 0);
    }

    if ($timeout) {            #timeout - save log
        die "Error: image creation timeout (${maxbuildtime}s), image build failed!";
    }

    #save logs
    send_key('alt-s');
    assert_screen('save-image-creation-logs');
    send_key('alt-t');
    send_key('home');
    send_key('shift-end');
    type_string($image . '.stdout');
    send_key('alt-e');
    send_key('home');
    send_key('shift-end');
    type_string($image . '.stderr');
    save_screenshot;
    send_key('alt-s');

    assert_screen('image-created');
    send_key('alt-o');
    assert_screen('image-created-ok');
    assert_and_click('ok-checkbox');
    assert_screen('image-creator-addimage');    #back to start ascreen

    #upload image
    select_console('root-console');
    wait_still_screen;
    save_screenshot;
    type_string "mv /var/lib/SLEPOS/system/images/$imagebase/ /var/lib/SLEPOS/system/images/$image/\n";
    type_string "rm -fr /var/lib/SLEPOS/system/$imagebase\n";    #remove previous cfg to allow subsequent images of same basename
    script_output "ls -l /var/lib/SLEPOS/system/images/$image/";
    script_output "ls -l /tmp/$image*";
    upload_logs "/tmp/$image.stderr", 'public';
    upload_logs "/tmp/$image.stdout", 'public';
    upload_slepos_image($image, 'pxe');

    select_console('x11', await_console => 0);
    ensure_unlocked_desktop;
}


sub prepare_template {
    my ($template) = @_;

    my $image_path = '/usr/share/kiwi/image/SLEPOS';
    my @vdrivers   = (
        'drivers/virtio/virtio_ring.ko', 'drivers/virtio/virtio.ko', 'drivers/net/virtio_net.ko', 'drivers/scsi/virtio_scsi.ko',
        'drivers/block/virtio_blk.ko',   'drivers/virtio/virtio_pci.ko'
    );

    type_string
      "grep -v \"wireless support\" \"$image_path/$template/config.xml\" |grep -v \"SUSE Manager support\" > \"$image_path/$template/config.xml.tmp\"\n";
    type_string "mv -f \"$image_path/$template/config.xml.tmp\" \"$image_path/$template/config.xml\"\n";

    my $driverlist;
    foreach my $driver (@vdrivers) {
        $driverlist .= "<file name='$driver'/>";
    }
    script_output "sed -i -e \"s|</drivers>|$driverlist</drivers>|\" \"$image_path/$template/config.xml\"";
    type_string "cat $image_path/$template/config.xml\n";
    wait_still_screen;
    save_screenshot;
}


sub run() {
    #todo: generalize so more than just graphical can be built
    my $images_ref = get_var_array('IMAGE_CREATOR');

    save_screenshot;
    select_console('x11', await_console => 0);
    save_screenshot;
    ensure_unlocked_desktop;
    save_screenshot;

    x11_start_program("xdg-su -c '/sbin/yast2 image-creator'", 3);
    if (check_screen('root-auth-dialog')) {
        if ($password) {
            type_password;
            send_key('ret', 1);
        }
    }
    assert_screen('image-creator-addimage', 100);    #check start ascreen

    foreach my $image (@{$images_ref}) {
        build_image('graphical-3.4.0', 'graphical-4.0.0', 2, ['liberation-fonts']) if ($image eq 'graphical-3.4.0');
        build_image('graphical-4.0.0', 'graphical-4.0.0', 2, ['liberation-fonts', 'cryptsetup']) if ($image eq 'graphical-4.0.0');
        build_image('minimal-3.4.0', 'minimal-3.4.0', 0) if ($image eq 'minimal-3.4.0');
        build_image('jeos-4.0.0',    'jeos-4.0.0',    1) if ($image eq 'jeos-4.0.0');
    }

    send_key('alt-l');                               #close
    select_console('root-console');
    wait_still_screen;
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
