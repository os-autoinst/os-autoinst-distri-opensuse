# SUSE's openQA tests
#
# Copyright 2019-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: The script to be run for testing saptune with 'mr_test'.
#          Also the main package with common methods and params for running 'mr_test'.
# Maintainer: QE-SAP <qe-sap@suse.de>, Ricardo Branco <rbranco@suse.de>, llzhao <llzhao@suse.com>

package mr_test_run;

use base "sles4sap";
use testapi;
use Utils::Backends;
use utils;
use version_utils qw(is_sle is_public_cloud);
use Utils::Architectures;
use Mojo::JSON 'encode_json';
use publiccloud::instances;
use strict;
use warnings;

our @EXPORT = qw(
  $result_module
  reboot_wait
  get_notes
  get_solutions
);

our $log_file = '/var/log.txt';
our $results_file = '/var/results.txt';
# Test result flag for test step
our $result;
# Test result flag for test module
our $result_module;

sub reboot_wait {
    my ($self) = @_;

    if (is_public_cloud) {
        # Reboot on publiccloud needs to happen via their dedicated reboot routine
        my $instance = publiccloud::instances::get_instance();
        $instance->softreboot(timeout => 1200);
    }
    else {
        $self->reboot;
    }
}

sub get_notes {
    # Note: We ignore these as we're not testing on cloud:
    # 1656250 - SAP on AWS: Support prerequisites - only Linux Operating System IO  recommendations
    # 2993054 - Recommended settings for SAP systems on Linux running in Azure virtual machines
    if (is_sle('>=15')) {
        return qw(1410736 1680803 1771258 1805750 1980196 2161991 2382421 2534844 2578899 2684254 3024346 900929 941735 SAP_BOBJ);
    }
    else {
        return qw(1410736 1680803 1771258 1805750 1980196 1984787 2161991 2205917 2382421 2534844 3024346 900929 941735 SAP_BOBJ);
    }
}

sub get_solutions {
    return qw(BOBJ HANA MAXDB NETWEAVER NETWEAVER+HANA S4HANA-APP+DB S4HANA-APPSERVER S4HANA-DBSERVER SAP-ASE);
}

sub tune_baseline {
    my $filename = shift;
    assert_script_run "sed -ri -e '/fs\\/file-max/s/:([0-9]*)\$/:~~\\1/' -e '/:scripts\\/shm_size/s/:([0-9]*)\$/:~~\\1/' $filename";
}


sub test_bsc1152598 {
    my ($self) = @_;

    my $SLE = is_sle(">=15") ? "SLE15" : "SLE12";
    $result = "ok";
    $self->result("$result");
    record_info "bsc1152598";

    $self->wrap_script_run("mr_test verify Pattern/${SLE}/testpattern_bsc1152598#1_1");
    assert_script_run
'echo -e "[version]\n# foobar-NOTE=foobar CATEGORY=foobar VERSION=0 DATE=foobar NAME=\" foobar \"\n[block]\nIO_SCHEDULER=noop, none, foobar\n" > /etc/saptune/extra/scheduler-test.conf';
    $self->wrap_script_run("saptune note apply scheduler-test");
    $self->wrap_script_run("mr_test verify Pattern/${SLE}/testpattern_bsc1152598#1_2");
    $self->wrap_script_run("saptune revert all");
    $self->wrap_script_run("mr_test verify Pattern/${SLE}/testpattern_bsc1152598#1_1");
    assert_script_run
'echo -e "[version]\n# foobar-NOTE=foobar CATEGORY=foobar VERSION=0 DATE=foobar NAME=\" foobar \"\n[block]\nIO_SCHEDULER=foobar, noop, none\n" > /etc/saptune/extra/scheduler-test.conf';
    $self->wrap_script_run('saptune note apply scheduler-test');
    $self->wrap_script_run("grep -E -q '\[(noop|none)\]' /sys/block/sda/queue/scheduler");
    $self->wrap_script_run("mr_test verify Pattern/${SLE}/testpattern_bsc1152598#1_2");
    $self->wrap_script_run("saptune revert all");

    assert_script_run "echo Test test_bsc1152598: $result >> $log_file";
    $self->result("$result");
}

