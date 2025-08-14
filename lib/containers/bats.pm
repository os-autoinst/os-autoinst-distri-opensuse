# SUSE's openQA tests
#
# Copyright 2024-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Common functions for BATS test suites
# Maintainer: qa-c@suse.de

package containers::bats;

use base Exporter;
use Exporter;

use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use version_utils qw(is_sle is_tumbleweed);
use serial_terminal qw(select_user_serial_terminal select_serial_terminal);
use registration qw(add_suseconnect_product get_addon_fullname);
use bootloader_setup 'add_grub_cmdline_settings';
use power_action_utils 'power_action';
use List::MoreUtils qw(uniq);
use YAML::PP;
use File::Basename;
use Utils::Architectures qw(is_aarch64);

our @EXPORT = qw(
  bats_post_hook
  bats_setup
  bats_sources
  bats_tests
  run_command
  switch_to_root
  switch_to_user
);

my $curl_opts = "-sL --retry 9 --retry-delay 100 --retry-max-time 900";
my $test_dir = "/var/tmp/";
my $package;
my $settings;

# Subdirectory in repo containing BATS tests
my %tests_dir = (
    "aardvark-dns" => "test",
    buildah => "tests",
    netavark => "test",
    podman => "test/system",
    runc => "tests/integration",
    skopeo => "systemtest",
);

my @commands = ();

sub run_command {
    my $cmd = shift;
    my %args = testapi::compat_args(
        {
            timeout => 90,
        }, ['timeout'], @_);

    push @commands, $cmd;
    if ($cmd =~ / &$/) {
        $cmd =~ s/ \&$//;
        background_script_run $cmd, %args;
    } else {
        assert_script_run $cmd, %args;
    }
}

sub install_git {
    # We need git 2.47.0+ to use `--ours` with `git apply -3`
    if (is_sle) {
        my $version = get_var("VERSION");
        if (is_sle('<16')) {
            $version =~ s/-/_/;
            $version = "SLE_$version";
        }
        run_command "sudo zypper addrepo https://download.opensuse.org/repositories/Kernel:/tools/$version/Kernel:tools.repo";
    }
    run_command "sudo zypper --gpg-auto-import-keys -n install --allow-vendor-change git-core", timeout => 300;
}

sub install_ncat {
    # Upstream tests use Nmap's ncat but this is a problematic tool for multiple reasons:
    # - Behaviour breaks between versions. See https://nmap.org/changelog.html#7.96
    # - Nmap changed license and both Fedora & openSUSE won't ship new versions
    # Tumbleweed has ncat 7.95 and SLES 16.0 has 7.92. These versions are unlikely to change
    if (is_tumbleweed) {
        if (is_aarch64) {
            run_command "zypper addrepo http://download.opensuse.org/ports/aarch64/tumbleweed/repo/non-oss/ non-oss";
        } else {
            run_command "zypper addrepo http://download.opensuse.org/tumbleweed/repo/non-oss/ non-oss";
        }
    } elsif (is_sle('<16')) {
        # This repo has ncat 7.92.  Also unlikely to change
        run_command "zypper addrepo https://download.opensuse.org/repositories/network:/utilities/SLE_15/network:utilities.repo";
    }
    run_command "zypper --gpg-auto-import-keys -n install ncat";

    # Some tests use nc instead of ncat but expect ncat behaviour instead of netcat-openbsd
    run_command "ln -sf /usr/bin/ncat /usr/bin/nc";
    record_info("nc", script_output("nc --version"));
}

sub install_bats {
    my $bats_version = get_var("BATS_VERSION", "1.11.1");

    run_command "curl $curl_opts https://github.com/bats-core/bats-core/archive/refs/tags/v$bats_version.tar.gz | tar -zxf -";
    run_command "bash bats-core-$bats_version/install.sh /usr/local";
    run_command "rm -rf bats-core-$bats_version";

    run_command "mkdir -pm 0750 /etc/sudoers.d/";
    run_command "echo 'Defaults secure_path=\"/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin\"' > /etc/sudoers.d/usrlocal";
    assert_script_run "echo '$testapi::username ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/nopasswd";

    assert_script_run "curl -o /usr/local/bin/bats_skip_notok " . data_url("containers/bats/skip_notok.py");
    assert_script_run "chmod +x /usr/local/bin/bats_skip_notok";
}

sub configure_oci_runtime {
    my $oci_runtime = shift;

    return if (script_run("command -v podman") != 0);

    if (!$oci_runtime) {
        $oci_runtime = script_output("podman info --format '{{ .Host.OCIRuntime.Name }}'");
    }
    run_command "mkdir -p /etc/containers/containers.conf.d";
    run_command 'echo -e "[engine]\nruntime=\"' . $oci_runtime . '\"" > /etc/containers/containers.conf.d/engine.conf';
    record_info("OCI runtime", script_output("$oci_runtime --version"));
}

