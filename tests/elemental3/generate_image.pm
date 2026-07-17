# Copyright 2023-2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test Elemental container image
#   This image is used as a base to build an Elemental container image.
#   Then, that image will be used to build a Host OS on top, so
#   it includes the kernel, firmware, bootloader, etc.
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use Mojo::Base 'opensusebasetest';
use testapi;
use elemental3;
use transactional qw(trup_call);
use package_utils qw(install_package);
use serial_terminal qw(select_serial_terminal);
use Mojo::File qw(path);
use utils qw(file_content_replace);

=head2 build_installer_cmd

 build_installer_cmd( config_dir => <value>, image => <value>, img_filename => <value>,
                      rootpwd => <value>, timeout => <value>, type => <value> );

Create an OS image with `build-installer` command by using the specified
containerized OS image.

=cut

sub build_installer_cmd {
    my (%args) = @_;
    my $krnlcmdline = get_required_var('KERNEL_CMD_LINE');
    my $isocmdline = get_var('ISO_CMD_LINE');
    my $config_file = "$args{config_dir}/config.sh";
    my $iso_config_file = "$args{config_dir}/config-iso.sh";
    my $device = get_var('INSTALL_DISK', '/dev/vda');

    # Configure the systemd sysexts
    my $overlay_dir =
      get_sysext(tmpdir => $args{config_dir}, timeout => $args{timeout});

    # OS configuration script
    assert_script_run("curl -sf -o $config_file "
          . data_url('elemental3/' . path($config_file)->basename));
    file_content_replace(
        $config_file,
        '--sed-modifier' => 'g',
        '%TEST_PASSWORD%' => $args{rootpwd}
    );
    assert_script_run("chmod 755 $config_file");

    # ISO configuration script
    assert_script_run("curl -sf -o $iso_config_file "
          . data_url('elemental3/' . path($iso_config_file)->basename));
    assert_script_run("chmod 755 $iso_config_file");

    record_info('ISO', 'Generate and upload ISO image');

    # Generate OS image
    assert_script_run(
"elemental3ctl --debug build-installer --type $args{type} --output . --name $args{img_filename} --os-image $args{image} --cmdline '$isocmdline' --config $iso_config_file --install-overlay dir://$overlay_dir --install-config $config_file --install-cmdline '$krnlcmdline' --install-target $device",
        timeout => $args{timeout}
    );

    # Return ISO image
    return ("$args{img_filename}.iso");
}

=head2 customize_cmd

 customize_cmd( config_dir => <value>, elemental3_uri => <value>, hddsize => <value>,
                k8s => <value>, manifest_uri => <value>, rootpwd => <value>,
                template => <value>, timeout => <value> );

Create an OS image with `customize` command by using the specified
release-manifest.

=cut

# Encode Internal SUSE CA:
# base64 -w0 /usr/share/pki/trust/anchors/SUSE_Trust_Root.crt.pem

# Extract files/subdirs from a directory
# assert_script_run 'curl ' . data_url('console/ansible/') . ' | cpio -id';

