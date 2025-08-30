# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Packages: python3-docker & python3-podman
# Summary: Test podman & docker python packages
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest', -signatures;
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils;
use utils;
use containers::common qw(install_packages);
use containers::bats;

my $oci_runtime;

sub install_git {
    # We need git 2.47.0+ to use `--ours` with `git apply -3`
    if (is_sle) {
        my $version = get_var("VERSION");
        if (is_sle('<16')) {
            $version =~ s/-/_/;
            $version = "SLE_$version";
        }
        assert_script_run "zypper addrepo https://download.opensuse.org/repositories/Kernel:/tools/$version/Kernel:tools.repo";
    }
    assert_script_run "zypper --gpg-auto-import-keys -n install --allow-vendor-change git-core", timeout => 300;
}

sub setup {
    my @pkgs = qw(aardvark-dns apache2-utils buildah catatonit glibc-devel-static go1.24 gpg2 jq libgpgme-devel
      libseccomp-devel make netavark openssl podman podman-remote skopeo socat sudo systemd-container xfsprogs);
    push @pkgs, qw(criu libcriu2) if is_tumbleweed;
    $oci_runtime = get_var("OCI_RUNTIME", "runc");
    push @pkgs, $oci_runtime;

    install_packages(@pkgs);
    install_git;

    record_info "info", script_output("podman info -f json");

    # test/e2e/run_test.go expects catatonit to be installed in this path
    assert_script_run "cp /usr/bin/catatonit /usr/libexec/podman/catatonit";
    # rootless user needed for these tests
    assert_script_run "useradd -m containers";
    assert_script_run "usermod --add-subuids 100000-165535 containers";
    assert_script_run "usermod --add-subgids 100000-165535 containers";

    # Enable SSH
    my $algo = "ed25519";
    systemctl 'enable --now sshd';
    assert_script_run "ssh-keygen -t $algo -N '' -f ~/.ssh/id_$algo";
    assert_script_run "cat ~/.ssh/id_$algo.pub >> ~/.ssh/authorized_keys";
    assert_script_run "ssh-keyscan localhost 127.0.0.1 ::1 | tee -a ~/.ssh/known_hosts";

    # Download podman sources
    my $version = script_output q(podman --version | awk '{ print $3 }');
    record_info "version", $version;
    my $github_org = "containers";
    my $branch = "v$version";

    # Support these cases for GIT_REPO: [<GITHUB_ORG>]#BRANCH
    # 1. As GITHUB_ORG#TAG: github_user#test-patch
    # 2. As TAG only: main, v1.2.3, etc
    # 3. Empty. Use defaults specified above for $github_org & $branch
    my $repo = get_var("GIT_REPO", "");
    if ($repo =~ /#/) {
        ($github_org, $branch) = split("#", $repo, 2);
    } elsif ($repo) {
        $branch = $repo;
    }

    assert_script_run "cd ~";
    assert_script_run "git clone --branch $branch https://github.com/$github_org/podman", timeout => 300;
    assert_script_run "cd ~/podman";

    unless ($repo) {
        # - https://github.com/containers/podman/pull/26934 - test/e2e: fix 'block all syscalls' seccomp for runc
        # - https://github.com/containers/podman/pull/26936 - Skip some tests that fail on runc
        my @patches = qw(26934 26936);
        foreach my $patch (@patches) {
            my $url = "https://github.com/$github_org/podman/pull/$patch";
            record_info("patch", $url);
            assert_script_run "curl -O " . data_url("containers/patches/podman/$patch.patch");
            assert_script_run "git apply -3 --ours $patch.patch";
        }
    }
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    setup;

    my $quadlet = script_output "rpm -ql podman | grep podman/quadlet";

    my %env = (
        TESTFLAGS => "--junit-report=report.xml",
        PODMAN_BINARY => "/usr/bin/podman",
        PODMAN_REMOTE_BINARY => "/usr/bin/podman-remote",
        QUADLET_BINARY => "/usr/libexec/podman/quadlet",
        OCI_RUNTIME => $oci_runtime,
    );
    my $env = join " ", map { "$_=$env{$_}" } sort keys %env;

    foreach my $target (qw(localintegration remoteintegration)) {
        script_run "env $env make $target |& tee $target.txt", timeout => 1800;
        script_run qq{sed -ri '0,/name=/s/name="Libpod Suite"/name="$target"/' report.xml};
        script_run "mv -v report.xml $target.xml";
        parse_extra_log(XUnit => "$target.xml");
        upload_logs("$target.txt");
    }
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;
