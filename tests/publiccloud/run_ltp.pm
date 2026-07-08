# SUSE's openQA tests
#
# Copyright 2018-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: perl-base ltp
# Summary: Use perl script to run LTP on public cloud
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils;
use repo_tools 'generate_version';
use Mojo::File;
use Mojo::JSON;
use Mojo::UserAgent;
use LTP::utils qw(get_ltproot prepare_whitelist_environment);
use LTP::install qw(get_required_build_dependencies get_maybe_build_dependencies);
use LTP::WhiteList;
use publiccloud::utils;
use publiccloud::zypper qw(pc_pkg_call pc_zypper_call pc_add_repo pc_available_packages);
use publiccloud::ssh_interactive 'select_host_console';
use JSON qw(decode_json);
use Data::Dumper;
use version_utils;
use Utils::Architectures qw(is_aarch64);

my $kirk_virtualenv = 'kirk-virtualenv';
our $root_dir = '/root';
our $ltp_timeout = get_var('LTP_TIMEOUT', 12600);

sub should_fully_build_ltp_from_git {
    return get_var('PUBLIC_CLOUD_LTP_GIT_FULL_BUILD', 0);    # 1 if env var is set, otherwise 0
}

sub should_partially_build_ltp_from_git_modules_install {
    return get_var('PUBLIC_CLOUD_LTP_BUILD_MODULES', 0);    # 1 if env var is set, otherwise 0
}

sub install_build_deps {
    my ($instance) = @_;

    my @deps = get_required_build_dependencies();

    # Remove kernel-default-devel from the list of dependencies since matching kernel version kernel-<flavor>-devel-<ver> package will be added.
    @deps = grep { $_ ne 'kernel-default-devel' } @deps;

    # Query rpm's NAME/VERSION/RELEASE tags directly for the package owning
    # the running kernel's config file, instead of parsing free-form `rpm -qf`
    # output. The previous sed/cut/awk chain assumed the package name always
    # splits cleanly into kernel-<flavor>-<version>, which is not guaranteed
    # and produced an invalid 'kernel--devel-<version>' package on some SUTs.
    my $kernel_pkg_name = $instance->ssh_script_output(cmd => q{rpm -qf --qf '%{NAME}' /boot/config-$(uname -r)});
    my $kernel_pkg_ver = $instance->ssh_script_output(cmd => q{rpm -qf --qf '%{VERSION}-%{RELEASE}' /boot/config-$(uname -r)});
    # Sample value: kernel-default-devel-6.12.0-160000.27.1
    my $kernel_devel_pkg = "${kernel_pkg_name}-devel-${kernel_pkg_ver}";

    push @deps, $kernel_devel_pkg;

    pc_pkg_call(
        $instance,
        'install --no-recommends ' . join(' ', @deps),
        timeout => 300,
    );
    install_optional_build_deps($instance);
}

sub prepare_ltp_git {
    my ($instance, $ltp_dir, $ltp_prefix) = @_;

    my $repo_url = get_var('LTP_GIT_URL', 'https://github.com/linux-test-project/ltp');
    my $repo_branch = get_var('LTP_RELEASE', 'master');

    my $configure = "./configure --prefix=$ltp_prefix";
    my $extra_flags = get_var('LTP_EXTRA_CONF_FLAGS', '');

    my $ltp_build_timeout = 5 * 60;

    $instance->ssh_assert_script_run("rm -rf $ltp_dir");
    $instance->ssh_assert_script_run("git clone --depth 1 -b $repo_branch $repo_url $ltp_dir");
    $instance->ssh_assert_script_run(
        cmd => "cd $ltp_dir && make autotools && $configure $extra_flags",
        timeout => $ltp_build_timeout
    );
}

sub fully_build_ltp_from_git {
    my ($instance, $ltp_dir, $ltp_prefix) = @_;

    my $start = time();
    my $ltp_build_timeout = 20 * 60;

    install_build_deps($instance);
    prepare_ltp_git($instance, $ltp_dir, $ltp_prefix);
    $instance->ssh_assert_script_run(
        cmd => "cd $ltp_dir && make -j\$(getconf _NPROCESSORS_ONLN) && sudo make install",
        timeout => $ltp_build_timeout
    );

    record_info("LTP Full Build Time", "Time taken to build from source: " . (time() - $start) . " seconds");
}