sub switch_to_root {
    select_serial_terminal;

    push @commands, "### RUN AS root";
    run_command "cd $test_dir";
}

sub switch_to_user {
    my $user = $testapi::username;

    if (script_run("grep $user /etc/passwd") != 0) {
        my $serial_group = script_output "stat -c %G /dev/$testapi::serialdev";
        assert_script_run "useradd -m -G $serial_group $user";
        assert_script_run "echo '${user}:$testapi::password' | chpasswd";
        ensure_serialdev_permissions;
    }

    assert_script_run "setfacl -m u:$user:r /etc/zypp/credentials.d/*" if is_sle;

    select_user_serial_terminal();
    push @commands, "### RUN AS user";
}

sub delegate_controllers {
    if (script_run("test -f /etc/systemd/system/user@.service.d/60-delegate.conf") != 0) {
        # Let user control cpu, io & memory control groups
        # https://susedoc.github.io/doc-sle/main/html/SLES-tuning/cha-tuning-cgroups.html#sec-cgroups-user-sessions
        run_command "mkdir -p /etc/systemd/system/user@.service.d/";
        run_command 'echo -e "[Service]\nDelegate=cpu cpuset io memory pids" > /etc/systemd/system/user@.service.d/60-delegate.conf';
        systemctl "daemon-reload";
    }
}

sub enable_modules {
    return if is_sle("16+");    # no modules on SLES16+

    add_suseconnect_product(get_addon_fullname('desktop'));
    add_suseconnect_product(get_addon_fullname('sdk'));
    add_suseconnect_product(get_addon_fullname('python3')) if is_sle('>=15-SP4');
}

sub patch_logfile {
    my ($log_file, @skip_tests) = @_;

    die "BATS failed!" if (script_run("test -e $log_file") != 0);

    @skip_tests = uniq sort @skip_tests;

    foreach my $test (@skip_tests) {
        next if (!$test);
        my $exp = "-e 'in test file.*/$test.bats'";
        # Sometimes bats lack the line above in podman remote tests
        # so we have to fetch the test number with another regexp
        if ($package eq "podman") {
            my ($number) = $test =~ /^(\d+)/;
            $exp .= " -e '^not ok [0-9]+ \\[$number\\]'";
        }
        if (script_run("grep -qE $exp $log_file") != 0) {
            record_info("PASS", $test);
        }
    }
    assert_script_run "bats_skip_notok $log_file " . join(' ', @skip_tests) if (@skip_tests);
}

sub fix_tmp {
    my $override_conf = <<'EOF';
[Unit]
ConditionPathExists=/var/tmp

[Mount]
What=/var/tmp
Where=/tmp
Type=none
Options=bind
EOF

    assert_script_run "mkdir -p /etc/systemd/system/tmp.mount.d/";
    write_sut_file('/etc/systemd/system/tmp.mount.d/override.conf', $override_conf);
}

