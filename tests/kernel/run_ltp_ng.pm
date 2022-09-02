# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Executes a single LTP test case
# Maintainer: Andrea Cervesato <andrea.cervesato@suse.com>
# More documentation is at the bottom

use base 'opensusebasetest';
use testapi;
use Mojo::File;
use Mojo::JSON;
use LTP::WhiteList;
require bmwqemu;

sub pre_run_hook
{
    my ($self) = @_;
    my @pattern_list;

    # Kernel error messages should be treated as soft-fail in boot_ltp,
    # install_ltp and shutdown_ltp so that at least some testing can be done.
    # But change them to hard fail in this test module.
    for my $pattern (@{$self->{serial_failures}}) {
        my %tmp = %$pattern;
        $tmp{type} = 'hard' if $tmp{message} =~ m/kernel/i;
        push @pattern_list, \%tmp;
    }

    $self->{serial_failures} = \@pattern_list;
    $self->SUPER::pre_run_hook;
}

sub upload_ltp_logs
{
    my ($self) = @_;
    my $log_file = Mojo::File::path('results.json');
    my $ltp_testsuite = get_required_var('LTP_COMMAND_FILE');

    upload_logs("$root_dir/results.json", log_name => $log_file->basename, failok => 1);

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

sub run
{
    my $ltp_repo = get_var('LTP_REPO', 'https://download.opensuse.org/repositories/benchmark:/ltp:/stable/' . generate_version("_") . '/');
    my $runltp_ng_repo = get_var("LTP_RUN_NG_REPO", "https://github.com/acerv/runltp-ng.git");
    my $runltp_ng_branch = get_var("LTP_RUN_NG_BRANCH", "master");
    my $ltp_pkg = get_var('LTP_PKG', 'ltp-stable');

    # add LTP repository and install LTP
    assert_script_run('sudo zypper -n addrepo -fG ' . $ltp_repo . ' ltp_repo', timeout => 600);
    assert_script_run("sudo zypper -n in $ltp_pkg", timeout => 600);

    # clone runltp-ng repository and run it
    assert_script_run("git clone -q --single-branch -b $runltp_ng_branch --depth 1 $runltp_ng_repo");

    my $cmd = 'python3 runltp-ng/runltp-ng ';
    $cmd .= '--verbose ';
    $cmd .= '--suite-timeout=1200 ';
    $cmd .= '--run-suite ' . get_required_var('LTP_COMMAND_FILE') . ' ';
    $cmd .= '--skip-tests ' . get_var('LTP_COMMAND_EXCLUDE') . ' ' if get_var('LTP_COMMAND_EXCLUDE');
    $cmd .= '--sut=host ';
    $cmd .= '--ltp-colors ';
    $cmd .= '--json-report=results.json ';

    assert_script_run($cmd, timeout => get_var('LTP_TIMEOUT', 30 * 60));
}

# Only propogate death don't create it from failure [2]
sub run_post_fail
{
    my ($self, $msg) = @_;

    $self->fail_if_running();

    if ($self->{ltp_tinfo} and $self->{result} eq 'fail') {
        my $whitelist = LTP::WhiteList->new();

        $whitelist->override_known_failures($self, $self->{ltp_env}, $self->{ltp_tinfo}->runfile, $self->{ltp_tinfo}->test->{name});
    }

    if ($msg =~ qr/died/) {
        die $msg . "\n";
    }
}

sub cleanup
{
    my ($self) = @_;

    $self->upload_ltp_logs();
}

1;
