# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test Elemental container image
#   This image is used as a base to build an Elemental container image.
#   Then, that image will be used to build a Host OS on top, so
#   it includes the kernel, firmware, bootloader, etc.
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base qw(opensusebasetest);
use testapi;
use transactional qw(trup_call);
use serial_terminal qw(select_serial_terminal);
use Mojo::File qw(path);
use utils qw(file_content_replace);
use Utils::Architectures qw(is_aarch64);

sub sysext_gen {
    my $sysext_path = get_required_var('SYSEXT_PATH');
    my $shared_dir = '/root/shared';
    my $config_file = "$shared_dir/config.sh";
    my $sysext_root = "$shared_dir/sysexts";
    my $sysext_dir = "$sysext_root/etc/extensions";
    my $overlay = "$shared_dir/sysexts.tar.gz";
    my $sysext_arch;
    my @sysexts;

    # Create directories
    assert_script_run("mkdir -p $sysext_dir");

    # Define architecture for the system extensions
    $sysext_arch = 'arm64' if ($args{arch} eq 'aarch64');
    $sysext_arch = 'x86-64' if ($args{arch} eq 'x86_64');

    # Get the system extensions list
    # NOTE: '/' is mandatory at the end of $sysext_path!
    my @list = split(
        /[\r\n]+/,
        script_output(
            "curl -s ${sysext_path}/ | sed -n 's/.*href=\"\\(.*_${sysext_arch}.raw\\)\">.*/\\1/p'"
        )
    );

    # Clean the list
    foreach (sort @list) {
        if ($_ =~ /$args{k8s}/) {
            # Keep only the first K8s version found (the lower version)
            # Higher versions can be used in another upgrade test
            next if $k8s_sysext_found;
            $k8s_sysext_found = 1;
        }
        push @sysexts, $_;
    }

    # Get the system extensions
    foreach my $sysext (@sysexts) {
        assert_script_run(
            "curl -v -f -o ${sysext_dir}/${sysext} ${sysext_path}/${sysext}",
            300);
    }

    # Package the system extensions
    assert_script_run("tar cvaf $overlay -C $sysext_root .");

    # Return systemd-sysexts file name
    return ($overlay, $sysext_dir);
}

sub build_cmd {
    my (%args) = @_;
    my $build_dir = '/root/build';
    my $tpl_tar = "$build_dir/build-tpl.tar.gz";
    my $krnlcmdline = get_var('KERNEL_CMD_LINE');
    my $manifest_uri = get_required_var('RELEASE_MANIFEST_URI');

    # Create directories
    assert_script_run("mkdir -p $build_dir");

    # Download build configuration files
    assert_script_run(
        "curl -v -o $tpl_tar "
          . data_url('elemental3/' . path($tpl_tar)->basename)
    );
    assert_script_run("tar xzvf $tpl_tar -C $build_dir");

    # Configure the build
    my $hashpwd = script_output("openssl passwd -6 $args{rootpwd}");
    file_content_replace(
        "$build_dir/butane.yaml",
        '--sed-modifier' => 'g',
        '%TEST_PASSWORD%' => $hashpwd,
        '%K8S%' => $args{k8s}
    );
    file_content_replace(
        "$build_dir/install.yaml",
        '--sed-modifier' => 'g',
        '%HDDSIZE%' => $args{hddsize},
        '%KERNEL_CMD_LINE%' => $krnlcmdline
    );
    file_content_replace(
        "$build_dir/release.yaml",
        '--sed-modifier' => 'g',
        '%RELEASE_MANIFEST_URI%' => $manifest_uri,
        '%K8S%' => $args{k8s}
    );

    # Generate OS image
    assert_script_run(
        "elemental3 --debug build --image-type raw --config-dir $build_dir --output uc_image.raw",
        $args{timeout}
    );

    # Convert RAW to QCOW2
    assert_script_run(
        "qemu-img convert -p -f raw -O qcow2 uc_image.raw ./$args{img_filename}.qcow2",
        $args{timeout}
    );

    # Return HDD image
    return ("$args{img_filename}.qcow2");
}