sub test_delete {
    my ($self) = @_;

    my $dir = "Pattern/testpattern_saptune-delete+rename";
    my $note = "2161991";

    ### Deleting a shipped Note (without override/with override + not applied/applied)
    $result = "ok";
    $self->result("$result");
    record_info "delete note $note";
    $self->wrap_script_run("rm -f /etc/saptune/extra/* /etc/saptune/override/*");

    # (not-applied, no override)
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#1_1");
    $self->wrap_script_run("! saptune note delete ${note}");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#1_1");

    # (applied, no override)
    $self->wrap_script_run("saptune note apply ${note}");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#1_2");
    $self->wrap_script_run("! saptune note delete ${note}");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#1_2");

    # (applied, override)
    assert_script_run "echo -e '[version]\n# SAP-NOTE=testnote CATEGORY=test VERSION=0 DATE=01.01.1971 NAME=\"testnote\"' > /etc/saptune/override/${note}";
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#1_3");
    $self->wrap_script_run("! saptune note delete ${note}");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#1_3");

    # (not applied, override)
    $self->wrap_script_run("saptune note revert ${note}");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#1_4");
    $self->wrap_script_run("yes n | saptune note delete ${note}");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#1_4");
    $self->wrap_script_run("yes | saptune note delete ${note}");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#1_1");

    ### Deleting a created Note (without override/with override + not applied/applied)

    $self->wrap_script_run("rm -f /etc/saptune/extra/* /etc/saptune/override/*");

    # (applied, no override)
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#2_1");
    assert_script_run "echo -e '[version]\n# SAP-NOTE=testnote CATEGORY=test VERSION=0 DATE=01.01.1971 NAME=\"testnote\"' > /etc/saptune/extra/testnote.conf";
    $self->wrap_script_run("saptune note apply testnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#2_2");
    $self->wrap_script_run("! saptune note delete testnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#2_2");

    # (applied, override)
    assert_script_run "echo -e '[version]\n# SAP-NOTE=testnote CATEGORY=test VERSION=0 DATE=01.01.1971 NAME=\"testnote\"' > /etc/saptune/override/testnote";
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#2_3");
    $self->wrap_script_run("! saptune note delete testnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#2_3");

    # (not applied, override)
    $self->wrap_script_run("saptune note revert testnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#2_4");
    $self->wrap_script_run("yes n | saptune note delete testnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#2_4");
    $self->wrap_script_run("yes | saptune note delete testnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#2_1");

    # (not-applied, no override)
    assert_script_run "echo -e '[version]\n# SAP-NOTE=testnote CATEGORY=test VERSION=0 DATE=01.01.1971 NAME=\"testnote\"' > /etc/saptune/extra/testnote.conf";
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#2_5");
    $self->wrap_script_run("yes n | saptune note delete testnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#2_5");
    $self->wrap_script_run("yes | saptune note delete testnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#2_1");

    ### Deleting a non-existent Note

    $self->wrap_script_run("rm -f /etc/saptune/extra/* /etc/saptune/override/*");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#3_1");
    $self->wrap_script_run("! saptune note delete 999999");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#3_1");

    ### Renaming a shipped Note (without override/with override + not applied/applied)

    $self->wrap_script_run("rm -f /etc/saptune/extra/* /etc/saptune/override/*");

    assert_script_run "echo Test test_delete_$note: $result >> $log_file";
    $self->result("$result");
}

