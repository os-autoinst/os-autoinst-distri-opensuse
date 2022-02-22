# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: engine subclass for containerd with nerdctl specific implementations
# Maintainer: qac team <qa-c@suse.de>

package containers::containerd_nerdctl;
use Mojo::Base 'containers::engine';
use testapi;
use containers::common 'install_containerd_when_needed';
use containers::utils 'registry_url';
has runtime => 'nerdctl';

sub init {
    install_containerd_when_needed();

    # The nerdctl validation test suite is a plug-in required for this test and needs to be installed from an external source.
    my $version = get_var('CONTAINERS_NERDCTL_VERSION', '0.16.1');
    my $url = "https://github.com/containerd/nerdctl/releases/download/v$version/nerdctl-$version-linux-amd64.tar.gz";
    my $filename = "/tmp/nerdctl-$version-linux-amd64.tar.gz";
    assert_script_run("curl -L $url -o $filename");
    assert_script_run("tar zxvf $filename -C /usr/local/bin");
    assert_script_run("rm $filename");
    assert_script_run('nerdctl');
}

1;
