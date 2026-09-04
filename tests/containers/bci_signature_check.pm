# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Checks the container signature
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'consoletest';
use XML::LibXML;
use utils qw(zypper_call script_retry systemctl);
use version_utils qw(get_os_release is_sle);
use db_utils qw(push_image_data_to_db);
use containers::common;
use testapi;
use serial_terminal 'select_serial_terminal';
use containers::helm;
use containers::k8s qw(install_k3s install_helm);
use transactional qw(trup_call reboot_on_changes);

sub run {
    select_serial_terminal;
    my $engines = get_required_var('CONTAINER_RUNTIMES');
    my $engine;
    if ($engines =~ /podman|k3s/) {
        $engine = 'podman';
    } elsif ($engines =~ /docker/) {
        $engine = 'docker';
    } else {
        die('No valid container engines defined in CONTAINER_RUNTIMES variable!');
    }

    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');

    # cosign 2.5 is build upon registry.suse.com/bci/bci-micro:15.7
    # works with power8 and power10
    # cosign 3 requires only power9+
    my $tag = check_var('MACHINE', 'ppc64le-p8-virtio') ? '2.5' : 'latest';
    my $cosign_image = "registry.suse.com/suse/cosign:$tag";

    my $engine_options = "-v /usr/share/pki/trust/anchors/SUSE_Trust_Root.crt.pem:/SUSE_Trust_Root.crt.pem:ro";
    my $options = "--key /usr/share/pki/containers/suse-container-key.pem";
    if ($image =~ "registry.suse.de") {
        $options .= " --registry-cacert=/SUSE_Trust_Root.crt.pem";    # include SUSE CA for registry.suse.de
        $options .= " --insecure-ignore-tlog=true";    # ignore missing transparency log entries for registry.suse.de
    }

    script_retry("$engine pull -q $image", timeout => 300, delay => 60, retry => 2);
    assert_script_run("$engine run --rm -q $engine_options $cosign_image verify $options $image", timeout => 300);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
