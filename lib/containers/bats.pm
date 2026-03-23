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
use strict;
use warnings;
use utils;
use version;
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
  cleanup_docker
  cleanup_podman
  cleanup_rootless_docker
  configure_containerd_mirror
  configure_docker
  configure_rootless_docker
  configure_podman_mirror
  enable_docker
  go_arch
  install_docker_compose
  install_gotestsum
  install_ncat
  numeric_version
  patch_junit
  patch_sources
  run_command
  run_timeout_command
  setup_pkgs
  switch_to_root
  switch_to_user
);

my $curl_opts = "-sL --retry 9 --retry-delay 100 --retry-max-time 900";
my $test_dir = "/var/tmp/";
my $rebooted = 0;
my $ip_addr;
my $registry = get_var("REGISTRY", "3.126.238.126:5000");

my @commands = ();

sub run_command {
    my $cmd = shift;
    my %args = testapi::compat_args(
        {
            timeout => 90,
            no_assert => 0,
        }, ['timeout', 'no_assert'], @_);
    my $no_assert = delete $args{no_assert};

    push @commands, $cmd;

    if ($cmd =~ / &$/) {
        $cmd =~ s/ \&$//;
        return background_script_run $cmd, %args;
    }

    # We need no_assert when running testsuites because the testsuite may fail
    # but we need to upload the XML before triggering the post fail hook.
    return $no_assert ? script_run $cmd, %args : assert_script_run $cmd, %args;
}

sub run_timeout_command {
    my $cmd = shift;
    my %args = testapi::compat_args(
        {
            timeout => 90,
        }, ['timeout'], @_);
    my $timeout = delete $args{timeout};

    return run_command("timeout -k 3 $timeout env $cmd", %args, timeout => $timeout + 10);
}

sub switch_to_root {
    select_serial_terminal;
    push @commands, "### RUN AS root";
    run_command "cd $test_dir";
}

sub switch_to_user {
    select_user_serial_terminal();
    push @commands, "### RUN AS user";
    run_command "cd /var/tmp";
}

sub install_docker_compose {
    my $compose_version = "2.40.3";
    my $arch = get_required_var("ARCH");
    my $url = "https://github.com/docker/compose/releases/download/v$compose_version/docker-compose-linux-$arch";
    run_command "curl -sSLo /usr/lib/docker/cli-plugins/docker-compose $url";
    run_command "chmod +x /usr/lib/docker/cli-plugins/docker-compose";
    run_command "echo 0 > /etc/docker/suse-secrets-enable";
}

