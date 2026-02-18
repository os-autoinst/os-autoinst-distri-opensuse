# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: containerd
# Summary: Upstream containerd tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest', -signatures;
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils;
use utils;
use Utils::Architectures;
use File::Basename;
use containers::bats;

my $version;

sub setup {
    my $self = shift;
    my @pkgs = qw(containerd containerd-ctr go1.25 make xfsprogs);
    push @pkgs, qw(cni-plugins cri-tools) unless is_sle;
    $self->setup_pkgs(@pkgs);
    install_gotestsum;

    run_command "systemctl enable --now containerd";
    record_info "containerd status", script_output("systemctl status containerd");
    record_info "containerd config", script_output("containerd config dump");

    $version = script_output q(containerd --version | awk '{ print $3 }');
    record_info "containerd version", $version;

    patch_sources "containerd", $version, "integration";

    run_command "make bin/runc-fp";
    run_command "cp bin/runc-fp /usr/local/bin";
    run_command "cd integration/client";
    run_command "go mod download";
}

sub critest {
    run_command "echo 'runtime-endpoint: unix:///run/containerd/containerd.sock' > /etc/crictl.yaml";
    my $url = "https://github.com/cri-o/cri-o/raw/refs/heads/main/contrib/cni/11-crio-ipv4-bridge.conflist";
    run_command "curl -sL $url | tee /etc/cni/net.d/" . basename($url);

    run_command "containerd config default | tee /etc/containerd/config.toml";
    # cni-plugins are installed in /usr/libexec/cni instead of /opt/cni
    run_command q(sed -i 's,bin_dir =.*,bin_dir = "/usr/libexec/cni",' /etc/containerd/config.toml);

    # Workaround for https://bugzilla.opensuse.org/show_bug.cgi?id=1257963
    if (script_output("crictl info -o go-template --template '{{.config.enableSelinux}}'") ne "true") {
        run_command "sed -i 's/selinux = false/selinux = true/' /etc/containerd/config.toml";
    }

    run_command "systemctl restart containerd";
    record_info "crictl info", script_output("crictl info");

    run_command "critest --ginkgo.junit-report critest.xml |& tee critest.txt", timeout => 300;

    my @xfails = (
        # https://github.com/kubernetes-sigs/cri-tools/issues/1029
"CRI validation::[It] [k8s.io] Networking runtime should support networking runtime should support port mapping with host port and container port [Conformance]",
        # https://github.com/containerd/containerd/issues/4460
        "CRI validation::[It] [k8s.io] Security Context NamespaceOption runtime should support HostIpc is true",
    );

    patch_junit "containerd", $version, "critest.xml", @xfails;

    parse_extra_log(XUnit => "critest.xml", timeout => 180);
    upload_logs("critest.txt");
}

sub run {
    my $self = shift;
    select_serial_terminal;
    $self->setup;
    select_serial_terminal;

    run_command "gotestsum --junitfile containerd.xml --format standard-verbose ./... -- -v -test.root |& tee containerd.txt", timeout => 600;
    upload_logs("containerd.txt");

    my @xfails = (
        "github.com/containerd/containerd/integration/client::TestImagePullSchema1",
    );

    patch_junit "containerd", $version, "containerd.xml", @xfails;
    parse_extra_log(XUnit => "containerd.xml", timeout => 180);

    critest unless is_sle;
}

sub cleanup {
    script_run "rm -f /usr/local/bin/runc-fp";
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup;
    bats_post_hook;
}

sub post_run_hook {
    my ($self) = @_;
    cleanup;
    bats_post_hook;
}

1;