sub partially_build_ltp_from_git {
    my ($instance, $ltp_dir, $ltp_prefix) = @_;

    my $start = time();
    my $ltp_subdir_build_timeout = 5 * 60;

    install_build_deps($instance);
    prepare_ltp_git($instance, $ltp_dir, $ltp_prefix);

    $instance->ssh_assert_script_run(
        cmd => "cd $ltp_dir && make -j\$(getconf _NPROCESSORS_ONLN) modules && sudo make -j\$(getconf _NPROCESSORS_ONLN) modules-install",
        timeout => $ltp_subdir_build_timeout
    );
    record_info("LTP Partial Build Time", "Time taken build from source: " . (time() - $start) . " seconds");
}

sub instance_log_args
{
    my ($provider, $instance) = @_;
    my $region = $provider->{provider_client}->region;
    $region .= "-" . $provider->{provider_client}->availability_zone if is_gce();

    return sprintf('"%s" "%s" "%s" "%s"',
        get_required_var('PUBLIC_CLOUD_PROVIDER'),
        $instance->instance_id,
        $instance->public_ip,
        $region);
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

sub dump_kernel_config
{
    my ($instance) = @_;

    record_info("uname -a", $instance->ssh_script_output(cmd => "uname -a"));

    my $uname_r = $instance->ssh_script_output(cmd => "uname -r");
    chomp $uname_r;

    record_info("KERNEL CONFIG", $instance->ssh_script_output(cmd => "cat /boot/config-$uname_r"));
    record_info("ver_linux", $instance->ssh_script_output("/opt/ltp/ver_linux"));
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

    my $instance = $args->{my_instance};
    my $provider = $args->{my_provider};

    prepare_scripts();

    my $ltp_dir = '/tmp/ltp';
    my $ltp_prefix = '/opt/ltp';

    if (should_fully_build_ltp_from_git()) {
        fully_build_ltp_from_git($instance, $ltp_dir, $ltp_prefix);
    } else {
        install_ltp($instance, $ltp_repo_name, $ltp_repo_url, $ltp_pkg);
        partially_build_ltp_from_git($instance, $ltp_dir, $ltp_prefix) if should_partially_build_ltp_from_git_modules_install();
    }

    $self->gen_ltp_env($instance, $ltp_pkg);

    my $include_tests_pattern = get_var('LTP_COMMAND_PATTERN');
    my $skip_tests = $self->prepare_skip_tests(\@commands);

    prepare_kirk($instance);

    printk_loglevel($instance);

    my $reset_cmd = $root_dir . '/restart_instance.sh ' . instance_log_args($provider, $instance);

    my $env = get_var('LTP_PC_RUNLTP_ENV');
    my $log_start_cmd = $root_dir . '/log_instance.sh start ' . instance_log_args($provider, $instance);
    prepare_logging($log_start_cmd);

    my $cmd_run_ltp = prepare_ltp_cmd($instance, $provider, $reset_cmd, $ltp_command, $include_tests_pattern, $skip_tests, $env);

    dump_kernel_config($instance);
    record_info('LTP START', 'Command launch');
    # $ltp_timeout is also used for --suite-timeout so we need give kirk some time to try to kill itself before trying to kill it
    my $kirk_exit_code = script_run($cmd_run_ltp, timeout => $ltp_timeout + 60);
    record_info('LTP END', 'krik finished with ' . $kirk_exit_code);
    die('kirk failed') if ($kirk_exit_code);
}


sub prepare_scripts {
    assert_script_run("cd $root_dir");
    assert_script_run('curl ' . data_url('publiccloud/restart_instance.sh') . ' -o restart_instance.sh');
    assert_script_run('curl ' . data_url('publiccloud/log_instance.sh') . ' -o log_instance.sh');
    assert_script_run('chmod +x restart_instance.sh');
    assert_script_run('chmod +x log_instance.sh');
}

sub install_ltp {
    my ($instance, $ltp_repo_name, $ltp_repo_url, $ltp_package_name) = @_;

    pc_add_repo($instance, $ltp_repo_name, $ltp_repo_url);
    pc_pkg_call(
        $instance,
        "install --no-recommends $ltp_package_name",
        timeout => 300,
    );
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
    my ($instance) = @_;
    my $kirk_repo = get_var("LTP_RUN_NG_REPO", "https://github.com/linux-test-project/kirk.git");
    my $kirk_branch = get_var("LTP_RUN_NG_BRANCH", "master");
    record_info('LTP RUNNER REPO', "Repo: " . $kirk_repo . "\nBranch: " . $kirk_branch);
    script_retry("git clone -q --single-branch -b $kirk_branch --depth 1 $kirk_repo", retry => 5, delay => 60, timeout => 300);
    $instance->ssh_assert_script_run(cmd => 'sudo CREATE_ENTRIES=1 ' . get_ltproot() . '/IDcheck.sh', timeout => 300);
    record_info('Kernel info', $instance->ssh_script_output(cmd => q(rpm -qa 'kernel*' --qf '%{NAME}\n' | sort | uniq | xargs rpm -qi)));
    assert_script_run("cd kirk");
    my $ghash = script_output("git rev-parse HEAD", proceed_on_failure => 1);
    set_var("LTP_RUN_NG_GIT_HASH", $ghash);
    record_info("KIRK_GIT_HASH", "$ghash");
    my $venv = install_in_venv($kirk_virtualenv, pip_packages => "asyncssh msgpack");
    venv_activate($venv);
}

sub printk_loglevel {
    my ($instance) = @_;
    # this will print /all/ kernel messages to the console. So in case kernel panic we will have some data to analyse
    $instance->ssh_assert_script_run(cmd => "echo 1 | sudo tee /sys/module/printk/parameters/ignore_loglevel");
}

sub prepare_logging {
    my ($log_start_cmd) = @_;
    assert_script_run($log_start_cmd);
}

sub prepare_ltp_cmd {
    my ($instance, $provider, $reset_cmd, $ltp_command, $include_tests_pattern, $skip_tests, $env) = @_;
    my $exec_timeout = get_var('LTP_EXEC_TIMEOUT', 1200);

    my $sut = ':user=' . $instance->username;
    $sut .= ':sudo=1';
    $sut .= ':key_file=$(realpath ' . $instance->provider->ssh_key . ')';
    $sut .= ':host=' . $instance->public_ip;
    $sut .= ':reset_cmd=\'' . $reset_cmd . '\'';

    my $env_prefix = '';
    if (defined $env && $env ne '') {
        my @vars = split /:/, $env;
        $env_prefix = join(' ', @vars) . ' ';
    }

    my $python_exec = get_python_exec();
    my $cmd = "$env_prefix$python_exec kirk";
    $cmd .= " --verbose";
    $cmd .= " --exec-timeout=$exec_timeout";
    $cmd .= " --suite-timeout=$ltp_timeout";
    $cmd .= " --run-suite $ltp_command";
    $cmd .= " --run-pattern '$include_tests_pattern'" if $include_tests_pattern;
    $cmd .= " --skip-tests '$skip_tests'" if $skip_tests;
    $cmd .= " --sut default:com=ssh";
    $cmd .= " --com=ssh$sut";
    $cmd .= " ";
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
        my $log_instance_stop_command = $root_dir . '/log_instance.sh stop ' . instance_log_args($self->{run_args}->{my_provider}, $self->{run_args}->{my_instance});
        script_run($log_instance_stop_command, timeout => 600);

        script_run("(cd /tmp/log_instance && tar -zcf $root_dir/instance_log.tar.gz *)");
        upload_logs("$root_dir/instance_log.tar.gz", failok => 1);
    }

    return 1;
}

