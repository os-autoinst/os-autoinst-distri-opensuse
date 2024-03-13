# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: perl-base ltp
# Summary: Use perl script to run LTP on public cloud
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>, qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils;
use repo_tools 'generate_version';
use Mojo::UserAgent;
use LTP::utils qw(get_ltproot);
use LTP::WhiteList;
use Mojo::File;
use Mojo::JSON;
use publiccloud::utils qw(is_byos registercloudguest register_openstack);
use publiccloud::ssh_interactive 'select_host_console';
use Data::Dumper;
use version_utils;

our $root_dir = '/root';

sub get_ltp_rpm
{
    my ($url) = @_;
    my $ua = Mojo::UserAgent->new();
    my $links = $ua->get($url)->res->dom->find('a')->map(attr => 'href');
    for my $link (grep(/^ltp-20.*rpm$/, @{$links})) {
        return $link;
    }
    die('Could not find LTP package in ' . $url);
}

sub instance_log_args
{
    my $self = shift;
    return sprintf('"%s" "%s" "%s" "%s"',
        get_required_var('PUBLIC_CLOUD_PROVIDER'),
        $self->{my_instance}->instance_id,
        $self->{my_instance}->public_ip,
        $self->{provider}->{provider_client}->region);
}

sub upload_ltp_logs
{
    my ($self) = @_;
    record_info('LTP Logs', 'upload');
    assert_script_run("test -f $root_dir/result.json || echo No result log");
    parse_extra_log('LTP', "$root_dir/result.json");
    # debug file in the standart LTP log-dir. structure:
    assert_script_run("test -f /tmp/runltp.\$USER/latest/debug.log || echo No debug log");
    upload_logs("/tmp/runltp.\$USER/latest/debug.log", failok => 1);

    die $@ if $@;
}