sub customize_cmd {
    my (%args) = @_;
    my $crypto_policy = get_var('CRYPTO_POLICY');
    my $device = get_var('INSTALL_DISK', '/dev/vda');
    my $krnlcmdline = get_required_var('KERNEL_CMD_LINE');
    my $type = get_required_var('IMAGE_TYPE');
    my $initial_hddsize = '4';
    my $out = "$args{img_filename}.iso";

    # Download build configuration files
    assert_script_run("cd $args{config_dir}");
    assert_script_run('curl ' . data_url("elemental3/templates/$args{template}/") . ' | cpio -ivd');

    # Redefine configuration path
    $args{config_dir} .= "/data";

    # Add 'oci://' in release-manifest URI if nothing is set
    $args{manifest_uri} = 'oci://' . $args{manifest_uri}
      unless $args{manifest_uri} =~ /:\/\//;

    # Configure the build
    $out = "$args{img_filename}.qcow2" if ($type =~ m/raw/);
    file_content_replace(
        "$args{config_dir}/butane.yaml",
        '--sed-modifier' => 'g',
        '%TEST_PASSWORD%' => $args{rootpwd},
        '%K8S%' => $args{k8s}
    );
    file_content_replace(
        "$args{config_dir}/install.yaml",
        '--sed-modifier' => 'g',
        '%CRYPTO_POLICY%' => $crypto_policy,
        '%HDDSIZE%' => $initial_hddsize,
        '%INSTALL_DISK%' => $device,
        '%KERNEL_CMD_LINE%' => $krnlcmdline
    );
    file_content_replace(
        "$args{config_dir}/release.yaml",
        '--sed-modifier' => 'g',
        '%RELEASE_MANIFEST_URI%' => $args{manifest_uri},
        '%K8S%' => $args{k8s}
    );
    if (check_var('TESTED_CMD', 'customize_recovery')) {
        file_content_replace(
            "$args{config_dir}/custom/scripts/50-firstboot.sh",
            '--sed-modifier' => 'g',
            '%INSTALL_DISK%' => $device,
        );
    }

    if (get_var('CLUSTER_TYPE') =~ /(singlenode|multinode)/) {
        # K8s configuration file
        assert_script_run(
            "curl -sf -o $args{config_dir}/kubernetes/cluster.yaml "
              . data_url('elemental3/cluster.yaml'));

        # For single-node
        if (check_var('CLUSTER_TYPE', 'singlenode')) {
            # Keep configuration for first node only
            assert_script_run(
                "sed -i -e '/^nodes:/,/^network:/d' -e '/apiVIP:.*/i network:' $args{config_dir}/kubernetes/cluster.yaml"
            );
        }
    }
    else {
        # Only useful for the single-node and multi-node tests
        assert_script_run("rm -rf $args{config_dir}/network");
        assert_script_run(
            "sed -i '/name: k8s-preinstall.service/,\$d' $args{config_dir}/butane.yaml"
        );
    }

    # Generate OS image
    elemental3_cmd(
        config_dir => $args{config_dir},
        cmd => "--debug customize --type $type --output /config/uc_image.$type",
        uri => $args{elemental3_uri},
        timeout => $args{timeout}
    );

    # Convert RAW to QCOW2 if needed
    # NOTE: './' is needed in front of $out as the filename contains a ':' in it
    if ($type =~ m/raw/) {
        assert_script_run(
            "qemu-img convert -p -f raw -O qcow2 $args{config_dir}/uc_image.$type ./$out",
            timeout => $args{timeout}
        );

        # Extend HDD image to needed size
        assert_script_run("qemu-img resize ./$out $args{hddsize}G",
            timeout => $args{timeout});
    }
    elsif ($type =~ m/iso/) {
        assert_script_run("mv $args{config_dir}/uc_image.$type '$out'");
    }

    # Return OS image
    return ($out);
}

=head2 extract_iso

 extract_iso( image=> <value>, img_filename => <value>, iso = <value>, timeout => <value> );

Extract ISO image from container.

=cut

sub extract_iso {
    my (%args) = @_;

    my $runtime = get_required_var('CONTAINER_RUNTIMES');
    my $out = "$args{img_filename}.iso";

    assert_script_run("$runtime pull $args{image}");
    my $run_id = script_output("$runtime run -d $args{image}");
    assert_script_run("$runtime cp ${run_id}:/iso/$args{iso} .");
    assert_script_run("mv $args{iso} '$out'");

    # Return OS image
    return ($out);
}

=head2 install_cmd

 install_cmd( hddsize => <value>, config_dir => <value>, image => <value>,
              img_filename => <value>, rootpwd => <value>, timeout => <value> );

Create an OS image with `install` command by using the specified
containerized OS image.

=cut

sub install_cmd {
    my (%args) = @_;

    #my $image       = get_required_var('CONTAINER_IMAGE_TO_TEST');
    my $krnlcmdline = get_required_var('KERNEL_CMD_LINE');
    my $config_file = "$args{config_dir}/config.sh";
    my $device = '/dev/nbd0';

    # Configure the systemd sysexts
    my $overlay_dir =
      get_sysext(tmpdir => $args{config_dir}, timeout => $args{timeout});

    # OS configuration script
    assert_script_run("curl -sf -o $config_file "
          . data_url('elemental3/' . path($config_file)->basename));
    file_content_replace(
        $config_file,
        '--sed-modifier' => 'g',
        '%TEST_PASSWORD%' => $args{rootpwd}
    );
    assert_script_run("chmod 755 $config_file");

    record_info('QCOW2', 'Generate and upload QCOW2 image');

    # Create a raw image and mount it
    assert_script_run(
        "qemu-img create -f qcow2 $args{config_dir}/$args{img_filename}.qcow2 $args{hddsize}G"
    );
    assert_script_run('modprobe nbd');
    assert_script_run(
        "qemu-nbd -c $device $args{config_dir}/$args{img_filename}.qcow2");

    # Generate OS image
    assert_script_run(
        "elemental3ctl --debug install --cmdline '$krnlcmdline' --os-image $args{image} --overlay dir://$overlay_dir --config $config_file --target $device",
        timeout => $args{timeout},
    );

    # Return HDD image
    return ("$args{config_dir}/$args{img_filename}.qcow2");
}

