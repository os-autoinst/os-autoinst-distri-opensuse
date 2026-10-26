# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Refresh repositories, apply patches and reboot
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use registration;
use testapi;
use utils qw(ssh_fully_patch_system);
use publiccloud::utils;
use publiccloud::ssh_interactive qw(select_host_console);
use version_utils qw(is_sle_micro is_sle);
use qam qw(get_test_repos);

sub run {
    my ($self, $args) = @_;
    select_host_console();    # select console on the host, not the PC instance

    my $cmd_time = time();
    my $ref_timeout = check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE') ? 3600 : 240;
    my $instance = $args->{my_instance};
    my $remote = $instance->username . '@' . $instance->public_ip;

    my $rpm_qa_command = 'rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n" | sort';
    my $rpm_list_before = "/var/tmp/rpm-qa-before-patch-system.txt";
    my $rpm_list_after = "/var/tmp/rpm-qa-after-patch-system.txt";
    # kernel-azure is discontinued in LTSS so we need to replace it with kernel-default
    if (is_ondemand && is_azure && is_sle('<=15-SP6')) {
        record_info('kernel-azure Switch', 'Switching from kernel-azure to kernel-default for LTSS');
        $args->{my_instance}->ssh_script_retry(
            "sudo zypper -n in kernel-default -kernel-azure",
            timeout => 600,
            retry => 3,
            delay => 60
        );
    }

    # Record package list before fully patch system
    $instance->ssh_assert_script_run(cmd => $rpm_qa_command . ' | tee ' . $rpm_list_before, timeout => 180);
    $instance->upload_log($rpm_list_before);

    $args->{my_instance}->ssh_script_retry("sudo zypper -n --gpg-auto-import-keys ref", timeout => $ref_timeout, retry => 6, delay => 60, fail_message => 'Remote execution of zypper ref failed. See previous steps for details');
    record_info('zypper ref time', 'The command zypper -n ref took ' . (time() - $cmd_time) . ' seconds.');
    record_soft_failure('bsc#1195382 - Considerable decrease of zypper performance and increase of registration times') if ((time() - $cmd_time) > 240);
    if (is_sle_micro) {
        ssh_update_transactional_system($args->{my_instance});
    } else {
        ssh_fully_patch_system($remote, $args->{my_instance});
    }
    record_info('UNAME', $args->{my_instance}->ssh_script_output(cmd => 'uname -a'));
    $args->{my_instance}->ssh_assert_script_run(cmd => 'rpm -qa > /tmp/rpm-qa.txt');
    $args->{my_instance}->upload_log('/tmp/rpm-qa.txt');

    if (is_cloudinit_supported) {
        $args->{my_instance}->cleanup_cloudinit();
        $args->{my_instance}->softreboot(scan_ssh_host_key => 1);
        permit_root_login($args->{my_instance});
    } else {
        $args->{my_instance}->softreboot();
    }

    # Record package list after fully patch system
    $instance->ssh_assert_script_run(cmd => $rpm_qa_command . ' | tee ' . $rpm_list_after, timeout => 180);
    $instance->upload_log($rpm_list_after);

    # Check if list is not empty
    $instance->ssh_assert_script_run(cmd => "test -s $rpm_list_before", fail_message => 'The package list before patching is empty, check the log for details');
    $instance->ssh_assert_script_run(cmd => "test -s $rpm_list_after", fail_message => 'The package list after patching is empty, check the log for details');

    my $rpm_list_diff = "/var/tmp/rpm-qa-diff.txt";
    $instance->ssh_assert_script_run(cmd => "diff $rpm_list_before $rpm_list_after | tee $rpm_list_diff");
    $instance->upload_log($rpm_list_diff);

    if (get_var('PUBLIC_CLOUD_REQUIRE_TEST_REPO_UPDATES') && get_test_repos()) {
        check_updates_from_test_repos($instance);
    } else {
        check_any_updates($instance, $rpm_list_diff);
    }
}

# Fail if the rpm list did not change at all
sub check_any_updates {
    my ($instance, $rpm_list_diff) = @_;
    return if $instance->ssh_script_run(cmd => "test -s $rpm_list_diff") == 0;
    _no_updates('No packages were updated during patching');
}

# Fail unless at least one installed package comes from a repo under test.
# Find these repos by URL, not by alias: the alias changes with the setup
# (TEST_N, ToTest_N, or the alias from a .repo file).
sub check_updates_from_test_repos {
    my ($instance) = @_;

    # Path of each repo under test, without the host part (transfer_repos replaces the host with a local dir)
    my @paths = grep { m{/} } map { s{^\s*(?:https?://.*?/ibs/)?|/*\s*$}{}gr } get_test_repos();

    my @test_repos;
    for my $line (split /\n/, $instance->ssh_script_output(cmd => 'sudo zypper -n lr -u')) {
        my @cols = map { s/^\s+|\s+$//gr } split /\|/, $line;
        next unless @cols > 2 && $cols[0] =~ /^\d+$/;    # skip header and separator lines
        my $uri = $cols[-1] =~ s{/+$}{}r;
        push @test_repos, $cols[1] if grep { $uri =~ m{(?:^|/)\Q$_\E$} } @paths;
    }
    return _no_updates('No repositories under test found on the instance') unless @test_repos;

    my $repo_args = join(' ', map { "-r $_" } @test_repos);
    my $out = '/var/tmp/installed-from-test-repos.txt';
    # zypper rc: 0 = matches, 104 = no match, anything else = other failure
    # No need for refresh, as it already happened during patching
    my $rc = $instance->ssh_script_run(
        cmd => "sudo zypper -n --no-refresh se -i -s -t package $repo_args > $out",
        timeout => 300,
        apply_graceful_timeout => 1);
    $instance->upload_log($out);

    if ($rc == 0) {
        # Keep only package rows - drop zypper's initial text and headers
        my @pkgs = grep { /^i/ } split /\n/, $instance->ssh_script_output(cmd => "cat $out");
        record_info('Repos under test', scalar(@pkgs) . " installed package(s) come from repos under test (@test_repos):\n" . join("\n", @pkgs));
        return;
    }
    return _no_updates('No installed packages come from the repos under test') if $rc == 104;
    die "zypper search failed with exit code $rc";
}

sub _no_updates {
    my ($msg) = @_;
    die $msg unless get_var('PUBLIC_CLOUD_IGNORE_EMPTY_UPDATES');
    record_info('PUBLIC_CLOUD_IGNORE_EMPTY_UPDATES', $msg);
}

sub test_flags {
    return {fatal => 1};
}

1;