sub test_rename {
    my ($self) = @_;

    my $dir = "Pattern/testpattern_saptune-delete+rename";
    my $note = "2161991";

    ### Renaming a shipped Note (without override/with override + not applied/applied)
    $result = "ok";
    $self->result("$result");
    record_info "rename note $note";
    $self->wrap_script_run("rm -f /etc/saptune/extra/* /etc/saptune/override/*");

    # (not-applied, no override)
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#1_1");
    $self->wrap_script_run("! saptune note rename ${note} newnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#1_1");

    # (applied, no override)
    $self->wrap_script_run("saptune note apply ${note}");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#1_2");
    $self->wrap_script_run("! saptune note rename ${note} newnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#1_2");

    # (applied, override)
    assert_script_run "echo -e '[version]\n# SAP-NOTE=testnote CATEGORY=test VERSION=0 DATE=01.01.1971 NAME=\"testnote\"' > /etc/saptune/override/${note}";
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#1_3");
    $self->wrap_script_run("! saptune note rename ${note} newnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#1_3");

    # (not applied, override)
    $self->wrap_script_run("saptune note revert ${note}");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#1_4");
    $self->wrap_script_run("! saptune note rename ${note} newnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#1_4");

    ### Renaming a created Note (without override/with override + not applied/applied)

    $self->wrap_script_run("rm -f /etc/saptune/extra/* /etc/saptune/override/*");

    # (applied, no override)
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#2_1");
    assert_script_run "echo -e '[version]\n# SAP-NOTE=testnote CATEGORY=test VERSION=0 DATE=01.01.1971 NAME=\"testnote\"' > /etc/saptune/extra/testnote.conf";
    $self->wrap_script_run("saptune note apply testnote");
    $self->wrap_script_run("! saptune note rename testnote newnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#2_2");

    # (applied, override)
    assert_script_run "echo -e '[version]\n# SAP-NOTE=testnote CATEGORY=test VERSION=0 DATE=01.01.1971 NAME=\"testnote\"' > /etc/saptune/override/testnote";
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#2_3");
    $self->wrap_script_run("! saptune note rename testnote newnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#2_3");

    # (not applied, override)
    $self->wrap_script_run("saptune note revert testnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#2_4");
    $self->wrap_script_run("yes n | saptune note rename testnote newnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#2_4");
    $self->wrap_script_run("yes | saptune note rename testnote newnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#2_5");

    # (not-applied, no override)
    $self->wrap_script_run("rm /etc/saptune/override/newnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#2_6");
    $self->wrap_script_run("yes n | saptune note rename newnote testnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#2_6");
    $self->wrap_script_run("yes | saptune note rename newnote testnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#2_7");

    ### Renaming a created Note to an existing note (not applied)

    $self->wrap_script_run("rm -f /etc/saptune/extra/* /etc/saptune/override/*");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#3_1");
    assert_script_run "echo -e '[version]\n# SAP-NOTE=testnote CATEGORY=test VERSION=0 DATE=01.01.1971 NAME=\"testnote\"' > /etc/saptune/extra/testnote.conf";
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#3_2");
    $self->wrap_script_run("! saptune note rename testnote ${note}");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#3_2");

    ### Renaming a non-existent Note

    $self->wrap_script_run("rm -f /etc/saptune/extra/* /etc/saptune/override/*");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#4_1");
    $self->wrap_script_run("! saptune note rename 999999 999999");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#4_1");

    assert_script_run "echo Test test_rename_$note: $result >> $log_file";
    $self->result("$result");
}

sub test_note {
    my ($self, $note) = @_;

    my $SLE = is_sle(">=15") ? "SLE15" : "SLE12";
    my $extra = ($note eq "1771258") ? "-1" : "";

    $result = "ok";
    $self->result("$result");
    record_info "note $note";
    $self->wrap_script_run("mr_test verify Pattern/${SLE}/testpattern_baseline_Cust");
    $self->wrap_script_run("mr_test dump Pattern/${SLE}/testpattern_note_${note}${extra}_b > baseline_testpattern_note_${note}${extra}_b");
    $self->wrap_script_run("saptune note apply $note");
    $self->wrap_script_run("mr_test verify Pattern/${SLE}/testpattern_note_${note}${extra}_a");
    $self->wrap_script_run("mr_test verify baseline_testpattern_note_${note}${extra}_b");
    tune_baseline("baseline_testpattern_note_${note}${extra}_b");
    $self->reboot_wait;
    $self->wrap_script_run("mr_test verify Pattern/${SLE}/testpattern_note_${note}${extra}_a");
    $self->wrap_script_run("mr_test verify baseline_testpattern_note_${note}${extra}_b");
    $self->wrap_script_run("saptune note revert $note");
    $self->reboot_wait;

    assert_script_run "echo Test test_note_$note: $result >> $log_file";
    $self->result("$result");
}

