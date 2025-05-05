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
use Utils::Architectures 'is_aarch64';
use bootloader_setup 'add_grub_cmdline_settings';
use power_action_utils 'power_action';
use List::MoreUtils qw(uniq);
use containers::common qw(install_packages);

our @EXPORT = qw(
  bats_patches
  bats_post_hook
  bats_setup
  bats_sources
  bats_tests
  run_command
  switch_to_root
  switch_to_user
);

my $curl_opts = "-sL --retry 9 --retry-delay 100 --retry-max-time 900";
my $test_dir = "/var/tmp/bats-tests";

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

sub install_ncat {
    return if (script_run("rpm -q ncat") == 0);

    my $version = "SLE_15";
    if (is_sle('<15-SP6')) {
        $version = get_required_var("VERSION");
        $version =~ s/-/_/g;
        $version = "SLE_" . $version;
    } elsif (is_tumbleweed || is_sle('>=16')) {
        $version = "openSUSE_Factory";
        $version .= "_ARM" if (is_aarch64);
    }

    my $repo = "https://download.opensuse.org/repositories/network:/utilities/$version/network:utilities.repo";

    my @cmds = (
        "zypper addrepo $repo",
        "zypper --gpg-auto-import-keys -n install ncat",
        "ln -sf /usr/bin/ncat /usr/bin/nc"
    );
    foreach my $cmd (@cmds) {
        run_command $cmd;
    }
}

sub install_bats {
    return if (script_run("command -v bats") == 0);

    my $bats_version = get_var("BATS_VERSION", "1.11.1");

    run_command "curl $curl_opts https://github.com/bats-core/bats-core/archive/refs/tags/v$bats_version.tar.gz | tar -zxf -";
    run_command "bash bats-core-$bats_version/install.sh /usr/local";
    run_command "rm -rf bats-core-$bats_version";

    run_command "mkdir -pm 0750 /etc/sudoers.d/";
    run_command "echo 'Defaults secure_path=\"/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin\"' > /etc/sudoers.d/usrlocal";
    assert_script_run "echo '$testapi::username ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/nopasswd";

    assert_script_run "curl -o /usr/local/bin/bats_skip_notok " . data_url("containers/bats_skip_notok.py");
    assert_script_run "chmod +x /usr/local/bin/bats_skip_notok";
}

sub configure_oci_runtime {
    my $oci_runtime = shift;

    return if (script_run("command -v podman") != 0);

    if (!$oci_runtime) {
        $oci_runtime = script_output("podman info --format '{{ .Host.OCIRuntime.Name }}'");
    }
    run_command "mkdir -p /etc/containers/containers.conf.d";
    run_command 'echo -e "[engine]\nruntime=\"' . $oci_runtime . '\"" >> /etc/containers/containers.conf.d/engine.conf';
    record_info("OCI runtime", $oci_runtime);
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
    # Needed for libcriu2
    add_suseconnect_product(get_addon_fullname('phub'));
}