sub build_iso_cmd {
    my (%args) = @_;
    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');
    my $krnlcmdline = get_var('KERNEL_CMD_LINE');
    my $isocmdline = get_var('ISO_CMD_LINE');
    my $shared_dir = '/root/shared';
    my $config_file = "$shared_dir/config.sh";
    my $iso_config_file = "$shared_dir/config-iso.sh";
    my $device = get_var('INSTALL_DISK', '/dev/vda');

    # Configure the systemd sysexts
    record_info('SYSEXT', 'Download and configure systemd system extensions');
    my ($overlay, $sysext_dir) = sysext_gen();

    # Keep only Elemental sysexts for the ISO overlay
    script_run("find $sysext_dir -type f ! -name 'elemental*' -exec rm -f {} \\;");

    # OS configuration script
    assert_script_run(
        "curl -v -o $config_file "
          . data_url('elemental3/' . path($config_file)->basename)
    );
    file_content_replace(
        $config_file,
        '--sed-modifier' => 'g',
        '%TEST_PASSWORD%' => $args{rootpwd},
        '%K8S%' => $args{k8s}
    );
    assert_script_run("chmod 755 $config_file");

    # ISO configuration script
    assert_script_run(
        "curl -v -o $iso_config_file "
          . data_url('elemental3/' . path($iso_config_file)->basename)
    );
    assert_script_run("chmod 755 $iso_config_file");

    record_info('ISO', 'Generate and upload ISO image');

    # Generate OS image
    #   "elemental3ctl --debug build-installer \\
    #      --type iso \\
    assert_script_run(
        "elemental3ctl --debug build-iso \\
           --output . \\
           --name $args{img_filename} \\
           --os-image $image \\
           --cmdline '$isocmdline' \\
           --config $iso_config_file \\
           --overlay oci://$ctl_oci \\
           --install-overlay dir://$overlay_dir \\
           --install-config $config_file \\
           --install-cmdline '$krnlcmdline' \\
           --install-target $device",
        $args{timeout}
    );

    # Return ISO image
    return ("$args{img_filename}.iso");
}

sub install_cmd {
    my (%args) = @_;
    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');
    my $shared_dir = '/root/shared';
    my $config_file = "$shared_dir/config.sh";
    my $device = '/dev/nbd0';
    my $k8s_sysext_found;

    record_info('SYSEXT', 'Download and configure systemd system extensions');
    my $overlay = sysext_gen();

    # OS configuration script
    assert_script_run(
        "curl -v -o $config_file "
          . data_url('elemental3/' . path($config_file)->basename)
    );
    file_content_replace(
        $config_file,
        '--sed-modifier' => 'g',
        '%TEST_PASSWORD%' => $args{rootpwd},
        '%K8S%' => $args{k8s}
    );
    assert_script_run("chmod 755 $config_file");

    record_info('QCOW2', 'Generate and upload QCOW2 image');

    # Create a raw image and mount it
    assert_script_run("qemu-img create -f qcow2 $shared_dir/$args{img_filename}.qcow2 ${hddsize}G");
    assert_script_run('modprobe nbd');
    assert_script_run("qemu-nbd -c $device $shared_dir/$args{img_filename}.qcow2");

    # Generate OS image
    assert_script_run(
        "elemental3ctl --debug install --os-image $image --overlay tar://$overlay --config $config_file --target $device",
        $args{timeout}
    );

    # Return HDD image
    return ("$shared_dir/$args{img_filename}.qcow2");
}

sub run {
    my $arch = get_required_var('ARCH');
    my $k8s = get_required_var('K8S');
    my $hddsize = get_var('HDDSIZEGB', '30');
    my $rootpwd = get_required_var('TEST_PASSWORD');
    my $build = get_required_var('BUILD');
    my $repo_to_test = get_required_var('REPO_TO_TEST');
    my $img_filename = "elemental-$build-$arch";
    my $out_file;

    # Clean image filename (useful for cloned jobs)
    $img_filename =~ tr/\/#/_/;

    # Define timeouts based on the architecture
    my $timeout = (is_aarch64) ? 960 : 480;

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # Add Unified Core repository and install Elemental package
    trup_call("run zypper addrepo --check --refresh $repo_to_test elemental");
    trup_call('--continue run zypper --gpg-auto-import-keys refresh');
    trup_call('--continue pkg install elemental3 elemental3ctl squashfs mtools xorriso');
    trup_call('apply');

    # Set SELinux in permissive mode, as there is an issue with enforcing mode and Elemental3 doesn't support it yet
    assert_script_run("setenforce permissive");

    # Create HDD image with different commands
    $out_file = build_cmd(
        timeout => $timeout,
        k8s => $k8s,
        hddsize => $hddsize,
        rootpwd => $rootpwd,
        build => $build,
        repo_to_test => $repo_to_test,
        img_filename => $img_filename
    ) if check_var('ELEMENTAL_CMD', 'build');

    $out_file = build_iso_cmd(
        timeout => $timeout,
        k8s => $k8s,
        rootpwd => $rootpwd,
        build => $build,
        repo_to_test => $repo_to_test,
        img_filename => $img_filename
    ) if check_var('ELEMENTAL_CMD', 'build_iso');

    $out_file = install_cmd(
        timeout => $timeout,
        arch => $arch,
        k8s => $k8s,
        hddsize => $hddsize,
        rootpwd => $rootpwd,
        build => $build,
        repo_to_test => $repo_to_test,
        img_filename => $img_filename
    ) if check_var('ELEMENTAL_CMD', 'install');

    # Upload OS image
    upload_asset("$out_file", 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
