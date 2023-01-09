# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: LTP helper functions
# Maintainer: Martin Doucha <mdoucha@suse.cz>

package LTP::utils;

use base Exporter;
use strict;
use warnings;
use testapi;
use Utils::Backends;
use autotest;
use LTP::WhiteList;
use LTP::TestInfo 'testinfo';
use version_utils qw(is_jeos is_openstack is_rt);
use File::Basename 'basename';
use Utils::Architectures;

our @EXPORT = qw(
  get_ltproot
  get_ltp_openposix_test_list_file
  get_ltp_version_file
  init_ltp_tests
  loadtest_kernel
  log_versions
  prepare_ltp_env
  schedule_tests
  shutdown_ltp
  want_ltp_32bit
);

sub loadtest_kernel {
    my ($test, %args) = @_;
    autotest::loadtest("tests/kernel/$test.pm", %args);
}

sub loadtest_runltp {
    my ($name, $tinfo, $whitelist) = @_;
    my %env = %{$tinfo->test_result_export->{environment}};
    $env{retval} = 'none';

    if ($whitelist->is_test_disabled(\%env, $tinfo->runfile, $name)) {
        bmwqemu::diag("skipping $name (disabled by LTP_KNOWN_ISSUES)");
        return;
    }

    loadtest_kernel('run_ltp', name => $name, run_args => $tinfo);
}

sub shutdown_ltp {
    loadtest_kernel('proc_sys_dump') if get_var('PROC_SYS_DUMP');
    loadtest_kernel('shutdown_ltp', @_);
}

sub want_ltp_32bit {
    my $pkg = shift // get_var('LTP_PKG');

    # TEST_SUITE_NAME is for running 32bit tests (e.g. ltp_syscalls_m32),
    # checking LTP_PKG is for install_ltp.pm which also uses prepare_ltp_env()
    return (get_required_var('TEST_SUITE_NAME') =~ m/[-_]m32$/
          || $pkg =~ m/-32bit$/
          || is_32bit);
}

sub get_ltproot {
    my $want_32bit = shift // want_ltp_32bit;

    return $want_32bit ? '/opt/ltp-32' : '/opt/ltp';
}

sub get_ltp_openposix_test_list_file {
    my $want_32bit = shift // want_ltp_32bit;

    return get_ltproot($want_32bit) . '/runtest/openposix-test-list';
}

sub get_ltp_version_file {
    my $want_32bit = shift // want_ltp_32bit;

    return get_ltproot($want_32bit) . '/version';
}

sub log_versions {
    my $report_missing_config = shift;
    my $kernel_pkg = is_jeos || get_var('KERNEL_BASE') ? 'kernel-default-base' :
      (is_rt ? 'kernel-rt' : 'kernel-default');
    my $kernel_pkg_log = '/tmp/kernel-pkg.txt';
    my $ver_linux_log = '/tmp/ver_linux_before.txt';
    my $kernel_config = script_output('for f in "/boot/config-$(uname -r)" "/usr/lib/modules/$(uname -r)/config" /proc/config.gz; do if [ -f "$f" ]; then echo "$f"; break; fi; done');

    script_run("rpm -qi $kernel_pkg > $kernel_pkg_log 2>&1");
    upload_logs($kernel_pkg_log, failok => 1);

    if (get_var('LTP_COMMAND_FILE') || get_var('LIBC_LIVEPATCH')) {
        script_run(get_ltproot . "/ver_linux > $ver_linux_log 2>&1");
        upload_logs($ver_linux_log, failok => 1);
    }

    if ($kernel_config) {
        my $cmd = "echo '# $kernel_config'; echo; ";

        upload_logs($kernel_config, failok => 1);

        if ($kernel_config eq '/proc/config.gz') {
            record_soft_failure 'boo#1189879 missing kernel config in kernel package, use /proc/config.gz' if $report_missing_config;
            $cmd .= "zcat $kernel_config";
        } else {
            if ($report_missing_config && $kernel_config !~ /^\/boot\/config-/) {
                record_soft_failure 'boo#1189879 missing symlink to /boot, use config in /usr/lib/modules/';
            }
            $cmd .= "cat $kernel_config";
        }

        record_info('KERNEL CONFIG', script_output("$cmd"));
    } elsif ($report_missing_config) {
        record_soft_failure 'boo#1189879 missing kernel config';
    }

    record_info('KERNEL VERSION', script_output('uname -a'));
    record_info('KERNEL DEFAULT PKG', script_output("cat $kernel_pkg_log", proceed_on_failure => 1));
    record_info('KERNEL EXTRA PKG', script_output('rpm -qi kernel-default-extra', proceed_on_failure => 1));

    record_info('KERNEL pkg', script_output('rpm -qa | grep kernel', proceed_on_failure => 1));

    if (get_var('LTP_COMMAND_FILE') || get_var('LIBC_LIVEPATCH')) {
        record_info('ver_linux', script_output("cat $ver_linux_log", proceed_on_failure => 1));
    }

    script_run('env');
    script_run('aa-enabled; aa-status');
}


