# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Kernel Selftests helper functions
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kselftests::utils;

use base Exporter;
use testapi;
use strict;
use warnings;
use utils;
use Kselftests::parser;
use LTP::WhiteList;
use version_utils qw(is_sle);
use base 'opensusebasetest';

our @EXPORT = qw(
  install_from_git
  install_from_repo
  post_process
  validate_kconfig
);

sub install_from_git
{
    my ($collection) = @_;

    my $git_tree = get_var('KERNEL_GIT_TREE', 'https://github.com/torvalds/linux.git');
    my $git_tag = get_var('KERNEL_GIT_TAG', '');
    zypper_call('in bc git-core ncurses-devel gcc flex bison libelf-devel libopenssl-devel kernel-devel');
    assert_script_run("git clone --depth 1 --single-branch --branch master $git_tree linux", 240);

    assert_script_run("cd ./linux");

    if ($git_tag ne '') {
        assert_script_run("git fetch --unshallow --tags", 7200);
        assert_script_run("git checkout $git_tag");
    }

    assert_script_run("make -j `nproc` -C tools/testing/selftests install TARGETS=$collection", 7200);
    script_run("cp tools/testing/selftests/$collection/config* tools/testing/selftests/kselftest_install/$collection");
}

sub install_from_repo
{
    my $repo = get_var('KSELFTEST_REPO', '');
    zypper_call("ar -p 1 -f $repo kselftests");
    zypper_call("--gpg-auto-import-keys ref");
    zypper_call("install -y kselftests kernel-devel");
}

sub post_process {
    my ($collection, @tests) = @_;

    my $ret = 0;

    my $default_whitelist_file = 'https://raw.githubusercontent.com/openSUSE/kernel-qe/refs/heads/main/kselftests_known_issues.yaml';
    if (is_sle) {
        $default_whitelist_file = 'https://qam.suse.de/known_issues/kselftests.yaml';
    }
    my $whitelist_file = get_var('KSELFTEST_KNOWN_ISSUES', $default_whitelist_file);
    my $whitelist = LTP::WhiteList->new($whitelist_file);
    my $env = {
        product => get_var('DISTRI', '') . ':' . get_var('VERSION', ''),
        arch => get_var('ARCH', ''),
    };

    my @full_ktap;
    my @summary = split(/\n/, script_output("cat summary.tap"));
    my $summary_ln_idx = 0;
    my $test_index = 0;

    for my $test (@tests) {
        $test_index++;
        my $test_name = $test =~ s/^\w+://r;    # Remove the $collection from it, sub . with _
        my $sanitized_test_name = $test_name =~ s/\.|-/_/gr;    # Dots and hyphens should be underscore for better handling in Perl and YAML files

        # Check test result in the summary
        my $summary_ln;
        while ($summary_ln_idx < @summary) {
            $summary_ln = $summary[$summary_ln_idx];
            $summary_ln_idx++;
            if ($summary_ln =~ /^(not )?ok \d+ selftests: \S+: \S+/) {
                my $test_failed = $summary_ln =~ /^not ok/ ? 1 : 0;
                if ($test_failed && $whitelist->find_whitelist_entry($env, $collection, $sanitized_test_name)) {
                    $ret = 1;
                    record_info("Known Issue", "$test marked as softfail");
                    $summary_ln = "ok $test_index selftests: $collection: $test_name # TODO Known Issue";
                }
                # Break and keep the index so that we only read each line in the summary once
                last;
            } else {
                # Push all lines that are not test results to the full log
                push(@full_ktap, $summary_ln);
            }
        }

        # Check each subtest result in the individual test log
        my @log = split(/\n/, script_output("cat /tmp/$test_name"));    # When using `--per-test-log`, that's where they are found
        my $parser = Kselftests::parser::factory($collection, $sanitized_test_name);
        my $hardfails = 0;
        my $fails = 0;
        for my $test_ln (@log) {
            $test_ln = $parser->parse_line($test_ln);
            if (!$test_ln) {
                next;
            }
            if ($test_ln =~ /^# not ok (\d+) (\S+)/) {
                my $subtest_idx = $1;
                my $subtest_name = $2;
                if ($whitelist->find_whitelist_entry($env, $collection, $subtest_name)) {
                    $ret = 1;
                    record_info("Known Issue", "$test:$subtest_name marked as softfail");
                    $test_ln = "# ok $subtest_idx $subtest_name # TODO Known Issue";
                } else {
                    $hardfails++;
                }
                $fails++;
            }
            push(@full_ktap, $test_ln);
        }

        if ($fails > 0 && $hardfails == 0) {
            record_info("Known Issue", "All failed subtests in $test are known issues; propagating TODO directive to the top-level");
            $summary_ln = "ok $test_index selftests: $collection: $test_name # TODO Known Issue";
        }

        push(@full_ktap, $summary_ln);
        upload_logs("/tmp/$test_name", log_name => "$test_name.tap.txt");
    }

    upload_logs("summary.tap", log_name => "summary.tap.txt");

    script_output("cat <<'EOF' > kselftest.tap.txt\n" . join("\n", @full_ktap) . "\nEOF");
    parse_extra_log(KTAP => 'kselftest.tap.txt');    # Append .txt so that it can be easily previewed within openQA

    return $ret;
}

sub validate_kconfig
{
    my ($collection) = @_;
    if (script_run("test -f $collection/config") != 0) {
        return;
    }
    my $arch = script_output('uname -m');
    my @expected = split(/\n/, script_output("cat $collection/{config,config.$arch}"));
    if (!@expected) {
        return;
    }
    my $kver = script_output('uname -r');
    if (script_run("test -f /boot/config-$kver") != 0) {
        record_info('KConfig', "Unable to find /boot/config-$kver file");
        return;
    }
    assert_script_run('wget https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/scripts/config && chmod +x config');
    my @mismatches;
    for my $expected (@expected) {
        my ($sym, $expected_st);
        if ($expected =~ /^#\s(CONFIG_[^\s]+)\s+is\s+not\s+set/) {
            $sym = $1;
            $expected_st = "undef";
        } elsif ($expected =~ /^(CONFIG_[^=\s]+)=(.+)$/) {
            $sym = $1;
            $expected_st = $2;
        } else {
            next;
        }
        my $actual_st = script_output("./config --state --file /boot/config-$kver $sym");
        if ($actual_st ne $expected_st) {
            my $mismatch = "$sym => $actual_st (actual) -> $expected_st (expected)";
            push(@mismatches, $mismatch);
        }
    }
    if (@mismatches) {
        script_output("cat <<'EOF' > config_mismatches.txt\n" . join("\n", @mismatches) . "\nEOF");
        upload_logs("config_mismatches.txt");
    }
}

1;