sub gen_ltp_env {
    my ($self, $instance, $ltp_pkg) = @_;
    my $ltp_version = get_var('LTP_RELEASE', 'master');
    unless (should_fully_build_ltp_from_git()) {
        $ltp_version = $instance->ssh_script_output(cmd => qq(rpm -q --qf '%{VERSION}\n' $ltp_pkg));
    }
    $self->{ltp_env} = prepare_whitelist_environment();
    $self->{ltp_env}->{arch} = get_var('PUBLIC_CLOUD_ARCH', get_required_var("ARCH"));
    $self->{ltp_env}->{kernel} = $instance->ssh_script_output(cmd => 'uname -r');
    $self->{ltp_env}->{ltp_version} = $ltp_version;

    record_info("LTP Environment", Dumper($self->{ltp_env}));

    return $self->{ltp_env};
}

=head2 install_optional_build_deps

install_optional_build_deps($instance)

This function checks which packages from the get_maybe_build_dependencies list
are available for installation on the remote instance. If any packages are
available, it installs them via C<pc_pkg_call>.

=cut

sub install_optional_build_deps {
    my ($instance) = @_;
    my $available = pc_available_packages(
        $instance, [get_maybe_build_dependencies()]
    );
    return unless @$available;
    pc_pkg_call(
        $instance,
        'install --no-recommends ' . join(' ', @$available),
        timeout => 300,
    );
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Discussion

Test module to run LTP test on publiccloud. The test run on a local qemu instance
and connect to the CSP instance using SSH. This is done via the kirk.