sub bats_setup {
    my ($self, @pkgs) = @_;

    $package = get_required_var("BATS_PACKAGE");

    push @commands, "### RUN AS root";

    if (get_var("BATS_TEST_REPOS", "")) {
        if (script_run("zypper lr | grep -q SUSE_CA")) {
            run_command "zypper addrepo --refresh http://download.opensuse.org/repositories/SUSE:/CA/openSUSE_Tumbleweed/SUSE:CA.repo";
        }
        if (script_run("rpm -q ca-certificates-suse")) {
            run_command "zypper --gpg-auto-import-keys -n install ca-certificates-suse";
        }

        foreach my $repo (split(/\s+/, get_var("BATS_TEST_REPOS", ""))) {
            run_command "zypper addrepo $repo";
        }
    }

    foreach my $pkg (split(/\s+/, get_var("BATS_TEST_PACKAGES", ""))) {
        run_command "zypper --gpg-auto-import-keys --no-gpg-checks -n install $pkg";
    }

    install_bats;

    enable_modules if is_sle;

    my $install_ncat = 0;
    if (grep { $_ eq "ncat" } @pkgs) {
        $install_ncat = 1;
        @pkgs = grep { $_ ne "ncat" } @pkgs;
    }

    # Install tests dependencies
    my $oci_runtime = get_var("OCI_RUNTIME", "");
    if ($oci_runtime && !grep { $_ eq $oci_runtime } @pkgs) {
        push @pkgs, $oci_runtime;
    }
    run_command "zypper --gpg-auto-import-keys -n install @pkgs", timeout => 300;

    configure_oci_runtime $oci_runtime;

    install_ncat if $install_ncat;

    install_git;

    delegate_controllers;

    if (check_var("ENABLE_SELINUX", "0") && script_output("getenforce") eq "Enforcing") {
        record_info("Disabling SELinux");
        run_command "sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config";
        run_command "setenforce 0";
    } else {
        # Rebuild SELinux policies without the so-called "dontaudit" rules
        # https://en.opensuse.org/Portal:SELinux/Troubleshooting
        assert_script_run "semodule -DB || true";
    }

    # This is a workaround for https://bugzilla.suse.com/show_bug.cgi?id=1246227
    run_command "rm -vf /etc/containers/mounts.conf /usr/share/containers/mounts.conf" unless (is_sle(">=16") || is_tumbleweed);

    # Disable tmpfs from next boot
    if (script_output("findmnt -no FSTYPE /tmp", proceed_on_failure => 1) =~ /tmpfs/) {
        # Bind mount /tmp to /var/tmp
        fix_tmp;
    }

    # Switch to cgroup v2 if not already active
    if (script_run("test -f /sys/fs/cgroup/cgroup.controllers") != 0) {
        add_grub_cmdline_settings("systemd.unified_cgroup_hierarchy=1", update_grub => 1);
    }

    power_action('reboot', textmode => 1);
    $self->wait_boot();
    push @commands, "reboot";

    select_serial_terminal;

    assert_script_run "mount --make-rshared /tmp" if (script_run("findmnt -no FSTYPE /tmp") == 0);
}

sub collect_coredumps {
    script_run('coredumpctl list > coredumpctl.txt');

    # Get PID and executable for all dumps
    my @lines = split /\n/, script_output(q{coredumpctl --no-pager --no-legend | awk '$9 == "present" { print $5, $10 }'});

    foreach my $line (@lines) {
        my ($pid, $exe) = split /\s+/, $line;
        my $core = basename($exe) . ".$pid.core";

        # Dumping and compressing coredumps may take some time
        script_run("coredumpctl -o $core dump $pid", 300);
        script_run("gzip -v $core", 300);
    }
}

sub bats_post_hook {
    select_serial_terminal;

    my $log_dir = "/tmp/logs/";
    assert_script_run "mkdir -p $log_dir || true";
    assert_script_run "cd $log_dir";

    script_run "rm -rf $test_dir";

    collect_coredumps;
    script_run('df -h > df-h.txt');
    script_run('dmesg > dmesg.txt');
    script_run('findmnt > findmnt.txt');
    script_run('lsmod > lsmod.txt');
    script_run('rpm -qa | sort > rpm-qa.txt');
    script_run('sysctl -a > sysctl.txt');
    script_run('systemctl > systemctl.txt');
    script_run('systemctl status > systemctl-status.txt');
    script_run('systemctl list-unit-files > systemctl_units.txt');
    script_run('journalctl -b > journalctl-b.txt', timeout => 120);
    script_run('tar zcf containers-conf.tgz $(find /etc/containers /usr/share/containers -type f)');

    for my $ip_version (4, 6) {
        script_run("ip -$ip_version addr > ip$ip_version-addr.txt");
        script_run("ip -$ip_version route > ip$ip_version-route.txt");
    }
    script_run("iptables-save > iptables.txt");
    script_run("ip6tables-save > ip6tables.txt");
    script_run('nft list ruleset > nft.txt');

    # Remove all empty logs
    script_run "find $log_dir -type f -size 0 -exec rm -f {} +";

    my @logs = split /\s+/, script_output "ls";
    for my $log (@logs) {
        upload_logs($log_dir . $log);
    }

    upload_logs('/proc/config.gz');
    upload_logs('/var/log/audit/audit.log', log_name => "audit.txt");

    write_sut_file('/tmp/commands.txt', join("\n", @commands));
    upload_logs('/tmp/commands.txt');
}

