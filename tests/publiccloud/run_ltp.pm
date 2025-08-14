# SUSE's openQA tests
#
# Copyright 2018-2025 SUSE LLC
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
use LTP::install qw(get_required_build_dependencies get_maybe_build_dependencies get_submodules_to_rebuild);
use LTP::WhiteList;
use publiccloud::utils qw(is_byos is_gce registercloudguest register_openstack install_in_venv get_python_exec venv_activate zypper_install_remote zypper_install_available_remote zypper_add_repo_remote);
use publiccloud::ssh_interactive 'select_host_console';
use Data::Dumper;
use version_utils;

my $kirk_virtualenv = 'kirk-virtualenv';
our $root_dir = '/root';

sub should_fully_build_ltp {
    return get_var('PUBLIC_CLOUD_LTP_GIT_FULL_BUILD', 0);    # 1 if env var is set, otherwise 0
}

sub should_partially_build_ltp {
    return get_var('PUBLIC_CLOUD_LTP_GIT_BUILD', 0);    # 1 if env var is set, otherwise 0
}

sub install_build_deps {
    my ($self, $instance) = @_;

    zypper_install_remote($instance, [get_required_build_dependencies()]);
    zypper_install_available_remote($instance, [get_maybe_build_dependencies()]);
}

sub prepare_ltp_git {
    my ($self, $instance, $ltp_dir, $ltp_prefix) = @_;

    my $repo_url = get_var('LTP_GIT_URL', 'https://github.com/linux-test-project/ltp');
    my $repo_branch = get_var('LTP_RELEASE', 'master');

    my $configure = "./configure --prefix=$ltp_prefix";
    my $extra_flags = get_var('LTP_EXTRA_CONF_FLAGS', '');

    my $ltp_build_timeout = 5 * 60;

    $self->install_build_deps($instance);

    $instance->run_ssh_command("rm -rf $ltp_dir");
    $instance->run_ssh_command("git clone --depth 1 -b $repo_branch $repo_url $ltp_dir");
    $instance->run_ssh_command(
        cmd => "cd $ltp_dir && make autotools && $configure $extra_flags",
        timeout => $ltp_build_timeout
    );
}

sub fully_build_ltp_from_git {
    my ($self, $instance, $ltp_dir, $ltp_prefix) = @_;

    my $start = time();
    my $ltp_build_timeout = 20 * 60;

    $self->prepare_ltp_git($instance, $ltp_dir, $ltp_prefix);
    $instance->run_ssh_command(
        cmd => "cd $ltp_dir && make -j\$(getconf _NPROCESSORS_ONLN) && sudo make install",
        timeout => $ltp_build_timeout
    );

    record_info("LTP Full Build Time", "Time taken to build from source: " . (time() - $start) . " seconds");
}