sub run {
    my $arch = get_required_var('ARCH');
    my $k8s = get_required_var('K8S');
    my $hddsize = get_var('HDDSIZEGB', '30');
    my $rootpwd = get_required_var('TEST_PASSWORD');
    my $img_filename = get_required_var('IMG_NAME');
    my $totest_path = get_required_var('TOTEST_PATH');
    my $template = get_var('TEMPLATE', 'default');
    my $timeout = 900;
    my $out_file;

    # Clean image filename (useful for cloned jobs)
    $img_filename =~ tr/\/#/_/;

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # NOTE: there is not enough space on /tmp, so we need to change TMPDIR.
    my $tmpdir = '/root/tmp';
    assert_script_run("mkdir -m 1777 -p $tmpdir && export TMPDIR=$tmpdir");

    # Add Unified Core repository and install elemental3ctl package
    # (we still need this one for now)
    my $pkgs = 'squashfs mtools xorriso';
    unless (check_var('TESTED_CMD', 'customize')) {
        # We need to add elemental3ctl package
        trup_call(
            "run zypper addrepo --check --refresh ${totest_path}/standard elemental"
        );
        trup_call('--continue run zypper --gpg-auto-import-keys refresh');
        $pkgs .= ' elemental3ctl';
    }
    install_package($pkgs, trup_apply => 1, trup_continue => 1);

    # Use a crypted password
    my $hashpwd = script_output("openssl passwd -6 $rootpwd");

    # Create HDD image with different commands
    if (check_var('TESTED_CMD', 'install')
        || check_var('TESTED_CMD', 'build_installer_iso'))
    {
        my $kernel_type = get_required_var('KERNEL_TYPE');
        my $kernel = "base-os-kernel-$kernel_type-";
        my $uri = get_container_uri(
            url => $totest_path,
            arch => $arch,
            regex => ".*${kernel}\([0-9]*\\..*\)-\(.*\)"
        );

        $out_file = install_cmd(
            arch => $arch,
            config_dir => $tmpdir,
            hddsize => $hddsize,
            image => $uri,
            img_filename => $img_filename,
            rootpwd => $hashpwd,
            timeout => $timeout,
        ) if (check_var('TESTED_CMD', 'install'));

        $out_file = build_installer_cmd(
            config_dir => $tmpdir,
            image => $uri,
            img_filename => $img_filename,
            rootpwd => $hashpwd,
            timeout => $timeout,
            type => 'iso'
        ) if (check_var('TESTED_CMD', 'build_installer_iso'));
    }

    if (check_var('TESTED_CMD', 'customize')
        || check_var('TESTED_CMD', 'customize_recovery'))
    {
        my $k8s = get_required_var('K8S');
        my $k8s_version_prefix = get_required_var('K8S_VERSION_PREFIX');
        my $uri = get_container_uri(
            url => $totest_path,
            arch => $arch,
            regex =>
              ".*${k8s}-manifest-\(${k8s_version_prefix}\\.[0-9]*\)-\(.*\)"
        );

        my $elemental3_uri = get_container_uri(
            url => $totest_path,
            arch => $arch,
            regex => ".*elemental-\([0-9]\\..*\)-\(.*\)"
        );

        $out_file = customize_cmd(
            config_dir => $tmpdir,
            elemental3_uri => $elemental3_uri,
            hddsize => $hddsize,
            img_filename => $img_filename,
            k8s => $k8s,
            manifest_uri => $uri,
            rootpwd => $hashpwd,
            template => $template,
            timeout => $timeout
        );
    }

    if (check_var('TESTED_CMD', 'extract_iso')) {
        my $kernel_type = get_required_var('KERNEL_TYPE');
        my $kernel = "base-os-kernel-$kernel_type-iso-";
        my $uri = get_container_uri(
            url => $totest_path,
            arch => $arch,
            regex => ".*${kernel}\([0-9]*\\..*\)-\(.*\)"
        );

        my ($fn, $version, $build) = get_values(
            url => "${totest_path}/containers",
            arch => $arch,
            regex => ".*${kernel}\([0-9]*\\..*\)-\(.*\)"
        );
        $kernel =~ s/-$//;

        $out_file = extract_iso(
            image => $uri,
            img_filename => $img_filename,
            iso => "${kernel}.${arch}-${version}-Build${build}.iso",
            timeout => $timeout
        );
    }

    # Upload OS image
    upload_asset("$out_file", 1);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