sub test_override {
    my ($self, $note) = @_;

    my $SLE = is_sle(">=15") ? "SLE15" : "SLE12";

    # With notes 1557506 & 1771258 we have to test 2 override files
    my @overrides = ($note =~ m/^(1557506|1771258)$/) ? ("${note}-1", "${note}-2") : (${note});

    $result = "ok";
    $self->result("$result");
    record_info "override $note";

    if ($note eq "1680803") {
        # Ignore the tests for the scheduler if we can't set "none" on /dev/sr0
        assert_script_run("if [ -f /sys/block/sr0/queue/scheduler ] ; then "
              . "grep -q none /sys/block/sr0/queue/scheduler || "
              . "sed -i '/:scripts\\/nr_requests/s/^/#/' Pattern/$SLE/testpattern_note_${note}_a_override ; fi");
    }
    foreach my $override (@overrides) {
        $self->wrap_script_run("mr_test verify Pattern/${SLE}/testpattern_baseline_Cust");
        $self->wrap_script_run("mr_test dump Pattern/$SLE/testpattern_note_${override}_b > baseline_testpattern_note_${override}_b");
        $self->wrap_script_run("cp Pattern/$SLE/override/$override /etc/saptune/override/$note");
        $self->wrap_script_run("saptune note apply $note");
        $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_note_${override}_a_override");
        $self->wrap_script_run("mr_test verify baseline_testpattern_note_${override}_b");
        tune_baseline("baseline_testpattern_note_${override}_b");
        $self->reboot_wait;
        $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_note_${override}_a_override");
        $self->wrap_script_run("mr_test verify baseline_testpattern_note_${override}_b");
        $self->wrap_script_run("saptune note revert $note");
        $self->wrap_script_run("rm -f /etc/saptune/override/$note");
        $self->reboot_wait;
    }

    assert_script_run "echo Test test_override_$note: $result >> $log_file";
    $self->result("$result");
}

sub test_solution {
    my ($self, $solution) = @_;

    my $SLE = is_sle(">=15") ? "SLE15" : "SLE12";

    $result = "ok";
    $self->result("$result");
    record_info "solution $solution";

    $self->wrap_script_run("mr_test verify Pattern/${SLE}/testpattern_baseline_Cust");
    $self->wrap_script_run("mr_test dump Pattern/${SLE}/testpattern_solution_${solution}_b > baseline_testpattern_solution_${solution}_b");
    $self->wrap_script_run("saptune solution apply $solution");
    $self->wrap_script_run("mr_test verify Pattern/${SLE}/testpattern_solution_${solution}_a");
    $self->wrap_script_run("mr_test verify baseline_testpattern_solution_${solution}_b");
    tune_baseline("baseline_testpattern_solution_${solution}_b");
    $self->reboot_wait;
    $self->wrap_script_run("mr_test verify Pattern/${SLE}/testpattern_solution_${solution}_a");
    $self->wrap_script_run("mr_test verify baseline_testpattern_solution_${solution}_b");
    $self->wrap_script_run("saptune solution revert $solution");
    $self->reboot_wait;

    assert_script_run "echo Test test_solution_$solution: $result >> $log_file";
    $self->result("$result");
}

sub test_notes {
    my ($self) = @_;

    foreach my $note (get_notes()) {
        # Skip 1805750 (SYB: Usage of HugePages on Linux Systems with Sybase ASE)
        # The ASE docs don't recommend any specific value or formula, so it must
        # be tested with an override file in test_overrides()
        next if ($note eq "1805750");
        $self->test_note($note);
    }
}

sub test_overrides {
    my ($self) = @_;

    foreach my $note (get_notes()) {
        $self->test_override($note);
    }
}

sub test_solutions {
    my ($self) = @_;

    foreach my $solution (get_solutions()) {
        $self->test_solution($solution);
    }
}

sub test_ppc64le {
    my ($self) = @_;

    die "This test cannot be run on QEMU" if (is_qemu);
    my $SLE = is_sle(">=15") ? "SLE15" : "SLE12";

    record_info "ppc64le";
    $result = "ok";
    $self->result("$result");

    $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_Cust#Power_1");
    # Apply all notes except 1805750
    foreach my $note (get_notes()) {
        next if ($note eq "1805750");
        $self->wrap_script_run("saptune note apply $note");
    }
    $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_Cust#Power_2");
    $self->wrap_script_run("saptune revert all");
    $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_Cust#Power_3");

    assert_script_run "echo Test test_ppc64le: $result >> $log_file";
    $self->result("$result");
}


