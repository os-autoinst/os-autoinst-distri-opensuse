# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: engine subclass for containerd with crictl specific implementations
# Maintainer: qac team <qa-c@suse.de>

package containers::containerd_crictl;
use Mojo::Base 'containers::engine';
use testapi;
use containers::common 'install_containerd_when_needed';
use containers::utils 'registry_url';
use utils qw(zypper_call);
use version_utils qw(is_leap is_sle);
use Utils::Architectures;
has runtime => 'crictl';

sub init {
    install_containerd_when_needed();

    unless (is_sle || is_leap) {
        zypper_call("in cri-tools");
    } else {
        # The crictl validation test suite is a plug-in required for this test and needs to be installed from an external source.
        my $version = get_var('CONTAINERS_CRICTL_VERSION', 'v1.23.0');
        my $arch;
        if (is_aarch64) {
            $arch = 'arm64';
        } elsif (is_x86_64) {
            $arch = 'amd64';
        } else {
            die 'Architecture ' . get_required_var('ARCH') . ' is not supported';
        }
        my $url = "https://github.com/kubernetes-sigs/cri-tools/releases/download/$version/crictl-$version-linux-$arch.tar.gz";
        my $filename = "/tmp/crictl-$version-linux-$arch.tar.gz";
        assert_script_run("curl -L $url -o $filename");
        assert_script_run("tar zxvf $filename -C /usr/local/bin");
        assert_script_run("rm $filename");
    }
    assert_script_run "curl " . data_url('containers/crictl.yaml') . " -o /etc/crictl.yaml";
    assert_script_run('crictl info');
}

1;