sub patch_logfile {
    my ($log_file, @skip_tests) = @_;

    @skip_tests = uniq sort @skip_tests;

    foreach my $test (@skip_tests) {
        next if (!$test);
        if (script_run("grep -q 'in test file.*/$test.bats' $log_file") != 0) {
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
    assert_script_run "echo '$override_conf' > /etc/systemd/system/tmp.mount.d/override.conf";
}

sub bats_setup {
    my ($self, @pkgs) = @_;
    my $reboot_needed = 0;

    push @commands, "### RUN AS root";

    install_bats;

    enable_modules if is_sle;

    # Install tests dependencies
    my $oci_runtime = get_var("OCI_RUNTIME", "");
    if ($oci_runtime && !grep { $_ eq $oci_runtime } @pkgs) {
        push @pkgs, $oci_runtime;
    }
    push @pkgs, "patch";
    push @commands, "zypper -n install @pkgs";
    install_packages(@pkgs);

    configure_oci_runtime $oci_runtime;

    install_ncat if (get_required_var("BATS_PACKAGE") =~ /^aardvark|netavark|podman$/);

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

    # Remove mounts.conf
    run_command "rm -vf /etc/containers/mounts.conf /usr/share/containers/mounts.conf";

    # Disable tmpfs from next boot
    if (script_output("findmnt -no FSTYPE /tmp", proceed_on_failure => 1) =~ /tmpfs/) {
        # Bind mount /tmp to /var/tmp
        fix_tmp;
        $reboot_needed = 1;
    }

    # Switch to cgroup v2 if not already active
    if (script_run("test -f /sys/fs/cgroup/cgroup.controllers") != 0) {
        add_grub_cmdline_settings("systemd.unified_cgroup_hierarchy=1", update_grub => 1);
        $reboot_needed = 1;
    }

    if ($reboot_needed) {
        power_action('reboot', textmode => 1);
        $self->wait_boot();
    }

    select_serial_terminal;

    assert_script_run "mount --make-rshared /tmp" if (script_run("findmnt -no FSTYPE /tmp") == 0);
}

sub selinux_hack {
    my $dir = shift;

    # Use the same labeling in /var/lib/containers for $dir
    # https://github.com/containers/podman/blob/main/troubleshooting.md#11-changing-the-location-of-the-graphroot-leads-to-permission-denied
    run_command "sudo semanage fcontext -a -e /var/lib/containers $dir || true", timeout => 120;
    run_command "sudo restorecon -R -v $dir || true";
}

sub bats_post_hook {
    select_serial_terminal;

    my $log_dir = "/tmp/logs/";
    assert_script_run "mkdir -p $log_dir";
    assert_script_run "cd $log_dir";

    script_run "rm -rf $test_dir";

    script_run('df -h > df-h.txt');
    script_run('dmesg > dmesg.txt');
    script_run('findmnt > findmnt.txt');
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

    my $package = get_required_var("BATS_PACKAGE");

    my $tmp_dir = script_output "mktemp -du -p /var/tmp test.XXXXXX";
    run_command "mkdir -p $tmp_dir";
    selinux_hack $tmp_dir if ($package =~ /buildah|podman/);

    $env{BATS_TMPDIR} = $tmp_dir;
    $env{TMPDIR} = $tmp_dir if ($package eq "buildah");
    $env{PATH} = '/usr/local/bin:$PATH:/usr/sbin:/sbin';
    my $env = join " ", map { "$_=$env{$_}" } sort keys %env;

    # Subdirectory in repo containing BATS tests
    my %tests_dir = (
        aardvark => "test",
        buildah => "tests",
        netavark => "test",
        podman => "test/system",
        runc => "tests/integration",
        skopeo => "systemtest",
    );

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

    $package = ($package eq "aardvark") ? "aardvark-dns" : $package;
    my $version = script_output "rpm -q --queryformat '%{VERSION} %{RELEASE}' $package";
    my $os_version = join(' ', get_var("DISTRI"), get_var("VERSION"), get_var("BUILD"), get_var("ARCH"));

    run_command "echo $log_file .. > $log_file";
    run_command "echo '# $package $version $os_version' >> $log_file";
    push @commands, $cmd;
    my $ret = script_run $cmd, 7000;

    unless (@tests) {
        my @skip_tests = split(/\s+/, get_var('BATS_SKIP', '') . " " . $skip_tests);
        patch_logfile($log_file, @skip_tests);
    }

    parse_extra_log(TAP => $log_file);

    run_command "rm -rf $tmp_dir || true";

    return ($ret);
}

sub bats_patches {
    return if get_var("BATS_URL");

    my $package = get_required_var("BATS_PACKAGE");
    $package = ($package eq "aardvark") ? "aardvark-dns" : $package;

    my $github_org = ($package eq "runc") ? "opencontainers" : "containers";

    foreach my $patch (split(/\s+/, get_var("BATS_PATCHES", ""))) {
        my $url = ($patch =~ /^\d+$/) ? "https://github.com/$github_org/$package/pull/$patch.diff" : $patch;
        record_info("patch", $url);
        run_command "curl $curl_opts $url | patch -p1 --merge", timeout => 900;
    }
}

sub bats_sources {
    my $version = shift;

    my $package = get_required_var("BATS_PACKAGE");
    $package = ($package eq "aardvark") ? "aardvark-dns" : $package;

    my $github_org = ($package eq "runc") ? "opencontainers" : "containers";
    my $tag = "v$version";

    # Support these cases for BATS_URL:
    # 1. As full URL: https://github.com/containers/aardvark-dns/archive/refs/heads/main.tar.gz
    # 2. As GITHUB_ORG#TAG: SUSE#suse-v4.9.5, yourusername#test-patch, etc
    # 3. As TAG only: main, v1.2.3, cool-test-fix, etc
    # 4. Empty. Use default for repo based on package version

    my $url = get_var("BATS_URL", "");
    if ($url !~ m%^https://%) {
        if ($url =~ /#/) {
            ($github_org, $tag) = split("#", $url, 2);
        } elsif ($url) {
            $tag = $url;
        }
        my $dir = ($tag =~ /^v\d+\./) ? "tags" : "heads";
        $url = "https://github.com/$github_org/$package/archive/refs/$dir/$tag.tar.gz";
    }
    record_info("BATS_URL", $url);

    run_command "mkdir -p $test_dir";
    if ($package eq "buildah") {
        selinux_hack $test_dir;
        selinux_hack "/tmp";
    }
    run_command "cd $test_dir";
    run_command "curl $curl_opts $url | tar -zxf - --strip-components 1";
    if ($package eq "podman") {
        my $hack_bats = "https://raw.githubusercontent.com/containers/podman/refs/heads/main/hack/bats";
        run_command "curl $curl_opts -o hack/bats $hack_bats";
    }
}

1;
