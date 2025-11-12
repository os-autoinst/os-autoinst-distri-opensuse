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
use version_utils qw(is_jeos is_released is_sle is_leap is_tumbleweed is_rt is_transactional);
use File::Basename 'basename';
use Utils::Architectures;
use repo_tools 'add_qa_head_repo';
use utils;
use kernel 'get_kernel_flavor';

our @EXPORT = qw(
  check_kernel_taint
  export_ltp_env
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
  add_ltp_repo
  get_default_pkg
  install_from_repo
  prepare_whitelist_environment
  setup_kernel_logging
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
    my $pkg = shift // get_var('LTP_PKG', '');

    # TEST is for running 32bit tests (e.g. ltp_syscalls_m32), checking
    # LTP_PKG is for install_ltp.pm which also uses prepare_ltp_env()
    return (get_required_var('TEST') =~ m/[-_]m32$/
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
      (is_rt ? 'kernel-rt' : get_kernel_flavor);
    my $kernel_pkg_log = '/tmp/kernel-pkg.txt';
    my $ver_linux_log = '/tmp/ver_linux_before.txt';
    my $kernel_config = script_output('for f in "/boot/config-$(uname -r)" "/usr/lib/modules/$(uname -r)/config" /proc/config.gz; do if [ -f "$f" ]; then echo "$f"; break; fi; done');
    my $run_cmd = is_transactional ? 'transactional-update -c run ' : '';

    script_run("$run_cmd rpm -qi $kernel_pkg > $kernel_pkg_log 2>&1", timeout => 120);
    upload_logs($kernel_pkg_log, failok => 1);

    if (get_var('LTP_COMMAND_FILE') || get_var('LIBC_LIVEPATCH')) {
        script_run("$run_cmd " . get_ltproot . "/ver_linux > $ver_linux_log 2>&1");
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
    record_info('KERNEL EXTRA PKG', script_output("$run_cmd rpm -qi kernel-default-extra", proceed_on_failure => 1));
    record_info('KERNEL pkg', script_output("$run_cmd rpm -qa | grep kernel", proceed_on_failure => 1));

    if (get_var('LTP_COMMAND_FILE') || get_var('LIBC_LIVEPATCH')) {
        record_info('ver_linux', script_output("cat $ver_linux_log", proceed_on_failure => 1));
    }

    script_run('env');
    script_run('aa-enabled; aa-status');
}

sub export_ltp_env {
    my $ltp_env = get_var('LTP_ENV');

    if ($ltp_env) {
        $ltp_env =~ s/,/ /g;
        script_run("export $ltp_env");
    }
}

# Set up basic shell environment for running LTP tests
sub prepare_ltp_env {
    assert_script_run('export LTPROOT=' . get_ltproot() . '; export LTP_COLORIZE_OUTPUT=n TMPDIR=/tmp PATH=$LTPROOT/testcases/bin:$PATH');

    # setup for LTP networking tests
    assert_script_run("export PASSWD='$testapi::password'");

    my $block_dev = get_var('LTP_BIG_DEV');
    if ($block_dev && get_var('NUMDISKS') > 1) {
        assert_script_run("lsblk -la; export LTP_BIG_DEV=$block_dev");
    }

    export_ltp_env;
    assert_script_run('cd $LTPROOT/testcases/bin');
}

sub parse_int {
    my $val = shift;

    return oct($val) if $val =~ m/^0/;
    return $val + 0;
}

sub check_kernel_taint {
    my ($testmod, $softfail) = @_;

    my @flag_desc = (
        'Proprietary module was loaded',
        'Module was force loaded',
        'Kernel running on out of specification system',
        'Module was force unloaded',
        'Processor reported Machine Check Exception (MCE)',
        'Bad page referenced or unexpected page flags',
        'Taint requested by userspace application',
        'Kernel died recently (OOPS or BUG)',
        'ACPI table overridden by user',
        'Kernel issued warning',
        'Staging driver was loaded',
        'Workaround for platform firmware bug',
        'Out of tree module was loaded',
        'Unsigned module was loaded',
        'Soft lockup occurred',
        'Kernel was live patched',
        'Externally supported module was loaded or auxiliary taint',
        'Kernel was built with struct randomization',
        'In-kernel test has been run'
    );
    $flag_desc[31] = 'Unsupported module was loaded';

    my $flag = 1;
    my $taint_undef = 0;
    my (@taint, @exp_taint);

    # Default taint mask:
    # - Proprietary module was loaded (0x1)
    # - Workaround for platform firmware bug (0x800)
    # - Out of tree module was loaded (0x1000)
    # - Kernel was live patched (0x8000)
    # - Externally supported module was loaded or auxiliary taint (0x10000)
    # - Unsupported module was loaded (0x80000000)
    my $taint_mask = parse_int(get_var('LTP_TAINT_EXPECTED', 0x80019801));
    my $taint_val = script_output('cat /proc/sys/kernel/tainted');

    my $i = 0;
    for my $desc (@flag_desc) {
        $desc .= sprintf(" (0x%x, 1 << $i)", $flag);
        if ($flag & $taint_val) {
            unless (defined($desc)) {
                $taint_undef = 1;
            }
            elsif ($flag & $taint_mask) {
                push @exp_taint, "- $desc";
            }
            else {
                push @taint, "- $desc";
            }
        }

        $flag <<= 1;
        $i += 1;
    }

    my $message = sprintf("Kernel taint: 0x%x", $taint_val);
    push @taint, '- Unknown tainted state' if $taint_undef;
    $message = "$message (OK)" unless @taint;
    $message .= "\n\nUnexpected taint:\n" . join("\n", @taint) if @taint;
    $message .= "\n\nExpected taint:\n" . join("\n", @exp_taint) if @exp_taint;

    unless (@taint) {
        $testmod->record_resultfile('Kernel taint OK', $message,
            result => 'ok');
    }
    elsif ($softfail) {
        $testmod->record_soft_failure_result($message);
    }
    else {
        $testmod->record_resultfile('Kernel tainted', $message,
            result => 'fail');
        $testmod->{result} = 'fail';
    }
}

sub init_ltp_tests {
    my $cmd_file = shift;
    my $is_network = $cmd_file =~ m/^\s*(net|net_stress)\./;
    my $is_ima = $cmd_file =~ m/^ima$/i;

    script_run('ps axf') if ($is_network || $is_ima);

    if ($is_network) {
        # Disable IPv4 and IPv6 iptables.
        # Disabling IPv4 is needed for iptables tests (net.tcp_cmds).
        # Disabling IPv6 is needed for ICMPv6 tests (net.ipv6).
        # This must be done after stopping network service.
        my $disable_iptables_script = <<'EOF';
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
        script_run('ss -nap || netstat -nap');

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
    my $environment = prepare_whitelist_environment();

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
    record_info("env", script_output('env'));

    $test_result_export->{environment} = $environment;

    if ($cmd_file =~ m/ltp-aiodio.part[134]/) {
        loadtest_kernel 'create_junkfile_ltp';
    }

    if ($cmd_file =~ m/lvm\.local/) {
        loadtest_kernel 'ltp_init_lvm';
    }

    parse_runfiles($cmd_file, $test_result_export, $suffix);

    if (check_var('KGRAFT', 1) && check_var('KGRAFT_DOWNGRADE', 1)) {
        loadtest_kernel 'klp_downgrade';
        parse_runfiles($cmd_file, $test_result_export, $suffix . '_postun');
    }
    elsif (check_var('KGRAFT', 1) && check_var('UNINSTALL_INCIDENT', 1)) {
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

    for my $line (@$cmds) {
        chomp($line);
        my $testname = basename($line, '.run-test') . $suffix;

        if ($testname =~ m/$cmd_pattern/ && !($testname =~ m/$cmd_exclude/)) {
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
    my @tests = ();

    for my $line (@$cmds) {
        next if ($line =~ /(^#)|(^$)/);
        #Command format is "<name> <command> [<args>...] [#<comment>]"
        next if ($line !~ /^\s* ([\w-]+) \s+ (\S.+) #?/gx);
        next if (is_svirt && ($1 eq 'dnsmasq' || $1 eq 'dhcpd'));    # poo#33850

        my $test = {name => $1 . $suffix, command => $2, last => 0};
        if ($test->{name} =~ m/$cmd_pattern/ && !($test->{name} =~ m/$cmd_exclude/)) {
            push @tests, $test;
        }
    }

    ${tests [-1]}->{last} = 1 if (@tests);

    for my $test (@tests) {
        my $tinfo = testinfo($test_result_export, test => $test, runfile => $name);
        loadtest_runltp($test->{name}, $tinfo, $whitelist);
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

sub add_ltp_repo {
    my $repo = get_var('LTP_REPOSITORY');

    if (!$repo) {
        if (is_sle || is_transactional) {
            add_qa_head_repo;
            return;
        }

        # ltp for leap15.2 is available only x86_64
        if (is_leap('15.4+')) {
            $repo = get_var('VERSION');
        } elsif ((is_leap('=15.2') && is_x86_64) || is_leap('15.3+')) {
            $repo = sprintf("openSUSE_Leap_%s", get_var('VERSION'));
        } elsif (is_tumbleweed) {
            $repo = "openSUSE_Factory";
            $repo = "openSUSE_Factory_ARM" if (is_aarch64() || is_arm());
            $repo = "openSUSE_Factory_PowerPC" if is_ppc64le();
            $repo = "openSUSE_Factory_RISCV" if is_riscv();
            $repo = "openSUSE_Factory_zSystems" if is_s390x();
        } else {
            die sprintf("Unexpected combination of version (%s) and architecture (%s) used", get_var('VERSION'), get_var('ARCH'));
        }
        $repo = "https://download.opensuse.org/repositories/benchmark:/ltp:/devel/$repo/";
    }

    zypper_ar($repo, name => 'ltp_repo');
}

sub get_default_pkg {
    my @packages;

    if (is_sle && is_released) {
        push @packages, 'ltp-stable';
        push @packages, 'ltp-stable-32bit' if is_x86_64;
    } else {
        push @packages, 'ltp';
        push @packages, 'ltp-32bit' if is_x86_64 && !is_jeos;
    }

    return join(' ', @packages);
}

sub install_from_repo {
    # Workaround for kernel-64kb, until we add multibuild support to LTP package
    # Lock kernel-default to don't pull it as LTP dependency
    zypper_call 'al kernel-default' if get_kernel_flavor eq 'kernel-64kb';

    my @pkgs = split(/\s* \s*/, get_var('LTP_PKG', get_default_pkg));

    if (is_transactional) {
        assert_script_run("transactional-update -n -c pkg install --recommends " . join(' ', @pkgs), 180);
    } else {
        zypper_call("in --recommends " . join(' ', @pkgs));
    }

    my $run_cmd = is_transactional ? 'transactional-update -c -d --quiet run' : '';
    for my $pkg (@pkgs) {
        my $want_32bit = want_ltp_32bit($pkg);

        record_info("LTP pkg: $pkg", script_output("$run_cmd rpm -qi $pkg | tee "
                  . get_ltp_version_file($want_32bit)));
        assert_script_run "find " . get_ltproot($want_32bit) .
          q(/testcases/bin/openposix/conformance/interfaces/ -name '*.run-test' > )
          . get_ltp_openposix_test_list_file($want_32bit);
    }
}

sub prepare_whitelist_environment {
    my $environment = {
        product => get_var('DISTRI') . ':' . get_var('VERSION'),
        revision => get_var('BUILD'),
        flavor => get_var('FLAVOR'),
        arch => get_var('ARCH'),
        backend => get_var('BACKEND'),
        machine => get_var('MACHINE'),
        kernel => '',
        libc => '',
        gcc => '',
        harness => 'SUSE OpenQA',
        ltp_version => ''
    };

    return $environment;
}

# NOTE: root is expected
sub setup_kernel_logging {
    my $grub_param = 'ignore_loglevel';

    # /sys/module/printk/parameters/ignore_loglevel was added to mainline in v3.2-rc1 in
    # 0eca6b7c78fd ("printk: add module parameter ignore_loglevel to control ignore_loglevel").
    # Therefore SLE11-SP4 doesn't support it (but it supports ignore_loglevel
    # as an early kernel command-line parameter => ok to add it to grub).
    script_run('echo 1 >/sys/module/printk/parameters/ignore_loglevel')
      unless is_sle('<12');

    if (script_output('cat /sys/module/printk/parameters/time') eq 'N') {
        script_run('echo 1 > /sys/module/printk/parameters/time');
        $grub_param .= ' printk.time=1';
    }

    return $grub_param;
}

1;
