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
use LTP::utils qw(get_ltproot get_ltp_version_file);
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
    my $ltp_testsuite = get_required_var('LTP_COMMAND_FILE');
    my $log_file = Mojo::File::path('ulogs/result.json');
    record_info('LTP Logs', 'upload');
    upload_logs("$root_dir/result.json", log_name => $log_file->basename, failok => 1);
    # debug file in the standart LTP log-dir. structure:
    assert_script_run("test -f /tmp/runltp.\$USER/latest/debug.log || echo No debug log");
    upload_logs("/tmp/runltp.\$USER/latest/debug.log", failok => 1);

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
        $instance = $self->{my_instance} = $provider->create_instance();
        unless (is_openstack) {
            $instance->wait_for_guestregister();
        }
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

    my $runltp_ng_repo = get_var("LTP_RUN_NG_REPO", "https://github.com/acerv/runltp-ng.git");
    my $runltp_ng_branch = get_var("LTP_RUN_NG_BRANCH", "master");
    record_info('LTP CLONE REPO', "Repo: " . $runltp_ng_repo . "\nBranch: " . $runltp_ng_branch);

    assert_script_run("git clone -q --single-branch -b $runltp_ng_branch --depth 1 $runltp_ng_repo");
    $instance->run_ssh_command(cmd => 'sudo CREATE_ENTRIES=1 ' . get_ltproot() . '/IDcheck.sh', timeout => 300);
    record_info('Kernel info', $instance->run_ssh_command(cmd => q(rpm -qa 'kernel*' --qf '%{NAME}\n' | sort | uniq | xargs rpm -qi)));

    my $reset_cmd = $root_dir . '/restart_instance.sh ' . $self->instance_log_args();
    my $log_start_cmd = $root_dir . '/log_instance.sh start ' . $self->instance_log_args();

    assert_script_run($log_start_cmd);

    # LTP command line preparation
    zypper_call("in -y python3-paramiko python3-scp");
    my $sut = ':user=' . $instance->username;
    $sut .= ':sudo=1';
    $sut .= ':key_file=' . $instance->ssh_key;
    $sut .= ':host=' . $instance->public_ip;
    $sut .= ':reset_command=\'' . $reset_cmd . '\'';
    $sut .= ':hostkey_policy=missing';
    $sut .= ':known_hosts=/dev/null';

    my $cmd = 'python3 runltp-ng/runltp-ng ';
    $cmd .= "--json-report=$root_dir/result.json ";
    $cmd .= '--verbose ';
    $cmd .= '--exec-timeout=1200 ';
    $cmd .= '--run-suite ' . get_required_var('LTP_COMMAND_FILE') . ' ';
    $cmd .= '--skip-tests \'' . get_var('LTP_COMMAND_EXCLUDE') . '\' ' if get_var('LTP_COMMAND_EXCLUDE');
    $cmd .= '--sut=ssh' . $sut . ' ';
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

=head1 Configuration

=head2 LTP_COMMAND_FILE

The LTP test command file (e.g. syscalls, cve)

=head2 LTP_COMMAND_EXCLUDE

This regex is used to exclude tests from command file.

=head2 LTP_REPO

The repo which will be added and is used to install LTP package.

=head2 LTP_KNOWN_ISSUES

Used to specify a url for a json file with well known LTP issues. If an error occur
which is listed, then the result is overwritten with softfailure.

=head2 PUBLIC_CLOUD_LTP

If set, this test module is added to the job.

=head2 PUBLIC_CLOUD_PROVIDER

The type of the CSP (e.g. AZURE, EC2)

=head2 PUBLIC_CLOUD_IMAGE_LOCATION

The URL where the image gets downloaded from. The name of the image gets extracted
from this URL.

=head2 PUBLIC_CLOUD_REGION

The region to use. (default-azure: westeurope, default-ec2: eu-central-1)
