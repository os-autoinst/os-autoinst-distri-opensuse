# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: blktests
# Summary: Block device layer tests
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use repo_tools 'add_qa_head_repo';
use LTP::WhiteList;
use LTP::utils 'prepare_whitelist_environment';
use package_utils 'install_package';
use Utils::Logging qw(export_logs_basic save_and_upload_log);
use Kernel::block_dev qw(is_block_device record_storage_info);

sub prepare_blktests_config {
    my ($devices, $test_case_dev_array) = @_;

    if ($devices eq 'none') {
        record_info('INFO', 'No specific tests device selected');
    } else {
        script_run("echo TEST_DEVS=\\($devices\\) > /etc/blktests/config");
        record_info('INFO', "$devices");
    }
    if ($test_case_dev_array) {
        script_run("echo '$test_case_dev_array' >> /etc/blktests/config");
    }
}

sub run {
    select_serial_terminal;

    #below variable exposes blktests options to the openQA testsuite
    #definition, so that it allows flexible ways of re-runing the tests
    my $tests = get_required_var('BLKTESTS');
    my $devices = get_required_var('BLKTESTS_TEST_DEVS');
    my $quick = get_var('BLKTESTS_QUICK');
    my $exclude = get_var('BLKTESTS_EXCLUDE');
    my $trtypes = get_var('BLKTESTS_TRTYPES');
    my $md_kver = get_var('BLKTESTS_MD_KVER');
    my $issues = get_var('BLKTESTS_KNOWN_ISSUES');
    my $test_case_dev_array = get_var('BLKTESTS_TEST_CASE_DEV_ARRAY');
    my $install = get_var('BLKTESTS_INSTALL', 'from_repo');

    record_info('KERNEL', script_output('(rpm -qi kernel-default; uname -a)'));
    save_and_upload_log('(rpm -qi kernel-default; uname -a)', 'kernel_bug_report.txt');

    #QA repo is added with lower prio in order to avoid possible problems
    #with some packages provided in both, tested product and qa repo; example: fio
    add_qa_head_repo(priority => 100);

    my $test_dir;
    if ($install eq 'from_git') {
        my $repository = get_var('BLKTESTS_REPO', 'https://github.com/linux-blktests/blktests.git');
        my $version = get_var('BLKTESTS_VERSION', '');
        install_package('git-core fio nvme-cli', trup_apply => 1);
        my $clone_cmd = "git clone --depth=1 $repository";
        $clone_cmd .= " --branch $version" if $version;
        assert_script_run($clone_cmd);
        $test_dir = 'blktests';
        record_info('test version', script_output('git -C blktests log -1 --oneline'));
    }
    else {
        install_package('blktests fio', trup_apply => 1);
        $test_dir = '/usr/lib/blktests';
    }

    #Prepare configuration, log/results directories
    assert_script_run("mkdir -p /etc/blktests");

    my $log_dir = '/var/log/blktests';
    assert_script_run("mkdir -p ${log_dir}/results");

    prepare_blktests_config($devices, $test_case_dev_array);

    record_storage_info();
    record_info('blktests cfg', script_output('cat /etc/blktests/config 2>/dev/null || true'));
    # BLKTESTS_TEST_DEVS may be set to 'none' to let blktests use its own defaults,
    # so skip the is_block_device check in such case
    is_block_device(split(/\s+/, $devices)) if $devices ne 'none';

    my @tests = split(',', $tests);
    assert_script_run("cd $test_dir");

    # BLKTESTS_EXCLUDE provides the initial list; known-issue entries are appended below
    my @exclude = split(/,/, $exclude // '');
    if ($issues) {
        my $whitelist = LTP::WhiteList->new($issues);
        my $environment = prepare_whitelist_environment();
        $environment->{test_variant} = $trtypes // '';
        $environment->{kernel} = script_output('uname -r');

        for my $test ($whitelist->list_skipped_tests($environment, 'blktests')) {
            my $entry = $whitelist->find_whitelist_entry($environment, 'blktests', $test);
            my $message = $entry->{message} // '';
            record_info('Known issue', "Skipping $test" . ($message ? ": $message" : ''));
            push @exclude, $test;
        }
    }

    $exclude = join(' ', map { "--exclude=$_" } @exclude);
    $trtypes = "NVMET_TRTYPES=\"$trtypes\" " if $trtypes;
    $md_kver = "BLKTESTS_MD_KVER=\"$md_kver\" " if $md_kver;

    foreach my $i (@tests) {
        my $config = $devices eq 'none' ? '' : '-c /etc/blktests/config';
        my $quick_arg = $quick ? "--quick=$quick" : '';
        script_run("${trtypes}${md_kver}./check $config -o ${log_dir}/results $quick_arg $exclude $i", 1200);
    }

    script_run("cd ${log_dir}");
    script_run('wget --quiet ' . data_url('kernel/post_process') . ' -O post_process');
    script_run('chmod +x post_process');
    script_run('./post_process');

    record_info('results', script_output('ls ./results'));
    script_run('tar -zcvf results.tar.gz results');
    upload_logs('results.tar.gz');

    record_info('XML', script_output('ls ./'));
    my $output = script_output("find ${log_dir} -name \"*_results.xml\" 2>/dev/null || true");
    foreach my $file (split /\n/, $output) {
        parse_extra_log('XUnit', $file);
    }
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

Run the upstream blktests suite either from the C<blktests> package (default)
or from a git checkout.

The test groups to execute are selected with C<BLKTESTS>. Individual tests can
be skipped either directly with C<BLKTESTS_EXCLUDE> (mostly for debugging purposes)
or through known-issues metadata referenced by C<BLKTESTS_KNOWN_ISSUES>.
Most native C<blktests> variables are exposed as C<BLKTESTS_NAME>, where C<NAME>
matches the upstream C<blktests> variable name, for example C<BLKTESTS_TRTYPES>
for C<TRTYPES>.

=head1 Configuration

=head2 BLKTESTS_INSTALL

Installation method. Defaults to C<from_repo> which installs the C<blktests>
package from QA:Head. Set to C<from_git> to clone the upstream C<blktests>
sources instead, for example to test a fix that is not yet packaged.

=head2 BLKTESTS_REPO

The blktests git repository URL. Used only with C<BLKTESTS_INSTALL=from_git>.
Defaults to C<https://github.com/linux-blktests/blktests.git>.

=head2 BLKTESTS_VERSION

Branch or tag to check out. Used only with C<BLKTESTS_INSTALL=from_git>.
Defaults to the default branch of the repository.

=head2 BLKTESTS

Required. Comma-separated list of blktests groups or individual tests passed to
C<./check>. Examples:

  BLKTESTS=block
  BLKTESTS=dm,throtl,scsi,loop
  BLKTESTS=nvme/001

=head2 BLKTESTS_TEST_DEVS

Required. Device list written to F</etc/blktests/config> as C<TEST_DEVS>.
Set to C<none> to skip writing a device list.

=head2 BLKTESTS_EXCLUDE

Optional. Comma-separated list of tests to exclude directly from this job. The
value is converted to C<./check --exclude=...> arguments.

This remains useful for temporary debugging overrides. Persistent product or
transport specific skips should be represented in C<BLKTESTS_KNOWN_ISSUES>
instead.

=head2 BLKTESTS_KNOWN_ISSUES

Optional. URL or local path to a known-issues YAML file parsed with
C<LTP::WhiteList>. Entries under the C<blktests> suite with C<skip: 1> are
added to the C<./check --exclude=...> arguments when they match the current
openQA environment.

Known-issues keys must use the full upstream blktests test ID format
C<group/number>. Matching C<skip: 1> entries are passed directly to
C<./check --exclude=...>.

Example:

  blktests:
      block/033:
      - product: sle:16\.1$
        skip: 1
        message: miniublk uses legacy ublk command opcodes
      nvme/041:
      - test_variant: ^fc$
        skip: 1
        message: skipped only for NVMe Fibre Channel transport

The common C<LTP::WhiteList> fields such as C<product>, C<revision>, C<flavor>,
C<arch>, C<backend>, C<machine>, C<kernel>, and C<test_variant> are supported.
For blktests, C<test_variant> matches C<BLKTESTS_TRTYPES>.

=head2 BLKTESTS_QUICK

Optional. Value passed to C<./check --quick>. If unset, C<--quick> is not
passed and all tests run regardless of their C<QUICK> flag.

=head2 BLKTESTS_TEST_CASE_DEV_ARRAY

Optional. A bash assignment appended verbatim to the blktests config file.
Required for tests using C<test_device_array()>, such as C<md/003>. Example:

  BLKTESTS_TEST_CASE_DEV_ARRAY='TEST_CASE_DEV_ARRAY[md/003]="/dev/nvme0n1 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1"'

=head2 BLKTESTS_MD_KVER

Optional. Overrides the minimum kernel version required by the md test group,
passed as C<BLKTESTS_MD_KVER> to C<./check>. Useful for distro kernels that
backport md atomic write support to an older base version. Example:

  BLKTESTS_MD_KVER=6 12 0

=head2 BLKTESTS_TRTYPES

Optional. NVMe transport type passed to blktests through C<NVMET_TRTYPES>.
This value is also available to C<BLKTESTS_KNOWN_ISSUES> entries through the
C<test_variant> matcher.

=cut