sub partially_build_ltp_from_git {
    my ($self, $instance, $ltp_dir, $ltp_prefix) = @_;

    my $start = time();
    my $ltp_subdir_build_timeout = 5 * 60;

    $self->prepare_ltp_git($instance, $ltp_dir, $ltp_prefix);

    foreach my $subdir (get_submodules_to_rebuild()) {
        $instance->run_ssh_command(
            cmd => "cd $ltp_dir/testcases/$subdir && make -j\$(getconf _NPROCESSORS_ONLN) && sudo make install",
            timeout => $ltp_subdir_build_timeout
        );
    }
    record_info("LTP Partial Build Time", "Time taken build from source: " . (time() - $start) . " seconds");
}

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
    my @commands = split(/\s+/, $ltp_testsuite);
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
            foreach my $command (@commands) {
                if ($whitelist->override_known_failures(
                        $self,
                        {%{$self->{ltp_env}}, retval => $ltp_log_results{$result->{test_fqn}}->{retval}},
                        $command,
                        $result->{test_fqn}
                )) {
                    $result->{result} = 'softfail';
                    last;
                }
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
    my $ltp_pkg = get_var('LTP_PKG', 'ltp-stable');
    my $ltp_repo_name = "ltp_repo";
    my $ltp_repo_url = get_var('LTP_REPO', 'https://download.opensuse.org/repositories/benchmark:/ltp:/stable/' . generate_version("_") . '/');
    my $ltp_command = get_var('LTP_COMMAND_FILE', 'publiccloud');
    $self->{ltp_command} = $ltp_command;
    my @commands = split(/\s+/, $ltp_command);

    select_host_console();

    ($args->{my_provider}, $args->{my_instance}) = $self->prepare_instance($args);

    my $instance = $args->{my_instance};
    my $provider = $args->{my_provider};

    $self->prepare_scripts();
    $self->register_instance($instance, $qam);

    my $ltp_dir = '/tmp/ltp';
    my $ltp_prefix = '/opt/ltp';
    if (should_fully_build_ltp()) {
        $self->fully_build_ltp_from_git($instance, $ltp_dir, $ltp_prefix);
    } else {
        $self->install_ltp($instance, $ltp_repo_name, $ltp_repo_url, $ltp_pkg);
        $self->partially_build_ltp_from_git($instance, $ltp_dir, $ltp_prefix) if should_partially_build_ltp();
    }

    $self->gen_ltp_env($instance, $ltp_pkg);

    my $skip_tests = $self->prepare_skip_tests(\@commands);

    $self->prepare_kirk($instance);

    $self->upload_runtest($instance, $provider);

    $self->printk_loglevel($instance);

    my $reset_cmd = $root_dir . '/restart_instance.sh ' . instance_log_args($provider, $instance);
    my $log_start_cmd = $root_dir . '/log_instance.sh start ' . instance_log_args($provider, $instance);

    my $env = get_var('LTP_PC_RUNLTP_ENV');
    $self->prepare_logging($log_start_cmd);

    my $cmd_run_ltp = $self->prepare_ltp_cmd($instance, $provider, $reset_cmd, $ltp_command, $skip_tests, $env);

    record_info('LTP START', 'Command launch');
    script_run($cmd_run_ltp, timeout => get_var('LTP_TIMEOUT', 30 * 60));
    record_info('LTP END', 'tests done');
}

sub prepare_instance {
    my ($self, $args) = @_;
    unless ($args->{my_provider} && $args->{my_instance}) {
        $args->{my_provider} = $self->provider_factory();
        $args->{my_instance} = $args->{my_provider}->create_instance(check_guestregister => is_openstack ? 0 : 1);
    }
    return ($args->{my_provider}, $args->{my_instance});
}

sub prepare_scripts {
    assert_script_run("cd $root_dir");
    assert_script_run('curl ' . data_url('publiccloud/restart_instance.sh') . ' -o restart_instance.sh');
    assert_script_run('curl ' . data_url('publiccloud/log_instance.sh') . ' -o log_instance.sh');
    assert_script_run('chmod +x restart_instance.sh');
    assert_script_run('chmod +x log_instance.sh');
}

sub register_instance {
    my ($self, $instance, $qam) = @_;
    registercloudguest($instance) if (is_byos() && !$qam);
    register_openstack($instance) if is_openstack;
}

sub install_ltp {
    my ($self, $instance, $ltp_repo_name, $ltp_repo_url, $ltp_package_name) = @_;

    zypper_add_repo_remote($instance, $ltp_repo_name, $ltp_repo_url);
    zypper_install_remote($instance, $ltp_package_name);
}

