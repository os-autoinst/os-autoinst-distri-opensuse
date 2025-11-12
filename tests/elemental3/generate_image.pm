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

sub run {
    my $arch = get_required_var('ARCH');
    my $build = get_required_var('BUILD');
    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');
    my $repo_to_test = get_required_var('REPO_TO_TEST');
    my $rootpwd = get_required_var('TEST_PASSWORD');
    my $sysext_path = get_required_var('SYSEXT_PATH');
    my $k8s = get_required_var('K8S');
    my $hdd_size = get_var('HDDSIZEGB', '30');
    my $img_filename = "elemental-$build-$arch.qcow2";
    my $shared_dir = '/root/shared';
    my $config_file = "$shared_dir/config.sh";
    my $sysext_root = "$shared_dir/sysexts";
    my $sysext_dir = "$sysext_root/etc/extensions";
    my $overlay = "$shared_dir/sysexts.tar.gz";
    my $device = '/dev/nbd0';
    my $sysext_arch;
    my $rke2_sysext_found;
    my @sysexts;

    # Clean image filename (useful for cloned jobs)
    $img_filename =~ tr/\/#/_/;

    # Define timeouts based on the architecture
    my $timeout = (is_aarch64) ? 480 : 240;

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # Create directories
    assert_script_run("mkdir -p $sysext_dir");

    # Add Unified Core repository and install Elemental package
    trup_call("run zypper addrepo --check --refresh $repo_to_test elemental");
    trup_call('--continue run zypper --gpg-auto-import-keys refresh');
    trup_call('--continue pkg install elemental3ctl');
    trup_call('apply');

    # OS configuration script
    assert_script_run(
        "curl -v -o $config_file "
          . data_url('elemental3/' . path($config_file)->basename)
    );
    file_content_replace($config_file, '%TEST_PASSWORD%' => $rootpwd, '%K8S%' => $k8s);
    assert_script_run("chmod 755 $config_file");

    # Define architecture for the system extensions
    $sysext_arch = 'arm64' if ($arch eq 'aarch64');
    $sysext_arch = 'x86-64' if ($arch eq 'x86_64');

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
        # RKE2 is hard-coded but for now we don't support anything else
        if ($_ =~ /rke2/) {

            # Keep only the first RKE2 version found (the lower version)
            # Higher versions can be used in another upgrade test
            next if $rke2_sysext_found;
            $rke2_sysext_found = 1;
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

    record_info('QCOW2', 'Generate and upload QCOW2 image');

    # Create a raw image and mount it
    assert_script_run("qemu-img create -f qcow2 $shared_dir/$img_filename ${hdd_size}G");
    assert_script_run('modprobe nbd');
    assert_script_run("qemu-nbd -c $device $shared_dir/$img_filename");

    # Set SELinux in permissive mode, as there is an issue with enforcing mode and Elemental3 doesn't support it yet
    assert_script_run("setenforce permissive");

    # Generate OS image
    assert_script_run(
        "elemental3ctl --debug install --os-image $image --overlay tar://$overlay --config $config_file --target $device",
        $timeout
    );

    # Upload QCOW2 image
    upload_asset("$shared_dir/$img_filename", 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
