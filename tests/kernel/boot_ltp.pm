# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Waits for the guest to boot, sets some variables for LTP then
#          dynamically loads the test modules based on the runtest file
#          contents.
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;
use LTP::WhiteList 'download_whitelist';
use LTP::utils;
use LTP::TestInfo 'testinfo';
use version_utils 'is_jeos';
use main_ltp qw(loadtest_kernel shutdown_ltp);
use File::Basename 'basename';

sub run {
    my ($self) = @_;
    my $cmd_file = get_var('LTP_COMMAND_FILE') || '';
    my $is_network = $cmd_file =~ m/^\s*(net|net_stress)\./;
    my $is_ima     = $cmd_file =~ m/^ima$/i;

    if (check_var('BACKEND', 'ipmi')) {
        record_info('INFO', 'IPMI boot');
        select_console 'sol', await_console => 0;
        assert_screen('linux-login', 1800);
    }
    elsif (is_jeos) {
        record_info('Loaded JeOS image', 'nothing to do...');
    }
    else {
        record_info('INFO', 'normal boot or boot with params');
        # during install_ltp, the second boot may take longer than usual
        $self->wait_boot(ready_time => 1800);
    }

    $self->select_serial_terminal;

    download_whitelist if get_var('LTP_KNOWN_ISSUES');

    # check kGraft patch if KGRAFT=1
    if (check_var('KGRAFT', '1') && !check_var('REMOVE_KGRAFT', '1')) {
        assert_script_run("uname -v| grep -E '(/kGraft-|/lp-)'");
    }

    prepare_ltp_env();
    script_run('env');
    upload_logs('/boot/config-$(uname -r)', failok => 1);

    my $kernel_pkg_log = '/tmp/kernel-pkg.txt';
    script_run('rpm -qi ' . ((is_jeos) ? 'kernel-default-base' : 'kernel-default') . " > $kernel_pkg_log 2>&1");
    upload_logs($kernel_pkg_log, failok => 1);

    my $ver_linux_log = '/tmp/ver_linux_before.txt';
    script_run("\$LTPROOT/ver_linux > $ver_linux_log 2>&1");
    upload_logs($ver_linux_log, failok => 1);

    script_run('ps axf') if ($is_network || $is_ima);

    script_run('aa-enabled; aa-status');

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

    # If the command file (runtest file) is set then we dynamically schedule
    # the test and shutdown modules.
    schedule_tests($cmd_file) if $cmd_file;
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
    my ($cmd_file) = @_;

    my $test_result_export = {
        format      => 'result_array:v2',
        environment => {},
        results     => []};
    my $cmd_pattern = get_var('LTP_COMMAND_PATTERN') || '.*';
    my $cmd_exclude = get_var('LTP_COMMAND_EXCLUDE') || '$^';
    my $environment = {
        product     => get_var('DISTRI') . ':' . get_var('VERSION'),
        revision    => get_var('BUILD'),
        flavor      => get_var('FLAVOR'),
        arch        => get_var('ARCH'),
        backend     => get_var('BACKEND'),
        kernel      => '',
        libc        => '',
        gcc         => '',
        harness     => 'SUSE OpenQA',
        ltp_version => ''
    };
    my $ver_linux_out = script_output("cat /tmp/ver_linux_before.txt");
    if ($ver_linux_out =~ qr'^Linux\s+(.*?)\s*$'m) {
        $environment->{kernel} = $1;
    }
    if ($ver_linux_out =~ qr'^Linux C Library\s*>?\s*(.*?)\s*$'m) {
        $environment->{libc} = $1;
    }
    if ($ver_linux_out =~ qr'^Gnu C\s*(.*?)\s*$'m) {
        $environment->{gcc} = $1;
    }
    $environment->{ltp_version}        = script_output('touch /opt/ltp_version; cat /opt/ltp_version');
    $test_result_export->{environment} = $environment;

    if ($cmd_file =~ m/ltp-aiodio.part[134]/) {
        loadtest_kernel 'create_junkfile_ltp';
    }

    if ($cmd_file =~ m/lvm\.local/) {
        loadtest_kernel 'ltp_init_lvm';
    }

    for my $name (split(/,/, $cmd_file)) {
        if ($name eq 'openposix') {
            parse_openposix_runfile($name,
                read_runfile('/root/openposix-test-list'),
                $cmd_pattern, $cmd_exclude, $test_result_export);
        }
        else {
            parse_runtest_file($name, read_runfile("/opt/ltp/runtest/$name"),
                $cmd_pattern, $cmd_exclude, $test_result_export);
        }
    }

    shutdown_ltp(run_args => testinfo($test_result_export));
}

sub parse_openposix_runfile {
    my ($name, $cmds, $cmd_pattern, $cmd_exclude, $test_result_export) = @_;

    for my $line (@$cmds) {
        chomp($line);
        if ($line =~ m/$cmd_pattern/ && !($line =~ m/$cmd_exclude/)) {
            my $test  = {name => basename($line, '.run-test'), command => $line};
            my $tinfo = testinfo($test_result_export, test => $test, runfile => $name);
            loadtest_kernel('run_ltp', name => $test->{name}, run_args => $tinfo);
        }
    }
}

sub parse_runtest_file {
    my ($name, $cmds, $cmd_pattern, $cmd_exclude, $test_result_export) = @_;

    for my $line (@$cmds) {
        next if ($line =~ /(^#)|(^$)/);

        #Command format is "<name> <command> [<args>...] [#<comment>]"
        if ($line =~ /^\s* ([\w-]+) \s+ (\S.+) #?/gx) {
            next if (check_var('BACKEND', 'svirt') && ($1 eq 'dnsmasq' || $1 eq 'dhcpd'));    # poo#33850
            my $test  = {name => $1, command => $2};
            my $tinfo = testinfo($test_result_export, test => $test, runfile => $name);
            if ($test->{name} =~ m/$cmd_pattern/ && !($test->{name} =~ m/$cmd_exclude/)) {
                loadtest_kernel('run_ltp', name => $test->{name}, run_args => $tinfo);
            }
        }
    }
}

sub test_flags {
    return {
        fatal     => 1,
        milestone => 1,
    };
}

1;

=head1 Configuration

See run_ltp.pm.

=cut