sub prepare_skip_tests {
    my ($self, $commands) = @_;
    my $ltp_exclude = get_var('LTP_COMMAND_EXCLUDE', '');
    # Use lib/LTP/WhiteList module to exclude tests
    my $issues = get_var('LTP_KNOWN_ISSUES', '');
    my $skip_tests;
    if ($issues) {
        my $whitelist = LTP::WhiteList->new($issues);
        my @skipped;
        foreach my $command (@$commands) {
            my @skipped_for_command = $whitelist->list_skipped_tests($self->{ltp_env}, $command);
            push @skipped, @skipped_for_command;
        }
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
    return $skip_tests;
}

sub prepare_kirk {
    my ($self, $instance) = @_;
    my $kirk_repo = get_var("LTP_RUN_NG_REPO", "https://github.com/linux-test-project/kirk.git");
    my $kirk_branch = get_var("LTP_RUN_NG_BRANCH", "master");
    record_info('LTP RUNNER REPO', "Repo: " . $kirk_repo . "\nBranch: " . $kirk_branch);
    script_retry("git clone -q --single-branch -b $kirk_branch --depth 1 $kirk_repo", retry => 5, delay => 60, timeout => 300);
    $instance->run_ssh_command(cmd => 'sudo CREATE_ENTRIES=1 ' . get_ltproot() . '/IDcheck.sh', timeout => 300);
    record_info('Kernel info', $instance->run_ssh_command(cmd => q(rpm -qa 'kernel*' --qf '%{NAME}\n' | sort | uniq | xargs rpm -qi)));
    if (get_var('PUBLIC_CLOUD_INSTANCE_TYPE') =~ /-metal$/) {
        record_info('VM type', $instance->run_ssh_command(cmd => '! systemd-detect-virt')) unless is_gce;
    } else {
        record_info('VM type', $instance->run_ssh_command(cmd => 'systemd-detect-virt'));
    }
    assert_script_run("cd kirk");
    my $ghash = script_output("git rev-parse HEAD", proceed_on_failure => 1);
    set_var("LTP_RUN_NG_GIT_HASH", $ghash);
    record_info("KIRK_GIT_HASH", "$ghash");
    my $venv = install_in_venv($kirk_virtualenv, pip_packages => "asyncssh msgpack");
    venv_activate($venv);
}

sub upload_runtest {
    my ($self, $instance, $provider) = @_;
    assert_script_run('curl ' . data_url('publiccloud/ltp_runtest') . ' -o publiccloud');
    $instance->scp("publiccloud", 'remote:/tmp/publiccloud', 9999);
    $instance->ssh_assert_script_run(cmd => "sudo mv /tmp/publiccloud /opt/ltp/runtest/publiccloud");
}

sub printk_loglevel {
    my ($self, $instance) = @_;
    # this will print /all/ kernel messages to the console. So in case kernel panic we will have some data to analyse
    $instance->ssh_assert_script_run(cmd => "echo 1 | sudo tee /sys/module/printk/parameters/ignore_loglevel");
}

sub prepare_logging {
    my ($self, $log_start_cmd) = @_;
    assert_script_run($log_start_cmd);
}

sub prepare_ltp_cmd {
    my ($self, $instance, $provider, $reset_cmd, $ltp_command, $skip_tests, $env) = @_;

    my $sut = ':user=' . $instance->username;
    $sut .= ':sudo=1';
    $sut .= ':key_file=$(realpath ' . $instance->provider->ssh_key . ')';
    $sut .= ':host=' . $instance->public_ip;
    $sut .= ':reset_cmd=\'' . $reset_cmd . '\'';

    my $python_exec = get_python_exec();
    my $cmd = "$python_exec kirk ";
    $cmd .= "--framework ltp ";
    $cmd .= '--verbose ';
    $cmd .= '--exec-timeout=1200 ';
    $cmd .= '--suite-timeout=5400 ';
    $cmd .= '--run-suite ' . $ltp_command . ' ';
    $cmd .= '--skip-tests \'' . $skip_tests . '\' ' if $skip_tests;
    $cmd .= '--sut=ssh' . $sut . ' ';
    $cmd .= '--env ' . $env . ' ' if ($env);
    return $cmd;
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
    my ($self, $instance, $ltp_pkg) = @_;
    my $ltp_version = get_var('LTP_RELEASE', 'master');
    unless (should_partially_build_ltp() || should_fully_build_ltp()) {
        $ltp_version = $instance->run_ssh_command(cmd => qq(rpm -q --qf '%{VERSION}\n' $ltp_pkg));
    }
    $self->{ltp_env} = {
        product => get_required_var('DISTRI') . ':' . get_required_var('VERSION'),
        revision => get_required_var('BUILD'),
        arch => get_var('PUBLIC_CLOUD_ARCH', get_required_var("ARCH")),
        kernel => $instance->run_ssh_command(cmd => 'uname -r'),
        backend => get_required_var('BACKEND'),
        flavor => get_required_var('FLAVOR'),
        ltp_version => $ltp_version,
        gcc => '',
        libc => '',
        harness => 'SUSE OpenQA',
    };

    record_info("LTP Environment", Dumper($self->{ltp_env}));

    return $self->{ltp_env};
}

1;

=head1 Discussion

Test module to run LTP test on publiccloud. The test run on a local qemu instance
and connect to the CSP instance using SSH. This is done via the kirk.