sub configure_docker_tls {
    my $ca_cert = "ca.pem";
    my $ca_key = "ca-key.pem";
    my $req = "cert.csr";
    my $cert = "cert.pem";
    my $key = "key.pem";
    my $opts = "-req -days 7 -sha256 -in $req -CA $ca_cert -CAkey $ca_key -CAcreateserial -out $cert";

    my $not_before = is_sle("<16") ? "" : " -not_before " . script_output('date -u -d "5 minutes ago" +%Y%m%d%H%M%SZ');
    $opts .= $not_before;

    # Create self-signed CA
    run_command "openssl genrsa -out $ca_key 4096";
    run_command qq(openssl req -new -x509 -days 7 -key $ca_key -sha256 -subj "/CN=CA" -out $ca_cert -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign");
    # Create server cert & key
    run_command "openssl genrsa -out $key 4096";
    run_command qq(openssl req -new -key $key -subj "/CN=\$(hostname)" -out $req);
    run_command "openssl x509 $opts -extfile <(echo extendedKeyUsage=serverAuth) -extfile <(echo subjectAltName=DNS:\$(hostname),DNS:localhost,IP:$ip_addr,IP:127.0.0.1)";
    run_command "cp -f $ca_cert $cert $key /etc/docker/";
    # Create client server & key
    run_command "openssl genrsa -out $key 4096";
    run_command qq(openssl req -new -key $key -subj "/CN=client" -out $req);
    run_command "openssl x509 $opts -extfile <(echo extendedKeyUsage=clientAuth)";
    run_command "mkdir -m 700 ~/.docker/ || true";
    run_command "mv -f $ca_cert $cert $key ~/.docker/";
    run_command "cp /etc/docker/ca.pem /etc/pki/trust/anchors/";
    run_command "update-ca-certificates";
    # Older versions of openssl-x509(1) lack -not_before so let's sleep a little while
    sleep 5 unless $not_before;
    return " --tlsverify --tlscacert=/etc/docker/$ca_cert --tlscert=/etc/docker/$cert --tlskey=/etc/docker/$key";
}

sub configure_docker {
    my (%args) = @_;
    $args{experimental} //= get_var("DOCKER_EXPERIMENTAL", 0);
    $args{selinux} //= get_var("DOCKER_SELINUX", 0);
    $args{tls} //= get_var("DOCKER_TLS", 0);

    # docker-compose is needed for tests but is not available on SLES 15
    install_docker_compose if (is_sle("<16") && script_run("test -f /usr/lib/docker/cli-plugins/docker-compose"));

    run_command "export DOCKER_BUILDKIT=1" if is_sle("<16");

    my $docker_opts = "-H unix:///var/run/docker.sock --insecure-registry localhost:5000 --log-level warn --registry-mirror http://$registry";
    $docker_opts .= " --experimental" if $args{experimental};
    $docker_opts .= " --selinux-enabled" if $args{selinux};
    my $port = 2375;
    if ($args{tls}) {
        $port++;
        $docker_opts .= configure_docker_tls;
    }
    $docker_opts .= " -H tcp://0.0.0.0:$port";
    run_command "mv -f /etc/sysconfig/docker{,.bak} || true";
    run_command "mv -f /etc/docker/daemon.json{,.bak} || true";
    if (script_output(q(docker --version | awk -F'[. ]' '{ print $3 }')) > 28) {
        my $docker_min_api_version = get_var("DOCKER_MIN_API_VERSION", "1.24");
        run_command qq(echo '{"min-api-version": "$docker_min_api_version"}' > /etc/docker/daemon.json);
    }
    run_command qq(echo 'DOCKER_OPTS="$docker_opts"' > /etc/sysconfig/docker);
    record_info "DOCKER_OPTS", $docker_opts;
    run_command "systemctl restart docker";
    run_command "export DOCKER_HOST=tcp://localhost:$port";
    if ($args{tls}) {
        run_command 'export DOCKER_CERT_PATH=$HOME/.docker';
        run_command "export DOCKER_TLS_VERIFY=1";
    }
    record_info "containerd status", script_output("systemctl status containerd", proceed_on_failure => 1);
    record_info "docker status", script_output("systemctl status docker", proceed_on_failure => 1);
    record_info "docker version", script_output("docker version -f json | jq -Mr");
    record_info "docker info", script_output("docker info -f json | jq -Mr");
    my $warnings = script_output("docker info -f '{{ range .Warnings }}{{ println . }}{{ end }}'");
    record_info "WARNINGS daemon", $warnings if $warnings;
    $warnings = script_output("docker info -f '{{ range .ClientInfo.Warnings }}{{ println . }}{{ end }}'");
    record_info "WARNINGS client", $warnings if $warnings;
}

sub configure_rootless_docker {
    run_command "modprobe br_netfilter || true";
    run_command "systemctl stop docker || true";

    switch_to_user;

    if (script_output(q(docker --version | awk -F'[. ]' '{ print $3 }')) > 28) {
        run_command 'mkdir -p ${XDG_CONFIG_HOME:-$HOME/.config}/docker';
        my $docker_min_api_version = get_var("DOCKER_MIN_API_VERSION", "1.24");
        run_command qq(echo '{"min-api-version": "$docker_min_api_version"}' > \${XDG_CONFIG_HOME:-\$HOME/.config}/docker/daemon.json);
    }

    # https://docs.docker.com/engine/security/rootless/
    run_command "dockerd-rootless-setuptool.sh install";
    run_command "systemctl --user enable --now docker";
    run_command "export DOCKER_HOST=unix:///run/user/\$(id -u)/docker.sock";
    record_info "docker status", script_output("systemctl status --user docker", proceed_on_failure => 1);
    record_info "rootless", script_output("docker info -f json | jq -Mr");
    my $warnings = script_output("docker info -f '{{ range .Warnings }}{{ println . }}{{ end }}'");
    record_info "WARNINGS daemon", $warnings if $warnings;
    $warnings = script_output("docker info -f '{{ range .ClientInfo.Warnings }}{{ println . }}{{ end }}'");
    record_info "WARNINGS client", $warnings if $warnings;
    run_command 'export PATH=$PATH:/usr/sbin:/sbin';
}

sub enable_docker {
    # Needed to avoid:
    # WARNING: COMMAND_FAILED: '/sbin/iptables -t nat -F DOCKER' failed: iptables: No chain/target/match by that name.
    # See https://bugzilla.suse.com/show_bug.cgi?id=1196801
    script_run 'systemctl restart firewalld';

    script_run 'systemctl enable --now docker';
    script_run "usermod -aG docker $testapi::username";

    # Running podman as root with docker installed may be problematic as netavark uses nftables
    # while docker still uses iptables.
    # Use workaround suggested in:
    # - https://fedoraproject.org/wiki/Changes/NetavarkNftablesDefault#Known_Issue_with_docker
    # - https://docs.docker.com/engine/network/packet-filtering-firewalls/#docker-on-a-router
    if (script_run("iptables -L -v | grep -q DOCKER") == 0) {
        script_run "iptables -I DOCKER-USER -j ACCEPT";
        script_run "ip6tables -I DOCKER-USER -j ACCEPT";
    }
}

sub configure_containerd_mirror {
    my $version = shift;

    # https://github.com/containerd/containerd/blob/main/docs/cri/registry.md
    if ($version =~ /v1/) {
        my $conf = <<"EOF";
version = 2

[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
      endpoint = ["http://$registry"]
EOF
        write_sut_file("/etc/containerd/config.toml", $conf);
    } else {
        my $conf = <<"EOF";
server = "https://docker.io"

[host."http://$registry"]
  capabilities = ["pull", "resolve"]
EOF
        assert_script_run("mkdir -p /etc/containerd/certs.d/docker.io");
        write_sut_file("/etc/containerd/certs.d/docker.io/hosts.toml", $conf);
    }
}

sub configure_podman_mirror {
    my $conf = <<"EOF";
[[registry]]
prefix = "docker.io"
location = "docker.io"

  [[registry.mirror]]
    prefix = "docker.io"
    location = "$registry"
    insecure = true
EOF
    write_sut_file("/etc/containers/registries.conf.d/777-mirror.conf", $conf);
}

sub cleanup_docker {
    my $timeout = 300;
    script_run "mv -f /etc/docker/daemon.json{.bak,}";
    script_run "mv -f /etc/sysconfig/docker{.bak,}";
    script_run 'docker rm -vf $(docker ps -aq)', timeout => $timeout;
    script_run "docker volume prune -a -f", timeout => $timeout;
    script_run "docker system prune -a -f", timeout => $timeout;
    script_run "unset DOCKER_CERT_PATH DOCKER_HOST DOCKER_TLS_VERIFY";
    systemctl "restart docker";
}

sub cleanup_rootless_docker {
    select_user_serial_terminal;
    script_run "dockerd-rootless-setuptool.sh uninstall";
    script_run "rootlesskit rm -rf ~/.local/share/docker";
}

sub cleanup_podman {
    my $timeout = 300;
    script_run 'podman rm -vf $(podman ps -aq --external)', timeout => $timeout;
    script_run "podman volume prune -f", timeout => $timeout;
    script_run "podman system prune -a -f", timeout => $timeout;
    script_run "podman system reset -f";
}

# Translate RPM arch to Go arch
sub go_arch {
    my $arch = shift;
    return "amd64" if $arch eq "x86_64";
    return "arm64" if $arch eq "aarch64";
    return $arch;
}

sub install_git {
    # We need git 2.47.0+ to use `--ours` with `git apply -3`
    return if (script_run("test -f /etc/zypp/repos.d/Kernel_tools.repo") == 0);
    my $version = get_var("VERSION");
    $version =~ s/-/_/;
    $version = "SLE_$version";
    run_command "zypper addrepo https://download.opensuse.org/repositories/Kernel:/tools/$version/Kernel:tools.repo";
    run_command "zypper --gpg-auto-import-keys -n install --allow-vendor-change git-core", timeout => 300;
}

sub install_gotestsum {
    # We need gotestsum to parse "go test" and create JUnit XML output
    return if (script_run("command -v gotestsum") == 0);
    run_command 'export GOPATH=$HOME/go';
    run_command 'export PATH=$GOPATH/bin:$PATH';
    run_command 'go install gotest.tools/gotestsum@v1.13.0';
}

sub install_ncat {
    if (is_sle('<16')) {
        # This repo has ncat 7.94
        run_command "zypper addrepo https://download.opensuse.org/repositories/network:/utilities/15.6/network:utilities.repo";
    }
    run_command "zypper --gpg-auto-import-keys -n install ncat";

    # Some tests use nc instead of ncat but expect ncat behaviour instead of netcat-openbsd
    run_command "ln -sf /usr/bin/ncat /usr/bin/nc";
    record_info("nc", script_output("nc --version"));
}

sub install_bats {
    my $bats_version = get_var("BATS_VERSION", "1.13.0");

    run_command "curl $curl_opts https://github.com/bats-core/bats-core/archive/refs/tags/v$bats_version.tar.gz | tar -zxf -", timeout => 300;
    run_command "bash bats-core-$bats_version/install.sh /usr/local";
    script_run("rm -rf bats-core-$bats_version", timeout => 0);
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
    record_info("$oci_runtime features", script_output("$oci_runtime features"));
}

sub delegate_controllers {
    if (script_run("test -f /etc/systemd/system/user@.service.d/60-delegate.conf") != 0) {
        # Let user control cpu, io & memory control groups
        # https://susedoc.github.io/doc-sle/main/html/SLES-tuning/cha-tuning-cgroups.html#sec-cgroups-user-sessions
        run_command "mkdir -p /etc/systemd/system/user@.service.d/";
        run_command 'echo -e "[Service]\nDelegate=cpu cpuset io memory pids" > /etc/systemd/system/user@.service.d/60-delegate.conf';
    }
}

sub enable_modules {
    add_suseconnect_product(get_addon_fullname('desktop'));
    add_suseconnect_product(get_addon_fullname('sdk'));
    add_suseconnect_product(get_addon_fullname('python3'));
    # Needed for criu, fakeroot & qemu-linux-user
    add_suseconnect_product(get_addon_fullname('phub')) if (check_var("BATS_PACKAGE", "buildah") || check_var("BATS_PACKAGE", "skopeo"));
}

sub patch_junit {
    my ($package, $version, $xmlfile, @xfails) = @_;
    my $os_version = join(' ', get_var("DISTRI"), get_var("VERSION"), get_var("BUILD"), get_var("ARCH"));
    @xfails = uniq sort @xfails;
    my $xfails = join(' ', map { "\"$_\"" } @xfails);
    script_run "cp $xmlfile $xmlfile.orig";
    my @passed = split /\n/, script_output "patch_junit $xmlfile '$package $version $os_version' $xfails";
    foreach my $pass (@passed) {
        record_info("PASS", $pass);
    }
}

sub setup_pkgs {
    my ($self, @pkgs) = @_;

    @commands = ("### RUN AS root");

    install_bats if get_var("BATS_PACKAGE");

    enable_modules if is_sle("<16");

    if (get_var("TEST_REPOS", "")) {
        if (script_run("zypper lr | grep -q SUSE_CA")) {
            run_command "zypper addrepo --refresh http://download.opensuse.org/repositories/SUSE:/CA/openSUSE_Tumbleweed/SUSE:CA.repo";
        }
        if (script_run("rpm -q ca-certificates-suse")) {
            run_command "zypper --gpg-auto-import-keys -n install ca-certificates-suse";
        }

        foreach my $repo (split(/\s+/, get_var("TEST_REPOS", ""))) {
            run_command "zypper addrepo --refresh $repo || true";
        }
    }

    # Install tests dependencies
    my $oci_runtime = get_var("OCI_RUNTIME", "");
    if ($oci_runtime && !grep { $_ eq $oci_runtime } @pkgs) {
        push @pkgs, $oci_runtime;
    }
    push @pkgs, qw(jq xz);
    @pkgs = uniq sort @pkgs;
    push @pkgs, "git" unless is_sle("<16.0");
    run_command "zypper --gpg-auto-import-keys -n install --allow-vendor-change @pkgs", timeout => 1200;
    install_git if is_sle("<16.0");

    # Workaround for https://bugzilla.opensuse.org/show_bug.cgi?id=1259147
    if (is_tumbleweed && is_x86_64 && !get_var("OCI_RUNTIME") && (check_var("BATS_PACKAGE", "buildah") || check_var("BATS_PACKAGE", "podman"))) {
        assert_script_run "curl -o /tmp/libseccomp2.rpm " . data_url("containers/libseccomp2-2.6.0-2.2.x86_64.rpm");
        assert_script_run "rpm -ivh --force /tmp/libseccomp2.rpm";
    }

    configure_oci_runtime $oci_runtime;

    if (script_run("test -f /usr/local/bin/patch_junit")) {
        assert_script_run "curl -o /usr/local/bin/patch_junit " . data_url("containers/patch_junit.py");
        assert_script_run "chmod +x /usr/local/bin/patch_junit";
    }

    # Add IP to /etc/hosts
    $ip_addr = script_output("ip -j route get 8.8.8.8 | jq -Mr '.[0].prefsrc'");
    if (script_run("grep -q \$(hostname) /etc/hosts")) {
        assert_script_run "echo $ip_addr \$(hostname) >> /etc/hosts";
    }

    # Enable SSH
    my $algo = "ed25519";
    if (script_run("test -f ~/.ssh/id_$algo.pub")) {
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
        assert_script_run "cp -r /root/.ssh /home/$testapi::username";
        assert_script_run "chown -R $testapi::username /home/$testapi::username/.ssh";
    }

    return if $rebooted;

    script_run "mkdir -pm 700 /etc/cdi";

    foreach my $pkg (split(/\s+/, get_var("TEST_PACKAGES", ""))) {
        run_command "zypper --gpg-auto-import-keys --no-gpg-checks -n install --force-resolution --allow-vendor-change $pkg || rpm -ivh --force --nodeps $pkg";
    }

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

    add_grub_cmdline_settings("systemd.unified_cgroup_hierarchy=1", update_grub => 1) if check_var('CONTAINERS_CGROUP_VERSION', '2');

    delegate_controllers;

    # We use ignore_loglevel to get task traces in case we get
    # "watchdog: BUG: soft lockup - CPU#1 stuck for 777s!"
    add_grub_cmdline_settings("ignore_loglevel", update_grub => 1);

    power_action('reboot', textmode => 1);
    $self->wait_boot();
    push @commands, "reboot";
    $rebooted = 1;

    select_serial_terminal;

    record_info "LSM", script_output("cat /sys/kernel/security/lsm", proceed_on_failure => 1);
    record_info "SELinux", script_output("cat /sys/fs/selinux/enforce", proceed_on_failure => 1) unless is_sle("<16");
}

sub collect_calltraces {
    my $dmesg = script_output('dmesg', proceed_on_failure => 1, quiet => 1, timeout => 180);
    return unless defined($dmesg);

    my $start = qr/(?:Call Trace:|-+\[ cut here \]-+)/;
    my $end = qr/(?:<\/TASK>|-+\[ end trace)/;

    my @lines = ();
    my @traces = ();
    my $in_trace = 0;

    for my $line (split /\n/, $dmesg) {
        $in_trace = 1 if $line =~ $start;
        push @lines, $line if $in_trace;

        if ($in_trace && $line =~ $end) {
            push @traces, join("\n", @lines);
            @lines = ();
            $in_trace = 0;
        }
    }

    push @traces, join("\n", @lines) if @lines;

    for my $trace (@traces) {
        record_info('TRACE', $trace);
    }
}

sub collect_coredumps {
    my $package = get_var("BATS_PACKAGE", "");
    my $backtrace = get_var("DEBUG");

    if ($backtrace) {
        script_run "sed -i s/enabled=0/enabled=1/ /etc/zypp/repos.d/*-[Dd]ebug.repo";
        script_run "zypper -n refresh", timeout => 300;
        script_run "zypper -n install -y gdb", timeout => 300;
        script_run "echo 'set debuginfod enabled on' > ~/.gdbinit";
        script_run "echo 'set pagination off' >> ~/.gdbinit";
    }

    script_run('coredumpctl list > coredumpctl.txt');

    # Get PID and executable for all dumps
    my @pids = split /\n/, script_output(q{coredumpctl -q --no-pager --no-legend | awk '$9 == "present" { print $5 }'}, proceed_on_failure => 1);

    foreach my $pid (@pids) {
        # Dumping and compressing coredumps may take some time
        my $out = script_output("coredumpctl info $pid", timeout => 300, proceed_on_failure => 1);
        record_info("COREDUMP", $out);

        if ($backtrace) {
            # First download debuginfo stuff to avoid polluting BACKTRACE info
            script_run "coredumpctl debug -A '-ex quit' $pid", timeout => 900;
            my $gdb_script = '-batch -ex "thread apply all bt full" -ex quit';
            record_info("BACKTRACE", script_output(qq{coredumpctl debug -A '$gdb_script' $pid}, timeout => 900, proceed_on_failure => 1));
        }

        my ($dump) = $out =~ /^\s*Storage:\s*(\S+)/m;
        script_run "mv $dump .", timeout => 300;
    }
}

sub bats_post_hook {
    select_serial_terminal;

    my $log_dir = "/tmp/logs/";
    assert_script_run "mkdir -p $log_dir || true";
    assert_script_run "cd $log_dir";

    script_run("rm -rf $test_dir", timeout => 0) unless ($test_dir eq "/var/tmp/");

    # Note: We don't use grep -q and redirect to /dev/null here to avoid SIGPIPE
    collect_calltraces if !script_run 'dmesg | grep -F -e "Call Trace:" -e "[ cut here ]" >/dev/null';
    collect_coredumps;

    script_run('df -h > df-h.txt');
    script_run('dmesg --read-clear > dmesg.txt');
    script_run('findmnt > findmnt.txt');
    script_run('free -h > free.txt');
    script_run('lscpu > lscpu.txt');
    script_run('lsmod > lsmod.txt');
    script_run('rpm -qa | sort > rpm-qa.txt', timeout => 180);
    script_run('sysctl -a > sysctl.txt');
    script_run('systemctl > systemctl.txt');
    script_run('systemctl status > systemctl-status.txt');
    script_run('systemctl list-unit-files > systemctl_units.txt');
    script_run('uname -a > uname.txt');
    script_run('journalctl -b > journalctl-b.txt', timeout => 120);
    script_run('tar zcf containers-conf.tgz $(find /etc/containerd /etc/containers /etc/docker /usr/share/containers -type f)');

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

    select_user_serial_terminal if (get_var("ROOTLESS") || script_output("id -u", proceed_on_failure => 1) ne "0");
}

sub bats_tests {
    my ($tapfile, $_env, $xfails, $timeout) = @_;
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
        umoci => "test",
    );

    my $tmp_dir = script_output "mktemp -du -p /var/tmp test.XXXXXX";
    run_command "mkdir -p $tmp_dir";

    $env{BATS_TMPDIR} = $tmp_dir;
    $env{TMPDIR} = $tmp_dir if ($package eq "buildah");
    $env{PATH} = '/usr/local/bin:$PATH:/usr/sbin:/sbin';
    my $env = join " ", map { "$_=$env{$_}" } sort keys %env;

    my @tests;
    foreach my $test (split(/\s+/, get_var("RUN_TESTS", ""))) {
        $test .= ".bats" unless $test =~ /\.bats$/;
        push @tests, "$tests_dir{$package}/$test";
    }
    my $tests = @tests ? join(" ", @tests) : $tests_dir{$package};

    my $debug = get_var("DEBUG") ? "--trace" : "";
    my $cmd = "$env bats $debug --report-formatter junit --tap -T $tests";
    my $xmlfile = "$tapfile.xml";
    $tapfile .= ".tap.txt";
    $cmd .= " </dev/null | tee -a $tapfile";

    run_command "echo $tapfile .. > $tapfile";
    my $ret = run_timeout_command($cmd, no_assert => 1, timeout => $timeout);
    script_run "mv report.xml $xmlfile";

    upload_logs($tapfile);
    my @xfails = get_var("RUN_TESTS") ? () : @{$xfails};
    # Strip control chars from XML as they aren't quoted and we can't quote them as valid XML 1.1
    # because it's not supported in most XML libraries anyway. See https://bugs.python.org/issue43703
    assert_script_run("LC_ALL=C sed -i 's/[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F]//g' $xmlfile") if ($package eq "umoci");
    my $version = script_output "rpm -q --queryformat '%{VERSION}' $package";
    patch_junit $package, $version, $xmlfile, @xfails;
    parse_extra_log(XUnit => $xmlfile, timeout => 180);

    script_run("rm -rf $tmp_dir || true", timeout => 0);

    return ($ret);
}

sub numeric_version {
    my $version = shift;

    # Sometimes version strings have a leading "v" or a trailing "-ce"
    # Strip leading & trailing non-digits from version
    $version =~ s/^\D+//;
    $version =~ s/\D+$//;
    return $version;
}

sub patch_sources {
    my ($package, $branch, $tests_dir) = @_;

    my $text = script_output("curl " . data_url("containers/patches.yaml"), quiet => 1);
    my $yaml = YAML::PP->new()->load_string($text);
    my $patches = $yaml->{$package} // {};

    my $version = numeric_version($branch);

    my @patches = split(/\s+/, get_var("GITHUB_PATCHES", ""));
    if (!@patches) {
        for my $pr (sort { $a <=> $b } keys %{$patches}) {
            my $def = $patches->{$pr} // {};
            # Skip if already merged in this version
            next if defined $def->{merged} && version->parse($version) >= version->parse("v$def->{merged}");
            # Skip if below minimum required version
            next if defined $def->{min} && version->parse($version) < version->parse("v$def->{min}");
            push @patches, $pr;
        }
    }
    # We use GITHUB_PATCHES="none" to specify that we don't want to patch anything
    @patches = () if check_var("GITHUB_PATCHES", "none");

    my $github_org = "containers";
    if ($package =~ /runc|umoci/) {
        $github_org = "opencontainers";
    } elsif ($package =~ /buildx|cli|compose|docker/) {
        $github_org = "docker";
    } elsif ($package =~ /moby/) {
        $github_org = "moby";
    } elsif ($package =~ /containerd/) {
        $github_org = "containerd";
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
    my $clone_opts = "--quiet --branch $branch";
    # If we don't have patches to apply, use a faster git-clone
    $clone_opts .= " --depth=1" unless @patches;
    run_command "git clone $clone_opts https://github.com/$github_org/$package.git", timeout => 300;
    $test_dir .= $package;
    run_command "cd $test_dir";

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
        $apply_cmd .= " || git apply -3 --ours --include '$tests_dir/*' $file" if $tests_dir;
        run_command $apply_cmd;
    }
}

1;
