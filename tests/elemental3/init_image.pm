# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test 'elemental3 init' command
#   Create a default configuration with 'elemental3 init', change only the
#   values that the test environment needs, then build an OS image from it
#   with 'elemental3 customize'. The image is uploaded to be booted later.
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use Mojo::Base 'opensusebasetest';
use testapi;
use elemental3;
use serial_terminal qw(select_serial_terminal);
use utils qw(file_content_replace);

my $tmpdir = '/root/tmp';
my $config_dir = "$tmpdir/config";

sub run {
    my $arch = get_required_var('ARCH');
    my $totest_path = get_required_var('TOTEST_PATH');
    my $k8s = get_required_var('K8S');
    my $k8s_prefix = get_required_var('K8S_VERSION_PREFIX');
    my $krnlcmdline = get_required_var('KERNEL_CMD_LINE');
    my $type = get_required_var('IMAGE_TYPE');
    my $crypto_policy = get_var('CRYPTO_POLICY');
    my $device = get_var('INSTALL_DISK', '/dev/vda');
    my $hddsize = get_var('HDDSIZEGB', '30');
    my $timeout = 900;

    # Clean image filename (useful for cloned jobs)
    (my $img_filename = get_required_var('IMG_NAME')) =~ tr/\/#/_/;

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # NOTE: there is not enough space on /tmp, so we need to change TMPDIR.
    assert_script_run("mkdir -m 1777 -p $tmpdir && export TMPDIR=$tmpdir && cd $tmpdir");

    my $elemental3 = get_artifact_uri(url => $totest_path, arch => $arch,
        regex => ".*elemental-\([0-9]\\..*\)-\(.*\)");
    my $manifest = get_artifact_uri(url => $totest_path, arch => $arch,
        regex => ".*${k8s}-manifest-\(${k8s_prefix}\\.[0-9]*\)-\(.*\)");
    $manifest = "oci://$manifest" unless ($manifest =~ m|://|);

    # Create the default configuration
    record_info('INIT', 'Create default configuration with elemental3 init');
    elemental3_cmd(config_dir => $config_dir, uri => $elemental3,
        cmd => '--debug init --target-dir /config');
    assert_script_run("test -s $config_dir/$_") foreach (qw(install.yaml release.yaml butane.yaml));
    assert_script_run("grep -q '^schema: v0' $config_dir/install.yaml");
    script_run("tail -n +1 $config_dir/*.yaml");

    # Change only the values that the test environment needs.
    # NOTE: the raw disk is extended to $hddsize after the build.
    my %install = (
        'kernelCmdLine:.*' => "kernelCmdLine: \"$krnlcmdline\"",
        'diskSize:.*' => 'diskSize: 4G',
        'device:.*' => "device: $device"
    );
    $install{'cryptoPolicy:.*'} = "cryptoPolicy: $crypto_policy" if ($crypto_policy);
    file_content_replace("$config_dir/install.yaml", %install);

    my $hashpwd = script_output('openssl passwd -6 ' . get_required_var('TEST_PASSWORD'));
    file_content_replace("$config_dir/butane.yaml", 'password_hash:.*' => "password_hash: \"$hashpwd\"");

    # The generated Helm charts and Kubernetes cluster use example values
    # that cannot work. Remove them to get a Linux-only image.
    assert_script_run("echo 'manifestURI: $manifest' > $config_dir/release.yaml");
    assert_script_run("rm -f $config_dir/kubernetes/cluster.yaml");

    # Generate OS image
    record_info('ISO/RAW', 'Generate and upload image');
    elemental3_cmd(config_dir => $config_dir, uri => $elemental3, timeout => $timeout,
        cmd => "--debug customize --type $type --output /config/uc_image.$type");

    # NOTE: './' is needed in front of the filename as it can contain a ':'
    my $out = "$img_filename.iso";
    if ($type eq 'raw') {
        $out = "$img_filename.qcow2";
        assert_script_run("qemu-img convert -p -f raw -O qcow2 $config_dir/uc_image.raw ./$out", timeout => $timeout);
        assert_script_run("qemu-img resize ./$out ${hddsize}G", timeout => $timeout);
    } else {
        assert_script_run("mv $config_dir/uc_image.$type './$out'");
    }

    upload_asset($out, 1);
}

sub post_fail_hook {
    my ($self) = @_;

    # Upload the configuration files for debugging
    my $files = script_output("find $config_dir -name '*.yaml'", proceed_on_failure => 1);
    upload_logs($_, failok => 1) foreach (split(/\n/, $files));
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