# Set up basic shell environment for running LTP tests
sub prepare_ltp_env {
    my $ltp_env = get_var('LTP_ENV');

    assert_script_run('export LTPROOT=' . get_ltproot() . '; export LTP_COLORIZE_OUTPUT=n TMPDIR=/tmp PATH=$LTPROOT/testcases/bin:$PATH');

    # setup for LTP networking tests
    assert_script_run("export PASSWD='$testapi::password'");

    my $block_dev = get_var('LTP_BIG_DEV');
    if ($block_dev && get_var('NUMDISKS') > 1) {
        assert_script_run("lsblk -la; export LTP_BIG_DEV=$block_dev");
    }

    if ($ltp_env) {
        $ltp_env =~ s/,/ /g;
        script_run("export $ltp_env");
    }

    assert_script_run('cd $LTPROOT/testcases/bin');
}

sub init_ltp_tests {
    my $cmd_file = shift;
    my $is_network = $cmd_file =~ m/^\s*(net|net_stress)\./;
    my $is_ima = $cmd_file =~ m/^ima$/i;

    script_run('ps axf') if ($is_network || $is_ima);

    if ($is_network) {
        # emulate $LTPROOT/testscripts/network.sh
        assert_script_run('curl ' . data_url("ltp/net.sh") . ' -o net.sh', 60);
        assert_script_run('chmod 755 net.sh');
        assert_script_run('. ./net.sh');

        script_run('env');

        # Disable IPv4 and IPv6 iptables.
        # Disabling IPv4 is needed for iptables tests (net.tcp_cmds).
        # Disabling IPv6 is needed for ICMPv6 tests (net.ipv6).
        # This must be done after stopping network service and loading
        # test_net.sh script.
        my $disable_iptables_script = << 'EOF';
iptables -P INPUT ACCEPT;
iptables -P OUTPUT ACCEPT;
iptables -P FORWARD ACCEPT;
iptables -t nat -F;
iptables -t mangle -F;
iptables -F;
iptables -X;

ip6tables -P INPUT ACCEPT;
ip6tables -P OUTPUT ACCEPT;
ip6tables -P FORWARD ACCEPT;
ip6tables -t nat -F;
ip6tables -t mangle -F;
ip6tables -F;
ip6tables -X;
EOF
        script_output($disable_iptables_script);
        # display resulting iptables
        script_run('iptables -L');
        script_run('iptables -S');
        script_run('ip6tables -L');
        script_run('ip6tables -S');

        # display various network configuration
        script_run('netstat -nap');

        script_run('cat /etc/resolv.conf');
        script_run('f=/etc/nsswitch.conf; [ ! -f $f ] && f=/usr$f; cat $f');
        script_run('cat /etc/hosts');

        # hostname (getaddrinfo_01)
        script_run('hostnamectl');
        script_run('cat /etc/hostname');

        script_run('ip addr');
        script_run('ip netns exec ltp_ns ip addr');
        script_run('ip route');
        script_run('ip -6 route');

        script_run('ping -c 2 $IPV4_LNETWORK.$LHOST_IPV4_HOST');
        script_run('ping -c 2 $IPV4_RNETWORK.$RHOST_IPV4_HOST');
        script_run('ping6 -c 2 $IPV6_LNETWORK:$LHOST_IPV6_HOST');
        script_run('ping6 -c 2 $IPV6_RNETWORK:$RHOST_IPV6_HOST');
    }

    # Check and activate hugepages before test execution
    script_run 'grep -e Huge -e PageTables /proc/meminfo';
    script_run 'echo 1 > /proc/sys/vm/nr_hugepages';
    script_run 'grep -e Huge -e PageTables /proc/meminfo';
}

sub read_runfile {
    my ($runfile_path) = @_;
    my $basename = basename($runfile_path);
    my @ret;

    upload_asset($runfile_path);
    open my $rf, "assets_private/$basename" or die "Cannot open runfile $basename: $!";

    while (my $line = <$rf>) {
        push @ret, $line;
    }

    close($rf);
    return \@ret;
}