sub bats_tests {
    my ($log_file, $_env, $skip_tests) = @_;
    my %env = %{$_env};

    my $tmp_dir = script_output "mktemp -du -p /var/tmp test.XXXXXX";
    run_command "mkdir -p $tmp_dir";

    $env{BATS_TMPDIR} = $tmp_dir;
    $env{TMPDIR} = $tmp_dir if ($package eq "buildah");
    $env{PATH} = '/usr/local/bin:$PATH:/usr/sbin:/sbin';
    my $env = join " ", map { "$_=$env{$_}" } sort keys %env;

    my @tests;
    foreach my $test (split(/\s+/, get_var("BATS_TESTS", ""))) {
        $test .= ".bats" unless $test =~ /\.bats$/;
        push @tests, "$tests_dir{$package}/$test";
    }
    my $tests = @tests ? join(" ", @tests) : $tests_dir{$package};

    my $cmd = "env $env bats --tap -T $tests";
    # With podman we must use its own hack/bats instead of calling bats directly
    if ($package eq "podman") {
        my $args = ($log_file =~ /root/) ? "--root" : "--rootless";
        $args .= " --remote" if ($log_file =~ /remote/);
        $cmd = "env $env hack/bats -t -T $args";
        $cmd .= " $tests" if ($tests ne $tests_dir{podman});
    }
    $cmd .= " | tee -a $log_file";

    my $version = script_output "rpm -q --queryformat '%{VERSION} %{RELEASE}' $package";
    my $os_version = join(' ', get_var("DISTRI"), get_var("VERSION"), get_var("BUILD"), get_var("ARCH"));

    run_command "echo $log_file .. > $log_file";
    run_command "echo '# $package $version $os_version' >> $log_file";
    push @commands, $cmd;
    my $ret = script_run($cmd, timeout => 7000);

    unless (get_var("BATS_TESTS")) {
        $skip_tests = get_var($skip_tests, $settings->{$skip_tests});
        my @skip_tests = split(/\s+/, join(' ', get_var('BATS_SKIP', $settings->{BATS_SKIP}), $skip_tests));
        patch_logfile($log_file, @skip_tests);
    }

    parse_extra_log(TAP => $log_file);

    run_command "sudo rm -rf $tmp_dir || true";

    return ($ret);
}

sub bats_settings {
    my $os_version = get_required_var("DISTRI") . "-" . get_required_var("VERSION");

    assert_script_run "curl -o /tmp/skip.yaml " . data_url("containers/bats/skip.yaml");
    my $text = script_output("cat /tmp/skip.yaml", quiet => 1);
    my $yaml = YAML::PP->new()->load_string($text);

    return $yaml->{$package}{$os_version};
}

sub bats_sources {
    my $version = shift;
    $settings = bats_settings;

    my $github_org = ($package eq "runc") ? "opencontainers" : "containers";
    my $branch = "v$version";

    # Support these cases for BATS_REPO: [<GITHUB_ORG>]#BRANCH
    # 1. As GITHUB_ORG#TAG: SUSE#suse-v4.9.5, your_gh_user#test-patch, etc
    # 2. As TAG only: main, v1.2.3, etc
    # 3. Empty. Use default for repo based on package version

    my $repo = get_var("BATS_REPO", "");
    if ($repo =~ /#/) {
        ($github_org, $branch) = split("#", $repo, 2);
    } elsif ($repo) {
        $branch = $repo;
    }

    run_command "cd $test_dir";
    run_command "git clone https://github.com/$github_org/$package.git", timeout => 300;
    $test_dir .= $package;
    run_command "cd $test_dir";
    run_command "git checkout $branch";

    # We use BATS_PATCHES="none" to specify that we don't want to patch anything
    unless (check_var("BATS_PATCHES", "none")) {
        my @patches = split(/\s+/, get_var("BATS_PATCHES", ""));
        if (!@patches && defined $settings->{BATS_PATCHES}) {
            @patches = @{$settings->{BATS_PATCHES}};
        }

        foreach my $patch (@patches) {
            my $url = ($patch =~ /^\d+$/) ? "https://github.com/$github_org/$package/pull/$patch.patch" : $patch;
            record_info("patch", $url);
            if ($patch =~ /^\d+$/) {
                push @commands, "curl $curl_opts -O $url";
                assert_script_run "curl -O " . data_url("containers/bats/patches/$package/$patch.patch");
            } else {
                run_command "curl $curl_opts -O $url", timeout => 900;
            }
            # Some patches (e.g., podman's 25942) fail to apply cleanly due to missing files so
            # try `git apply` first and if it fails use `--include` to restrict the patch scope
            # to the package tests directory.  Remove this when `git-apply` has a new option to
            # ignore missing files.
            my $file = basename($url);
            my $apply_cmd = "git apply -3 --ours $file";
            $apply_cmd .= " || git apply -3 --ours --include '$tests_dir{$package}/*' $file";
            run_command $apply_cmd;
        }
    }

    if ($package eq "podman") {
        my $hack_bats = "https://raw.githubusercontent.com/containers/podman/refs/heads/main/hack/bats";
        run_command "curl $curl_opts -o hack/bats $hack_bats";
    }
}

1;