sub run {
    my ($self, $args) = @_;
    my $arch = check_var('PUBLIC_CLOUD_ARCH', 'arm64') ? 'aarch64' : 'x86_64';
    my $ltp_repo = get_var('LTP_REPO', 'https://download.opensuse.org/repositories/benchmark:/ltp:/stable/' . generate_version("_") . '/');

    my $provider;
    my $instance;

    select_host_console();

    my $qam = get_var('PUBLIC_CLOUD_QAM', 0);
    if ($qam) {
        $instance = $self->{my_instance} = $args->{my_instance};
        $provider = $self->{provider} = $args->{my_provider};    # required for cleanup
    } else {
        $provider = $self->provider_factory();
        $instance = $self->{my_instance} = $provider->create_instance(check_guestregister => is_openstack ? 0 : 1);
    }

    assert_script_run("cd $root_dir");
    assert_script_run('curl ' . data_url('publiccloud/restart_instance.sh') . ' -o restart_instance.sh');
    assert_script_run('curl ' . data_url('publiccloud/log_instance.sh') . ' -o log_instance.sh');
    assert_script_run('chmod +x restart_instance.sh');
    assert_script_run('chmod +x log_instance.sh');

    registercloudguest($instance) if (is_byos() && !$qam);
    register_openstack($instance) if is_openstack;

    $instance->run_ssh_command(cmd => 'sudo zypper -n addrepo -fG ' . $ltp_repo . ' ltp_repo', timeout => 600);
    my $ltp_pkg = get_var('LTP_PKG', 'ltp-stable');
    $instance->run_ssh_command(cmd => "sudo zypper -n in $ltp_pkg", timeout => 600);

    my $ltp_env = gen_ltp_env($instance, $ltp_pkg);
    $self->{ltp_env} = $ltp_env;

    # Use lib/LTP/WhiteList module to exclude tests
    if (get_var('LTP_KNOWN_ISSUES')) {
        my $whitelist = LTP::WhiteList->new();
        my $exclude = get_var('LTP_COMMAND_EXCLUDE', '');
        my @skipped_tests = $whitelist->list_skipped_tests($ltp_env, get_required_var('LTP_COMMAND_FILE'));
        if (@skipped_tests) {
            $exclude .= '|' if (length($exclude) > 0);
            $exclude .= '^(' . join('|', @skipped_tests) . ')$';
            set_var('LTP_COMMAND_EXCLUDE', $exclude);
        }
    }

    my $runltp_ng_repo = get_var("LTP_RUN_NG_REPO", "https://github.com/linux-test-project/runltp-ng.git");
    my $runltp_ng_branch = get_var("LTP_RUN_NG_BRANCH", "master");
    record_info('LTP CLONE REPO', "Repo: " . $runltp_ng_repo . "\nBranch: " . $runltp_ng_branch);

    assert_script_run("git clone -q --single-branch -b $runltp_ng_branch --depth 1 $runltp_ng_repo");
    $instance->run_ssh_command(cmd => 'sudo CREATE_ENTRIES=1 ' . get_ltproot() . '/IDcheck.sh', timeout => 300);
    record_info('Kernel info', $instance->run_ssh_command(cmd => q(rpm -qa 'kernel*' --qf '%{NAME}\n' | sort | uniq | xargs rpm -qi)));
    record_info('VM Detect', $instance->run_ssh_command(cmd => 'systemd-detect-virt'));

    my $reset_cmd = $root_dir . '/restart_instance.sh ' . $self->instance_log_args();
    my $log_start_cmd = $root_dir . '/log_instance.sh start ' . $self->instance_log_args();

    my $env = get_var('LTP_PC_RUNLTP_ENV');

    assert_script_run($log_start_cmd);

    # LTP command line preparation
    # The python3-paramiko is too old (2.4 on 15-SP6)
    # The python311-paramiko is from SLE-Module-Python3-15-SP5-Updates which we have in PC tools image
    zypper_call("in python311-paramiko python311-scp");

    my $sut = ':user=' . $instance->username;
    $sut .= ':sudo=1';
    $sut .= ':key_file=$(realpath ' . $instance->provider->ssh_key . ')';
    $sut .= ':host=' . $instance->public_ip;
    $sut .= ':reset_command=\'' . $reset_cmd . '\'';
    $sut .= ':hostkey_policy=missing';
    $sut .= ':known_hosts=/dev/null';

    my $cmd = 'python3.11 runltp-ng/runltp-ng ';
    $cmd .= "--json-report=$root_dir/result.json ";
    $cmd .= '--verbose ';
    $cmd .= '--exec-timeout=1200 ';
    $cmd .= '--suite-timeout=5400 ';
    $cmd .= '--run-suite ' . get_required_var('LTP_COMMAND_FILE') . ' ';
    $cmd .= '--skip-tests \'' . get_var('LTP_COMMAND_EXCLUDE') . '\' ' if get_var('LTP_COMMAND_EXCLUDE');
    $cmd .= '--sut=ssh' . $sut . ' ';
    $cmd .= '--env ' . $env . ' ' if ($env);
    record_info('LTP START', 'Command launch');
    assert_script_run($cmd, timeout => get_var('LTP_TIMEOUT', 30 * 60));
    record_info('LTP END', 'tests done');
}


sub cleanup {
    my ($self) = @_;

    # Ensure that the ltp script gets killed
    type_string('', terminate_with => 'ETX');
    $self->upload_ltp_logs();
    if ($self->{my_instance} && script_run("test -f $root_dir/log_instance.sh") == 0) {
        assert_script_run($root_dir . '/log_instance.sh stop ' . $self->instance_log_args());
        assert_script_run("(cd /tmp/log_instance && tar -zcf $root_dir/instance_log.tar.gz *)");
        upload_logs("$root_dir/instance_log.tar.gz", failok => 1);
    }
}

sub gen_ltp_env {
    my ($instance, $ltp_pkg) = @_;
    my $environment = {
        product => get_required_var('DISTRI') . ':' . get_required_var('VERSION'),
        revision => get_required_var('BUILD'),
        arch => get_var('PUBLIC_CLOUD_ARCH', get_required_var("ARCH")),
        kernel => $instance->run_ssh_command(cmd => 'uname -r'),
        backend => get_required_var('BACKEND'),
        flavor => get_required_var('FLAVOR'),
        ltp_version => $instance->run_ssh_command(cmd => qq(rpm -q --qf '%{VERSION}\n' $ltp_pkg)),
    };

    record_info("LTP Environment", Dumper($environment));

    return $environment;
}

1;

=head1 Discussion

Test module to run LTP test on publiccloud. The test run on a local qemu instance
and connect to the CSP instance using SSH. This is done via the run_ltp_ssh.pl script.