sub schedule_tests {
    my ($cmd_file, $suffix) = @_;
    $suffix //= '';

    my $test_result_export = {
        format => 'result_array:v2',
        environment => {},
        results => []};
    my $environment = {
        product => get_var('DISTRI') . ':' . get_var('VERSION'),
        revision => get_var('BUILD'),
        flavor => get_var('FLAVOR'),
        arch => get_var('ARCH'),
        backend => get_var('BACKEND'),
        kernel => '',
        libc => '',
        gcc => '',
        harness => 'SUSE OpenQA',
        ltp_version => ''
    };

    my $ver_linux_out = script_output("cat /tmp/ver_linux_before.txt");
    if ($ver_linux_out =~ qr'^Linux C Library\s*>?\s*(.*?)\s*$'m) {
        $environment->{libc} = $1;
    }
    if ($ver_linux_out =~ qr'^Gnu C\s*(.*?)\s*$'m) {
        $environment->{gcc} = $1;
    }

    my $file = get_ltp_version_file();
    $environment->{kernel} = script_output('uname -r');
    $environment->{ltp_version} = script_output("touch $file; cat $file");
    record_info("LTP version", $environment->{ltp_version});

    $test_result_export->{environment} = $environment;

    if ($cmd_file =~ m/ltp-aiodio.part[134]/) {
        loadtest_kernel 'create_junkfile_ltp';
    }

    if ($cmd_file =~ m/lvm\.local/) {
        loadtest_kernel 'ltp_init_lvm';
    }

    parse_runfiles($cmd_file, $test_result_export, $suffix);

    if (check_var('KGRAFT', 1) && check_var('UNINSTALL_INCIDENT', 1)) {
        loadtest_kernel 'uninstall_incident';
        parse_runfiles($cmd_file, $test_result_export, $suffix . '_postun');
    }

    shutdown_ltp(run_args => testinfo($test_result_export))
      unless get_var('LIBC_LIVEPATCH');
}

sub parse_openposix_runfile {
    my ($name, $cmds, $cmd_pattern, $cmd_exclude, $test_result_export, $suffix) = @_;
    my $ulp_test = get_var('LIBC_LIVEPATCH', 0);
    my $whitelist = LTP::WhiteList->new();

    assert_script_run('export LD_PRELOAD=/usr/lib64/libpulp.so.0')
      if ($ulp_test);

    for my $line (@$cmds) {
        chomp($line);
        if ($line =~ m/$cmd_pattern/ && !($line =~ m/$cmd_exclude/)) {
            my $testname = basename($line, '.run-test') . $suffix;

            # For ULP tests, start all processes in the background immediately
            # and change the test command to unpause the existing process
            if ($ulp_test) {
                my $pid = background_script_run("$line --livepatch");
                $line = "kill -s SIGUSR1 $pid; wait $pid";
            }

            my $test = {name => $testname, command => $line};
            my $tinfo = testinfo($test_result_export, test => $test, runfile => $name);

            loadtest_runltp($test->{name}, $tinfo, $whitelist);
        }
    }
}

sub parse_runtest_file {
    my ($name, $cmds, $cmd_pattern, $cmd_exclude, $test_result_export, $suffix) = @_;
    my $whitelist = LTP::WhiteList->new();

    for my $line (@$cmds) {
        next if ($line =~ /(^#)|(^$)/);

        #Command format is "<name> <command> [<args>...] [#<comment>]"
        next if ($line !~ /^\s* ([\w-]+) \s+ (\S.+) #?/gx);
        next if (is_svirt && ($1 eq 'dnsmasq' || $1 eq 'dhcpd'));    # poo#33850
        my $test = {name => $1 . $suffix, command => $2};
        my $tinfo = testinfo($test_result_export, test => $test, runfile => $name);

        if ($test->{name} =~ m/$cmd_pattern/ && !($test->{name} =~ m/$cmd_exclude/)) {
            loadtest_runltp($test->{name}, $tinfo, $whitelist);
        }
    }
}

# NOTE: current implementation does not allow to run tests on both archs
sub parse_runfiles {
    my ($cmd_file, $test_result_export, $suffix) = @_;

    my $cmd_pattern = get_var('LTP_COMMAND_PATTERN') || '.*';
    my $cmd_exclude = get_var('LTP_COMMAND_EXCLUDE') || '$^';

    $suffix //= '';

    for my $name (split(/,/, $cmd_file)) {
        if ($name eq 'openposix') {
            parse_openposix_runfile($name,
                read_runfile(get_ltp_openposix_test_list_file()),
                $cmd_pattern, $cmd_exclude, $test_result_export, $suffix);
        }
        else {
            parse_runtest_file($name, read_runfile(get_ltproot() . "/runtest/$name"),
                $cmd_pattern, $cmd_exclude, $test_result_export, $suffix);
        }
    }
}

1;
