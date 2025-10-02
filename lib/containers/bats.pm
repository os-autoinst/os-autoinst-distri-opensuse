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
use Utils::Architectures;

our @EXPORT = qw(
  bats_post_hook
  bats_tests
  mount_tmp_vartmp
  patch_junit
  patch_sources
  run_command
  setup_pkgs
  switch_to_root
  switch_to_user
);

my $curl_opts = "-sL --retry 9 --retry-delay 100 --retry-max-time 900";
my $test_dir = "/var/tmp/";
my $rebooted = 0;
my $settings;

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
        } elsif (is_ppc64le) {
            run_command "zypper addrepo https://download.opensuse.org/repositories/openSUSE:/Factory:/PowerPC:/NonFree/standard/openSUSE:Factory:PowerPC:NonFree.repo";
        } elsif (is_s390x) {
            run_command "zypper addrepo http://download.opensuse.org/ports/zsystems/tumbleweed/repo/non-oss/ non-oss";
        } else {
            run_command "zypper addrepo http://download.opensuse.org/tumbleweed/repo/non-oss/ non-oss";
        }
    } elsif (is_sle('<16')) {
        # This repo has ncat 7.94
        run_command "zypper addrepo https://download.opensuse.org/repositories/network:/utilities/15.6/network:utilities.repo";
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
    script_run("rm -rf bats-core-$bats_version", proceed_on_failure => 1);

    run_command "mkdir -pm 0750 /etc/sudoers.d/";
    run_command "echo 'Defaults secure_path=\"/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin\"' > /etc/sudoers.d/usrlocal";
    assert_script_run "echo '$testapi::username ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/nopasswd";

    assert_script_run "curl -o /usr/local/bin/bats_skip_notok " . data_url("containers/bats/skip_notok.py");
    assert_script_run "chmod +x /usr/local/bin/bats_skip_notok";
}

sub configure_oci_runtime {
    my $oci_runtime = shift;

    return if (script_run("command -v podman") != 0);
    return if (script_run("test -f /etc/containers/containers.conf.d/engine.conf") == 0);

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
    add_suseconnect_product(get_addon_fullname('desktop'));
    add_suseconnect_product(get_addon_fullname('sdk'));
    add_suseconnect_product(get_addon_fullname('python3')) if is_sle('>=15-SP4');
    # Needed for criu, fakeroot & qemu-linux-user
    add_suseconnect_product(get_addon_fullname('phub'));
}

sub patch_junit {
    my ($package, $version, $xmlfile, $skip_tests) = @_;
    my $os_version = join(' ', get_var("DISTRI"), get_var("VERSION"), get_var("BUILD"), get_var("ARCH"));

    my @passed = split /\n/, script_output "patch_junit $xmlfile '$package $version $os_version' $skip_tests";
    foreach my $pass (@passed) {
        record_info("PASS", $pass);
    }
}

sub patch_logfile {
    my ($log_file, $xmlfile, @skip_tests) = @_;

    my $package = get_required_var("BATS_PACKAGE");
    my $version = script_output "rpm -q --queryformat '%{VERSION}' $package";

    die "BATS failed!" if (script_run("test -e $log_file") != 0);

    @skip_tests = uniq sort @skip_tests;

    my $skip_tests = join(' ', map { "\"$_\"" } @skip_tests);
    assert_script_run "bats_skip_notok $log_file $skip_tests" if (@skip_tests);
    patch_junit $package, $version, $xmlfile, $skip_tests;
}