sub test_x86_64 {
    my ($self) = @_;

    my $SLE;
    my $note;

    if (is_sle(">=15")) {
        $SLE = "SLE15";
        $note = "2684254";
    }
    else {
        $SLE = "SLE12";
        $note = "2205917";
    }

    record_info "x86_64";
    $result = "ok";
    $self->result("$result");

    # energy_perf_bias=6
    $self->wrap_script_run("cpupower set -b 6");
    # governor=powersave
    $self->wrap_script_run('cpupower frequency-set -g powersave');
    # force_latency=max
    $self->wrap_script_run('cpupower idle-set -E');
    $self->reboot_wait;
    $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_Cust#Intel_1");
    $self->wrap_script_run("saptune note apply $note");
    $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_Cust#Intel_2");
    $self->wrap_script_run("saptune note revert $note");
    $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_Cust#Intel_1");
    assert_script_run "echo -e '[cpu]\\nenergy_perf_bias=powersave\\ngovernor=powersave\\nforce_latency=' > /etc/saptune/override/$note";
    $self->wrap_script_run("saptune note apply $note");
    $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_Cust#Intel_3");
    $self->wrap_script_run("saptune note revert $note");
    $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_Cust#Intel_1");
    assert_script_run "echo -e '[cpu]\\nenergy_perf_bias=\\ngovernor=\\nforce_latency=\\n' > /etc/saptune/override/$note";
    $self->wrap_script_run("saptune note apply $note");
    $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_Cust#Intel_4");
    $self->wrap_script_run("saptune note revert $note");
    $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_Cust#Intel_1");

    assert_script_run "echo Test test_x86_64_$note: $result >> $log_file";
    $self->result("$result");
}

sub wrapup_log_file {
    my %results;

    $results{tests} = [];
    my $output = script_output "cat $log_file";
    foreach my $line (split("\n", $output)) {
        my %aux = ();
        next unless ($line =~ /Test ([^:]+)/);
        $aux{name} = $1;
        $line =~ /Test .*: ([a-zA-z]+)/;
        if ($1 eq 'ok') {
            $aux{outcome} = 'passed';
        }
        elsif ($1 eq 'fail') {
            $aux{outcome} = 'failed';
        }
        $aux{test_index} = 0;
        push @{$results{tests}}, \%aux;
    }
    my $json = encode_json \%results;
    assert_script_run "echo '$json' > $results_file";
}

sub wrap_script_run {
    my ($self, $args) = @_;
    my $ret = '';
    my $log = '/tmp/log';

    $ret = script_run "$args > $log 2>&1";
    if ($ret) {
        script_run "cat $log";
        record_soft_failure('Error found:jsc#TEAM-7435');
        # These are known issues so mark them as 'softfail' not 'fail' for not blocking 'bot' auto approval
        # - sysstat service [FAIL] exited disabled != dead disabled
        # - sysstat (cronjob) [FAIL] ok == no link
        # - UserTasksMax [FAIL] max == 12288
        # - UserTasksMax (sapconf DropIn) [FAIL] regular == missing
        if (
            script_run(
"grep -Ev '(sysstat service.*FAIL.*exited disabled|sysstat \(cronjob\) .*FAIL.*ok|UserTasksMax.*FAIL.*max|UserTasksMax \(sapconf DropIn\).*FAIL.*regular)' $log"
            ))
        {
            $result = 'fail';
        }
        $result_module = $result;
        $self->result("$result");
    }
}

sub run {
    my ($self, $tinfo) = @_;
    my $test = $tinfo->test;

    # Cleanup test log file before run test cases
    assert_script_run "> $log_file";

    # Set test module result to "ok"
    $self->result("ok");
    $result_module = "ok";

    $test = quotemeta($test);
    if ($test eq "solutions") {
        $self->test_solutions;
    }
    elsif ($test eq "notes") {
        $self->test_notes;
    }
    elsif ($test eq "overrides") {
        $self->test_overrides;
    }
    elsif (grep { /^${test}$/ } get_solutions()) {
        $self->test_solution($test);
    }
    elsif (grep { /^${test}$/ } get_notes()) {
        # Skip 1805750 (SYB: Usage of HugePages on Linux Systems with Sybase ASE)
        # The ASE docs don't recommend any specific value or formula, so it must
        # be tested with an override file
        $self->test_note($test) if ($test ne "1805750");
        $self->test_override($test);
    }
    elsif ($test =~ m/^(x86_64|ppc64le)$/) {
        $self->test_x86_64 if (is_ipmi);
        $self->test_ppc64le if is_ppc64le();
        $self->test_bsc1152598;
    }
    elsif ($test eq "delete_rename") {
        $self->test_delete;
        $self->test_rename;
    }
    else {
        die "Invalid value for MR_TEST=$test";
    }

    # Reset test module result according to global test result flag
    $self->result("$result_module");

    # Do IPA parsing and upload log file
    wrapup_log_file();
    parse_extra_log(IPA => $results_file);
    upload_logs $log_file;
}

sub post_fail_hook {
    my ($self) = @_;

    return if get_var('PUBLIC_CLOUD_SLES4SAP');
    $self->SUPER::post_fail_hook;
}

1;
