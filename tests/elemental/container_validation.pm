# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test Elemental container image
#   This image is used as a base to build an Elemental container image.
#   Then, that image will be used to build a Host OS on top, so
#   it includes the kernel, firmware, bootloader, etc.
#
# Maintainer: elemental@suse.de

use base 'opensusebasetest';

use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(file_content_replace);
use version_utils qw(is_sle_micro);
use Utils::Architectures qw(is_aarch64);

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

    my $arch = get_required_var('ARCH');
    my $build = get_required_var('BUILD');
    my $flavor = get_required_var('FLAVOR');
    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');
    my $cnt_name = 'elemental_image';
    my $img_filename = "elemental-$build-$arch";
    my $shared = '/var/shared';

    # Clean image filename (useful for cloned jobs)
    $img_filename =~ tr/\/#/_/;

    # Define timeouts based on the architecture
    my $timeout = (is_aarch64) ? 960 : 480;

    # Set SELinux in permissive mode, as there is an issue with Enforcing mode and Elemental doesn't support it
    assert_script_run("setenforce Permissive");

    # Create shared directory
    assert_script_run("mkdir -p $shared");

    if (lc($flavor) =~ m/image/) {
        assert_script_run("podman pull $image", $timeout);
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

        unless ($image =~ m/(base|kvm)/) {
            record_info('Firmware', 'Test that /lib/firmware directory is not empty');
            assert_script_run("podman exec $cnt_name /bin/sh -c 'test -d /lib/firmware'");
            assert_script_run("podman exec $cnt_name /bin/sh -c '[[ -n \"\$(ls -A /lib/firmware)\" ]]'");
        }

        # For now OS image based on SLMicro5.5 has broken 'build-disk' command, so we cannot test it
        # NOTE: keep support for this older image in the following code to be able to test it if 'build-disk' will be fixed
        if (is_sle_micro('>=6.0')) {
            record_info('QCOW2', 'Generate and upload QCOW2 image');

            # Installation files
            my @config_files = ("$shared/install.yaml", "$shared/cloud-config.yaml");
            my $grub_env_path = is_sle_micro('<6.0') ? '/host/build/state' : '/host/build/efi';

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
            my $build_opts = is_sle_micro('<6.0') ? "--unprivileged dir:/" : "--system dir:/";
            my $build_raw_cmd = "elemental --debug build-disk --expandable --squash-no-compression --name $img_filename --cloud-init /host/*.yaml --output /host $build_opts";
            assert_script_run("podman exec $cnt_name /bin/sh -c '$build_raw_cmd'", $timeout);
            assert_script_run("qemu-img convert -f raw -O qcow2 $shared/$img_filename.raw $shared/$img_filename.qcow2", $timeout);
            assert_script_run("qemu-img resize $shared/$img_filename.qcow2 20G", $timeout);
            upload_asset("$shared/$img_filename.qcow2", 1);
        }
    }

    if (lc($flavor) =~ m/iso/) {
        # Create and upload ISO image
        record_info('ISO', 'Generate and upload ISO');
        assert_script_run("podman run --rm -v $shared:/host:Z $image /bin/sh -c 'busybox cp /elemental-iso/*.iso /host/$img_filename.iso'", $timeout);
        upload_asset("$shared/$img_filename.iso", 1);
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
