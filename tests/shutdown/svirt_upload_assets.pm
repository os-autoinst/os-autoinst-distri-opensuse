# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: upload svirt assets
# Maintainer: Michal Nowak <mnowak@suse.com>

use base 'installbasetest';
use strict;
use warnings;
use testapi;
use version_utils 'is_vmware';

sub extract_assets {
    my ($args) = @_;

    my $name   = $args->{name};
    my $format = $args->{format};

    type_string("clear\n");
    my $image_storage  = '/var/lib/libvirt/images';
    my $svirt_img_name = $image_storage . '/' . $args->{svirt_name} . '.img';
    type_string("test -e $svirt_img_name && echo 'OK'\n");
    assert_screen('svirt-asset-upload-hdd-image-exists');

    my $cmd = "nice ionice qemu-img convert -p -O $format $svirt_img_name $image_storage/$name";
    if (get_var('QEMU_COMPRESS_QCOW2')) {
        $cmd .= ' -c';
    }
    type_string("$cmd && echo OK\n");
    assert_screen('svirt-asset-upload-hdd-image-converted', 600);

    # Upload the image as a private asset; do the upload verification
    # on your own - hence the following assert_screen().
    upload_asset("$image_storage/$name", 1, 1);
    assert_screen('svirt-asset-upload-hdd-image-uploaded', 1000);
}

sub run {
    # Not implemented on VMware
    return 1 if is_vmware;
    # connect to VIRSH_HOSTNAME screen and upload asset from there
    my $svirt = select_console('svirt');

    # mark hard disks for upload if test finished
    my @toextract;
    my $first_hdd = get_var('S390_ZKVM') ? 'a' : 'b';
    for my $i (1 .. get_var('NUMDISKS')) {
        my $name = get_var("PUBLISH_HDD_$i");
        next unless $name;
        $name =~ /\.([[:alnum:]]+)$/;
        my $format = $1;
        if (($format ne 'raw') and ($format ne 'qcow2')) {
            next;
        }
        push @toextract, {name => $name, format => $format, svirt_name => $svirt->name . chr(ord($first_hdd) + $i - 1)};
    }
    for my $asset (@toextract) {
        extract_assets($asset);
    }
}

1;
