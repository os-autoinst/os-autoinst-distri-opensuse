# Copyright 2023-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test Elemental container image
#   This image is used as a base to build an Elemental container image.
#   Then, that image will be used to build a Host OS on top, so
#   it includes the kernel, firmware, bootloader, etc.
#
# Maintainer: elemental@suse.de

use base 'opensusebasetest';
use strict;
use warnings;

use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(file_content_replace);
use version_utils qw(is_sle_micro);

=head2 get_filename

 get_filename(file => '/path/to/file');

Extract the filename from F</path/to/file> and return it.

=cut

sub get_filename {
    my %args = @_;

    my @spl = split('/', $args{file});

    return $spl[$#spl];
}

sub run {
    select_serial_terminal;

    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');
    my $flavor = get_required_var('FLAVOR');
    my $arch = get_required_var('ARCH');
    my $cnt_name = 'elemental_image';
    my $shared = '/var/shared';
    my $build_raw_cmd = "elemental --debug build-disk --expandable --squash-no-compression -n $flavor-$arch -o /host --system dir:/";

    # Create shared directory
    assert_script_run("mkdir -p $shared");

    if ($image =~ m/os-container/) {
        assert_script_run("podman pull $image");
        assert_script_run("podman run --name $cnt_name -v $shared:/host:Z -dt $image sleep infinity");

        record_info('Kernel', 'Test that kernel files are present');
        foreach my $file ('initrd', 'vmlinuz') {
            validate_script_output("podman exec $cnt_name /bin/sh -c 'ls /boot'", sub { m/$file/ });
        }

        record_info('Grub', 'Test that /etc/default/grub exists and it is not empty');
        assert_script_run("podman exec $cnt_name /bin/sh -c 'test -s /etc/default/grub'");

        record_info('Repos', 'Image should come with empty repos');
        validate_script_output("podman exec $cnt_name /bin/sh -c 'zypper lr' 2>&1", sub { m/No repositories defined/ }, proceed_on_failure => 1);
        assert_script_run("podman exec $cnt_name /bin/sh -c '[[ -z \"\$(ls -A /etc/zypp/repos.d)\" ]]'");

        unless ($image =~ m/(base|kvm)-os-container/) {
            record_info('Firmware', 'Test that /lib/firmware directory is not empty');
            assert_script_run("podman exec $cnt_name /bin/sh -c 'test -d /lib/firmware'");
            assert_script_run("podman exec $cnt_name /bin/sh -c '[[ -n \"\$(ls -A /lib/firmware)\" ]]'");
        }

        record_info('QCOW2', 'Generate and upload QCOW2 image');

        # Installation files
        my @config_files = ("$shared/install.yaml", "$shared/cloud-config.yaml");
        my $grub_env_path = '/host/build/efi';

        # Encode root password
        my $rootpwd = script_output('openssl passwd -6 ' . get_required_var('TEST_PASSWORD'));

        # Add configuration files
        foreach my $config_file (@config_files) {
            assert_script_run('curl ' . data_url('elemental/' . get_filename(file => $config_file)) . ' -o ' . $config_file);
            file_content_replace($config_file, '%TEST_PASSWORD%' => $rootpwd);
            file_content_replace($config_file, '%STEP%' => 'disk');
            file_content_replace($config_file, '%PATH%' => $grub_env_path);
        }

        # Move install.yaml in /oem
        assert_script_run("podman exec $cnt_name /bin/sh -c 'mv /host/install.yaml /oem/'");

        # Create and upload QCOW2 image (forced to 20GB to allow enough space for creating active partition)
        assert_script_run("podman exec $cnt_name /bin/sh -c '$build_raw_cmd --cloud-init /host/*.yaml'");
        assert_script_run("qemu-img convert -f raw -O qcow2 $shared/$flavor-$arch.raw $shared/elemental-$flavor-$arch.qcow2");
        assert_script_run("qemu-img resize $shared/elemental-$flavor-$arch.qcow2 20G");
        upload_asset("$shared/elemental-$flavor-$arch.qcow2", 1);
    }

    if ($image =~ m/iso-image/) {
        # Create and upload ISO image
        record_info('ISO', 'Generate and upload ISO');
        assert_script_run("podman run --rm -v $shared:/host:Z $image /bin/sh -c 'busybox cp /elemental-iso/*.iso /host/elemental-$flavor-$arch.iso'");
        upload_asset("$shared/elemental-$flavor-$arch.iso", 1);
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
