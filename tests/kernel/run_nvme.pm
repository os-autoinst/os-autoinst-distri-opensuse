# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run the upstream nvme-cli Python test suite
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'write_sut_file';
use LTP::WhiteList;
use LTP::utils 'prepare_whitelist_environment';
use package_utils 'install_package';
use Utils::Logging qw(export_logs_basic save_and_upload_log);
use Kernel::block_dev qw(record_storage_info);

my $repo_dir = 'nvme-cli';

# TODO: extend the nvem-cli tests to use env, so config could be replaced
sub prepare_nvmecli_config {
    my ($ctrl, $ns1) = @_;

    my $config = <<"END_CONFIG";
{
    "controller": "$ctrl",
    "ns1": "$ns1",
    "log_dir": "nvmetests",
    "log_level": "DEBUG"
}
END_CONFIG
    write_sut_file('tests/config.json', $config);
    record_info('config.json', script_output('cat tests/config.json'));
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # below variables expose the nvme-cli Python test suite to the openQA
    # testsuite definition, so that it allows flexible ways of re-running tests
    my $tests = get_required_var('NVMECLI_TESTS');
    my $ctrl = get_required_var('NVMECLI_CTRL');
    my $ns1 = get_required_var('NVMECLI_NS1');
    my $repo = get_var('NVMECLI_REPO', 'https://github.com/linux-nvme/nvme-cli.git');
    my $version = get_var('NVMECLI_VERSION');
    my $issues = get_var('NVMECLI_KNOWN_ISSUES');

    record_info('KERNEL', script_output('rpm -qi kernel-default'));
    save_and_upload_log('(rpm -qi kernel-default; uname -a)', 'kernel_bug_report.txt');

    install_package('nvme-cli git-core python3', trup_apply => 1);

    assert_script_run("test -c $ctrl", fail_message => "NVMe controller device $ctrl not found");
    assert_script_run("test -b $ns1", fail_message => "NVMe namespace device $ns1 not found");
    record_storage_info();

    my $branch = $version ? "--branch $version" : '';
    assert_script_run("git clone --depth=1 $branch $repo $repo_dir");
    assert_script_run("cd $repo_dir");

    prepare_nvmecli_config($ctrl, $ns1);

    my @tests = split(',', $tests);

    if ($issues) {
        my $whitelist = LTP::WhiteList->new($issues);
        my $environment = prepare_whitelist_environment();
        $environment->{kernel} = script_output('uname -r');

        my %exclude;
        for my $test ($whitelist->list_skipped_tests($environment, 'nvme-cli')) {
            my $entry = $whitelist->find_whitelist_entry($environment, 'nvme-cli', $test);
            my $message = $entry->{message} // '';
            record_info('Known issue', "Skipping $test" . ($message ? ": $message" : ''));
            $exclude{$test} = 1;
        }
        @tests = grep { !$exclude{$_} } @tests;
    }

    my $failed = 0;
    foreach my $test (@tests) {
        record_info('TEST', $test);
        my $tap_file = "/tmp/${test}.tap";
        my $stderr_file = "${tap_file}.stderr";
        assert_script_run("echo '$test.tap ..' > $tap_file");
        script_run("python3 tests/tap_runner.py --start-dir tests $test >> $tap_file 2>> $stderr_file", 300);
        parse_extra_log(TAP => $tap_file);
        upload_logs($stderr_file);

        if (script_run("grep -q '^not ok' $tap_file") == 0) {
            record_info('RESULT', "$test failed", result => 'fail');
            $failed = 1;
        }
    }

    $self->result('fail') if $failed;
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    export_logs_basic;
}

1;

=head1 Description

Run the upstream Python test suite from the C<nvme-cli> project's C<tests/>
directory (see L<https://github.com/linux-nvme/nvme-cli/tree/master/tests>).

The suite is not shipped as part of the C<nvme-cli> package, so this module
clones the upstream repository to obtain it and uses the already installed
C<nvme> binary to exercise the device under test.

B<Warning:> these tests expect to run against a real NVMe device and will
read, write, and re-provision namespaces on it. Only point C<NVMECLI_CTRL>
and C<NVMECLI_NS1> at disposable hardware.

=head1 Configuration

=head2 NVMECLI_TESTS

Required. Comma-separated list of test modules passed one at a time to
C<tap_runner.py>, for example:

  NVMECLI_TESTS=nvme_id_ctrl_test
  NVMECLI_TESTS=nvme_id_ctrl_test,nvme_id_ns_test,nvme_smart_log_test

=head2 NVMECLI_CTRL

Required. NVMe controller character device, written into F<tests/config.json>
as C<controller>. Example: C</dev/nvme0>.

=head2 NVMECLI_NS1

Required. NVMe namespace block device, written into F<tests/config.json> as
C<ns1>. Example: C</dev/nvme0n1>.

=head2 NVMECLI_REPO

Optional. Git repository to clone for the test suite. Defaults to the
upstream C<linux-nvme/nvme-cli> repository on GitHub.

=head2 NVMECLI_VERSION

Optional. Git branch or tag to check out. If unset, the repository's default
branch is used.

=head2 NVMECLI_KNOWN_ISSUES

Optional. URL or local path to a known-issues YAML file parsed with
C<LTP::WhiteList>. Entries under the C<nvme-cli> suite with C<skip: 1> are
removed from the C<NVMECLI_TESTS> list when they match the current openQA
environment, since C<tap_runner.py> runs a whole test module at a time and
individual test methods within it cannot be excluded.

=cut