# /tmp as tmpfs has multiple issues: it can't store SELinux labels, consumes RAM and doesn't have enough space
# Bind-mount it to /var/tmp
sub mount_tmp_vartmp {
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

sub setup_pkgs {
    my ($self, @pkgs) = @_;

    push @commands, "### RUN AS root";

    if (get_var("TEST_REPOS", "")) {
        if (script_run("zypper lr | grep -q SUSE_CA")) {
            run_command "zypper addrepo --refresh http://download.opensuse.org/repositories/SUSE:/CA/openSUSE_Tumbleweed/SUSE:CA.repo";
        }
        if (script_run("rpm -q ca-certificates-suse")) {
            run_command "zypper --gpg-auto-import-keys -n install ca-certificates-suse";
        }

        foreach my $repo (split(/\s+/, get_var("TEST_REPOS", ""))) {
            run_command "zypper addrepo $repo";
        }
    }

    foreach my $pkg (split(/\s+/, get_var("TEST_PACKAGES", ""))) {
        run_command "zypper --gpg-auto-import-keys --no-gpg-checks -n install $pkg";
    }

    install_bats if get_var("BATS_PACKAGE");
    assert_script_run "curl -o /usr/local/bin/patch_junit " . data_url("containers/patch_junit.py");
    assert_script_run "chmod +x /usr/local/bin/patch_junit";

    enable_modules if is_sle("<16");

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
    push @pkgs, qw(jq xz);
    @pkgs = uniq sort @pkgs;
    run_command "zypper --gpg-auto-import-keys -n install @pkgs", timeout => 600;

    configure_oci_runtime $oci_runtime;

    install_ncat if $install_ncat;

    return if $rebooted;

    install_git;

    # Add IP to /etc/hosts
    my $iface = script_output "ip -4 --json route list match default | jq -Mr '.[0].dev'";
    my $ip_addr = script_output "ip -4 --json addr show $iface | jq -Mr '.[0].addr_info[0].local'";
    assert_script_run "echo $ip_addr \$(hostname) >> /etc/hosts";

    # Enable SSH
    my $algo = "ed25519";
    systemctl 'enable --now sshd';
    assert_script_run "ssh-keygen -t $algo -N '' -f ~/.ssh/id_$algo";
    assert_script_run "cat ~/.ssh/id_$algo.pub >> ~/.ssh/authorized_keys";
    assert_script_run "ssh-keyscan localhost 127.0.0.1 ::1 | tee -a ~/.ssh/known_hosts";
    # Persist SSH connections
    # https://docs.docker.com/engine/security/protect-access/#ssh-tips
    my $ssh_config = <<'EOF';
ControlMaster     auto
ControlPath       ~/.ssh/control-%C
ControlPersist    yes
EOF
    write_sut_file('/root/.ssh/config', $ssh_config);

    delegate_controllers;

    if (check_var("SELINUX_ENFORCE", "0") && script_output("getenforce") eq "Enforcing") {
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
        mount_tmp_vartmp;
    }

    # Switch to cgroup v2 if not already active
    if (script_run("test -f /sys/fs/cgroup/cgroup.controllers") != 0) {
        add_grub_cmdline_settings("systemd.unified_cgroup_hierarchy=1", update_grub => 1);
    }

    power_action('reboot', textmode => 1);
    $self->wait_boot();
    push @commands, "reboot";
    $rebooted = 1;

    select_serial_terminal;

    assert_script_run "mount --make-rshared /tmp" if (script_run("findmnt -no FSTYPE /tmp") == 0);
}

sub collect_coredumps {
    my $package = get_var("BATS_PACKAGE", "");

    script_run('coredumpctl list > coredumpctl.txt');

    # Get PID and executable for all dumps
    my @lines = split /\n/, script_output(q{coredumpctl -q --no-pager --no-legend | awk '$9 == "present" { print $5, $10 }'}, proceed_on_failure => 1);

    foreach my $line (@lines) {
        my ($pid, $exe) = split /\s+/, $line;
        $exe = basename($exe);
        # The runc seccomp SCMP_ACT_KILL test uses mkdir so a core file is expected
        next if ($package eq "runc" && $exe eq "mkdir");
        my $core = "core.$exe.$pid.core";

        # Dumping and compressing coredumps may take some time
        my $out = script_output("coredumpctl -o $core dump $pid", timeout => 300, proceed_on_failure => 1);
        record_info("COREDUMP", $out);
        script_run("xz -9v $core", 300);
    }
}

sub collect_calltraces {
    # Collect all traces
    my $traces = script_output(q(dmesg | awk '/Call Trace:/ { trace = 1 } trace { print } /<\/TASK>/ { trace = 0; print "" }'));

    foreach my $trace (split /\n\n+/, $traces) {
        record_info("TRACE", $trace);
    }
}

sub bats_post_hook {
    select_serial_terminal;

    my $log_dir = "/tmp/logs/";
    assert_script_run "mkdir -p $log_dir || true";
    assert_script_run "cd $log_dir";

    script_run("rm -rf $test_dir", timeout => 300, proceed_on_failure => 1) unless ($test_dir eq "/var/tmp/");

    collect_calltraces;
    collect_coredumps;
    script_run('df -h > df-h.txt');
    script_run('dmesg > dmesg.txt');
    script_run('findmnt > findmnt.txt');
    script_run('free -h > free.txt');
    script_run('lscpu > lscpu.txt');
    script_run('lsmod > lsmod.txt');
    script_run('rpm -qa | sort > rpm-qa.txt');
    script_run('sysctl -a > sysctl.txt');
    script_run('systemctl > systemctl.txt');
    script_run('systemctl status > systemctl-status.txt');
    script_run('systemctl list-unit-files > systemctl_units.txt');
    script_run('uname -a > uname.txt');
    script_run('journalctl -b > journalctl-b.txt', timeout => 120);
    script_run('tar zcf containers-conf.tgz $(find /etc/containers /usr/share/containers -type f)');

    for my $ip_version (4, 6) {
        script_run("ip -j -$ip_version addr | jq -Mr > ip$ip_version-addr.txt");
        script_run("ip -j -$ip_version link | jq -Mr > ip$ip_version-link.txt");
        script_run("ip -j -$ip_version route | jq -Mr > ip$ip_version-route.txt");
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

    script_run('cd / ; rm -rf /tmp/logs');
}

sub bats_tests {
    my ($log_file, $_env, $skip_tests, $timeout) = @_;
    my %env = %{$_env};

    my $package = get_required_var("BATS_PACKAGE");

    # Subdirectory in repo containing BATS tests
    my %tests_dir = (
        "aardvark-dns" => "test",
        buildah => "tests",
        conmon => "test",
        netavark => "test",
        podman => "test/system",
        runc => "tests/integration",
        skopeo => "systemtest",
    );

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

    my $cmd = "env $env bats --report-formatter junit --tap -T $tests";
    # With podman we must use its own hack/bats instead of calling bats directly
    if ($package eq "podman") {
        my $args = ($log_file =~ /root/) ? "--root" : "--rootless";
        $args .= " --remote" if ($log_file =~ /remote/);
        $cmd = "env $env hack/bats -t -T $args";
        $cmd .= " $tests" if ($tests ne $tests_dir{podman});
    }
    my $xmlfile = "$log_file.xml";
    $log_file .= ".tap.txt";
    $cmd .= " | tee -a $log_file";

    run_command "echo $log_file .. > $log_file";
    push @commands, $cmd;
    my $ret = script_run($cmd, timeout => $timeout);
    script_run "mv report.xml $xmlfile";

    unless (get_var("BATS_TESTS")) {
        my @skip_tests = ();
        push @skip_tests, @{$settings->{$skip_tests}} if ($settings->{$skip_tests});
        push @skip_tests, @{$settings->{BATS_IGNORE}} if ($settings->{BATS_IGNORE});
        patch_logfile($log_file, $xmlfile, @skip_tests);
    }

    parse_extra_log(XUnit => $xmlfile);
    upload_logs($log_file);

    script_run("sudo rm -rf $tmp_dir", timeout => 300, proceed_on_failure => 1);

    return ($ret);
}

sub bats_settings {
    my $package = shift;
    my $os_version = get_required_var("DISTRI") . "-" . get_required_var("VERSION");

    assert_script_run "curl -o /tmp/skip.yaml " . data_url("containers/bats/skip.yaml");
    my $text = script_output("cat /tmp/skip.yaml", quiet => 1);
    my $yaml = YAML::PP->new()->load_string($text);

    return $yaml->{$package}{$os_version};
}

sub patch_sources {
    my ($package, $branch, $tests_dir) = @_;

    $settings = bats_settings $package;
    my @patches = split(/\s+/, get_var("GITHUB_PATCHES", ""));
    if (!@patches && defined $settings->{GITHUB_PATCHES}) {
        @patches = @{$settings->{GITHUB_PATCHES}};
    }

    my $github_org = "containers";
    if ($package eq "runc") {
        $github_org = "opencontainers";
    } elsif ($package =~ /compose|docker/) {
        $github_org = "docker";
    }

    # Support these cases for GITHUB_REPO: [<GITHUB_ORG>]#BRANCH
    # 1. As GITHUB_ORG#TAG: SUSE#suse-v4.9.5, your_gh_user#test-patch, etc
    # 2. As TAG only: main, v1.2.3, etc
    # 3. Empty. Use default for repo based on package version

    my $repo = get_var("GITHUB_REPO", "");
    if ($repo =~ /#/) {
        ($github_org, $branch) = split("#", $repo, 2);
    } elsif ($repo) {
        $branch = $repo;
    }

    $test_dir = "/var/tmp/";
    run_command "cd $test_dir";
    run_command "git clone https://github.com/$github_org/$package.git", timeout => 300;
    $test_dir .= $package;
    run_command "cd $test_dir";
    run_command "git checkout $branch";

    # We use GITHUB_PATCHES="none" to specify that we don't want to patch anything
    unless (check_var("GITHUB_PATCHES", "none")) {
        foreach my $patch (@patches) {
            my $url = ($patch =~ /^\d+$/) ? "https://github.com/$github_org/$package/pull/$patch.patch" : $patch;
            record_info("patch", $url);
            if ($patch =~ /^\d+$/) {
                push @commands, "curl $curl_opts -O $url";
                assert_script_run "curl -O " . data_url("containers/patches/$package/$patch.patch");
            } else {
                run_command "curl $curl_opts -O $url", timeout => 900;
            }
            # Some patches (e.g., podman's 25942) fail to apply cleanly due to missing files so
            # try `git apply` first and if it fails use `--include` to restrict the patch scope
            # to the package tests directory.  Remove this when `git-apply` has a new option to
            # ignore missing files.
            my $file = basename($url);
            my $apply_cmd = "git apply -3 --ours $file";
            $apply_cmd .= " || git apply -3 --ours --include '$tests_dir/*' $file";
            run_command $apply_cmd;
        }
    }

    if ($package eq "podman") {
        my $hack_bats = "https://raw.githubusercontent.com/containers/podman/refs/heads/main/hack/bats";
        run_command "curl $curl_opts -o hack/bats $hack_bats";
        assert_script_run q(sed -ri 's/(bats_opts)=.*/\1=(--report-formatter junit)/' hack/bats);
    }
}

1;
