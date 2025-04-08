# SUSE's openQA tests
#
# Copyright 2018-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: perl-base ltp
# Summary: Use perl script to run LTP on public cloud
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>, qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils;
use repo_tools 'generate_version';
use Mojo::File;
use Mojo::JSON;
use Mojo::UserAgent;
use LTP::utils qw(get_ltproot);
use LTP::WhiteList;
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
    my ($provider, $instance) = @_;
    return sprintf('"%s" "%s" "%s" "%s"',
        get_required_var('PUBLIC_CLOUD_PROVIDER'),
        $instance->instance_id,
        $instance->public_ip,
        $provider->{provider_client}->region);
}

sub upload_ltp_logs
{
    my $self = shift;
    my $ltp_testsuite = $self->{ltp_command};
    my $log_file = Mojo::File::path('ulogs/results.json');

    record_info('LTP Logs', 'upload');
    upload_logs("/tmp/kirk.\$USER/latest/results.json", log_name => $log_file->basename, failok => 1);
    upload_logs("/tmp/kirk.\$USER/latest/debug.log", log_name => 'debug.txt', failok => 1);

    return unless -e $log_file->to_string;

    local @INC = ($ENV{OPENQA_LIBPATH} // testapi::OPENQA_LIBPATH, @INC);
    eval {
        require OpenQA::Parser::Format::LTP;

        my $ltp_log = Mojo::JSON::decode_json($log_file->slurp());
        my $parser = OpenQA::Parser::Format::LTP->new()->load($log_file->to_string);
        my %ltp_log_results = map { $_->{test_fqn} => $_->{test} } @{$ltp_log->{results}};
        my $whitelist = LTP::WhiteList->new();

        for my $result (@{$parser->results()}) {
            if ($whitelist->override_known_failures($self, {%{$self->{ltp_env}}, retval => $ltp_log_results{$result->{test_fqn}}->{retval}}, $ltp_testsuite, $result->{test_fqn})) {
                $result->{result} = 'softfail';
            }
        }

        $parser->write_output(bmwqemu::result_dir());
        $parser->write_test_result(bmwqemu::result_dir());

        $parser->tests->each(sub {
                $autotest::current_test->register_extra_test_results([$_->to_openqa]);
        });
    };
    die $@ if $@;
}

sub run {
    my ($self, $args) = @_;
    my $qam = get_var('PUBLIC_CLOUD_QAM', 0);
    my $arch = check_var('PUBLIC_CLOUD_ARCH', 'arm64') ? 'aarch64' : 'x86_64';
    my $ltp_repo = get_var('LTP_REPO', 'https://download.opensuse.org/repositories/benchmark:/ltp:/stable/' . generate_version("_") . '/');
    my $ltp_command = get_required_var('LTP_COMMAND_FILE');
    $self->{ltp_command} = $ltp_command;
    my $ltp_exclude = get_var('LTP_COMMAND_EXCLUDE', '');

    select_host_console();

    unless ($args->{my_provider} && $args->{my_instance}) {
        $args->{my_provider} = $self->provider_factory();
        $args->{my_instance} = $args->{my_provider}->create_instance(check_guestregister => is_openstack ? 0 : 1);
    }
    my $instance = $args->{my_instance};
    my $provider = $args->{my_provider};

    assert_script_run("cd $root_dir");
    assert_script_run('curl ' . data_url('publiccloud/restart_instance.sh') . ' -o restart_instance.sh');
    assert_script_run('curl ' . data_url('publiccloud/log_instance.sh') . ' -o log_instance.sh');
    assert_script_run('chmod +x restart_instance.sh');
    assert_script_run('chmod +x log_instance.sh');

    registercloudguest($instance) if (is_byos() && !$qam);
    register_openstack($instance) if is_openstack;

    $instance->run_ssh_command(cmd => 'sudo zypper -n addrepo -fG ' . $ltp_repo . ' ltp_repo', timeout => 600);
    my $ltp_pkg = get_var('LTP_PKG', 'ltp-stable');
    if (is_transactional) {
        $instance->run_ssh_command(cmd => "sudo transactional-update -n pkg install $ltp_pkg", timeout => 900);
        $instance->softreboot();
    } else {
        $instance->run_ssh_command(cmd => "sudo zypper -n in $ltp_pkg", timeout => 600);
    }
    my $ltp_env = gen_ltp_env($instance, $ltp_pkg);
    $self->{ltp_env} = $ltp_env;


    # Use lib/LTP/WhiteList module to exclude tests
    my $issues = get_var('LTP_KNOWN_ISSUES', '');
    my $skip_tests;
    if ($issues) {
        my $whitelist = LTP::WhiteList->new($issues);
        my @skipped = $whitelist->list_skipped_tests($ltp_env, $ltp_command);
        if (@skipped) {
            $skip_tests = '^(' . join("|", @skipped) . ')$';
            $skip_tests .= '|' . $ltp_exclude if $ltp_exclude;
        }
        record_info("Exclude", "Excluding tests: $skip_tests");
    } elsif ($ltp_exclude) {
        $skip_tests = $ltp_exclude;
        record_info("Exclude", "Excluding only 'LTP_COMMAND_EXCLUDE' tests: $skip_tests");
    } else {
        record_info("Exclude", "None");
    }

    my $kirk_repo = get_var("LTP_RUN_NG_REPO", "https://github.com/linux-test-project/kirk.git");
    my $kirk_branch = get_var("LTP_RUN_NG_BRANCH", "master");
    record_info('LTP RUNNER REPO', "Repo: " . $kirk_repo . "\nBranch: " . $kirk_branch);
    assert_script_run("git clone -q --single-branch -b $kirk_branch --depth 1 $kirk_repo");
    $instance->run_ssh_command(cmd => 'sudo CREATE_ENTRIES=1 ' . get_ltproot() . '/IDcheck.sh', timeout => 300);
    record_info('Kernel info', $instance->run_ssh_command(cmd => q(rpm -qa 'kernel*' --qf '%{NAME}\n' | sort | uniq | xargs rpm -qi)));
    record_info('VM Detect', $instance->run_ssh_command(cmd => 'systemd-detect-virt'));
    # this will print /all/ kernel messages to the console. So in case kernel panic we will have some data to analyse
    $instance->ssh_assert_script_run(cmd => "echo 1 | sudo tee /sys/module/printk/parameters/ignore_loglevel");

    my $reset_cmd = $root_dir . '/restart_instance.sh ' . instance_log_args($provider, $instance);
    my $log_start_cmd = $root_dir . '/log_instance.sh start ' . instance_log_args($provider, $instance);

    my $env = get_var('LTP_PC_RUNLTP_ENV');

    assert_script_run($log_start_cmd);

    assert_script_run("cd kirk");
    my $ghash = script_output("git rev-parse HEAD", proceed_on_failure => 1);
    set_var("LTP_RUN_NG_GIT_HASH", $ghash);
    record_info("KIRK_GIT_HASH", "$ghash");
    assert_script_run("python3.11 -m venv env311");
    assert_script_run("source env311/bin/activate");
    assert_script_run("pip3.11 install asyncssh msgpack");

    my $sut = ':user=' . $instance->username;
    $sut .= ':sudo=1';
    $sut .= ':key_file=$(realpath ' . $instance->provider->ssh_key . ')';
    $sut .= ':host=' . $instance->public_ip;
    $sut .= ':reset_cmd=\'' . $reset_cmd . '\'';
    $sut .= ':hostkey_policy=missing';
    $sut .= ':known_hosts=/dev/null';

    my $cmd = 'python3.11 kirk ';
    $cmd .= "--framework ltp ";
    $cmd .= '--verbose ';
    $cmd .= '--exec-timeout=1200 ';
    $cmd .= '--suite-timeout=5400 ';
    $cmd .= '--run-suite ' . $ltp_command . ' ';
    $cmd .= '--skip-tests \'' . $skip_tests . '\' ' if $skip_tests;
    $cmd .= '--sut=ssh' . $sut . ' ';
    $cmd .= '--env ' . $env . ' ' if ($env);

    record_info('LTP START', 'Command launch');
    script_run($cmd, timeout => get_var('LTP_TIMEOUT', 30 * 60));
    record_info('LTP END', 'tests done');
}

sub cleanup {
    my ($self) = @_;

    # Ensure that the ltp script gets killed
    type_string('', terminate_with => 'ETX');
    $self->upload_ltp_logs();

    unless ($self->{run_args} && $self->{run_args}->{my_instance}) {
        die('cleanup: Either $self->{run_args} or $self->{run_args}->{my_instance} is not available. Maybe the test died before the instance has been created?');
    }

    if (script_run("test -f $root_dir/log_instance.sh") == 0) {
        script_run($root_dir . '/log_instance.sh stop ' . instance_log_args($self->{run_args}->{my_provider}, $self->{run_args}->{my_instance}));
        script_run("(cd /tmp/log_instance && tar -zcf $root_dir/instance_log.tar.gz *)");
        upload_logs("$root_dir/instance_log.tar.gz", failok => 1);
    }
    return 1;
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
        gcc => '',
        libc => '',
        harness => 'SUSE OpenQA',
    };

    record_info("LTP Environment", Dumper($environment));

    return $environment;
}

1;

=head1 Discussion

Test module to run LTP test on publiccloud. The test run on a local qemu instance
and connect to the CSP instance using SSH. This is done via the kirk.
