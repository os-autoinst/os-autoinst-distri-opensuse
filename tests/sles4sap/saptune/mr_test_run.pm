# SUSE's openQA tests
#
# Copyright 2019-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: The script to be run for testing saptune with 'mr_test'.
#          Also the main package with common methods and params for running 'mr_test'.
# Maintainer: QE-SAP <qe-sap@suse.de>, Ricardo Branco <rbranco@suse.de>, llzhao <llzhao@suse.com>

package mr_test_run;

use base 'sles4sap';
use testapi;
use Utils::Backends;
use utils;
use version_utils qw(is_sle is_public_cloud);
use Utils::Architectures;
use Mojo::JSON 'encode_json';
use publiccloud::instances;

=head1 NAME

sles4sap/saptune/mr_test_run.pm - Wrapper to run selected B<mr_test> saptune tests

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=head1 DESCRIPTION

This module is scheduled by C<sles4sap/saptune/mr_test.pm> according to the contents of
the B<MR_TEST> setting, which contains the selection of B<mr_test> test units to run.

B<The key tasks performed by this module include:>

=over

=item * Extract the type of test to run from the C<tinfo> structure passed to the module. Values can
be: C<solutions>, C<notes>, C<overrides>, C<delete_rename>, a specific SAP note, a specific Solution,
C<x86_64> or C<ppc64le>.

=item * Call the method which implements the type of test selected.

=item * Parse log files for results and upload logs.

=item * Record results into the test.

=back

=head1 OPENQA SETTINGS

=over

=item * MR_TEST: list of C<mr_test> tests to run. See acceptable values above.

=item * VERSION: OS version of the System Under Test.

=back

=cut

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

=head1 METHODS

=head2 reboot_wait

    $self->reboot_wait;

Reboot the System Under Test.

=cut

sub reboot_wait {
    my ($self) = @_;

    if (is_public_cloud()) {
        # Reboot on publiccloud needs to happen via their dedicated reboot routine
        my $instance = publiccloud::instances::get_instance();
        $instance->softreboot(timeout => 1200);
    }
    else {
        $self->reboot;
    }
}

=head2 get_notes

    get_notes();

Return a list of SAP notes depending on the OS version of the System Under Test.

=cut

sub get_notes {
    # Note: We ignore these as we're not testing on cloud:
    # 1656250 - SAP on AWS: Support prerequisites - only Linux Operating System IO  recommendations
    # 2993054 - Recommended settings for SAP systems on Linux running in Azure virtual machines
    if (is_sle('>=16')) {
        return qw(1410736 1980196 2161991 2382421 2534844 3024346 3565382 3577842 900929 941735 SAP_BOBJ);
    }
    if (is_sle('>=15')) {
        return qw(1410736 1680803 1771258 1805750 1980196 2161991 2382421 2534844 2578899 2684254 3024346 900929 941735 SAP_BOBJ);
    }
    else {
        return qw(1410736 1680803 1771258 1805750 1980196 1984787 2161991 2205917 2382421 2534844 3024346 900929 941735 SAP_BOBJ);
    }
}

=head2 get_solutions

    get_solutions();

Return a list of SAP solutions depending on the OS version of the System Under Test.

=cut

sub get_solutions {
    my @solutions = qw(BOBJ HANA MAXDB NETWEAVER NETWEAVER+HANA S4HANA-APP+DB S4HANA-APPSERVER S4HANA-DBSERVER);
    return (@solutions, 'SAP-ASE') if is_sle('<16');
    return @solutions;
}

=head2 tune_baseline

    tune_baseline('/path/to/baseline_file');

Replaces in a baseline pattern file the values of B<fs.file-max> or
of the TMPFS on B</dev/shm> for the existing value prepended by B<~~>.
This makes the matching not exact, and instead checks against a 5% deviation of the value.
This is useful in some tests.

=cut

sub tune_baseline {
    my $filename = shift;
    assert_script_run "sed -ri -e '/fs\\/file-max/s/:([0-9]*)\$/:~~\\1/' -e '/:scripts\\/shm_size/s/:([0-9]*)\$/:~~\\1/' $filename";
}

=head2 test_bsc1152598

    $self->test_bsc1152598;

Run pattern tests for https://bugzilla.suse.com/show_bug.cgi?id=1152598

=cut

sub test_bsc1152598 {
    my ($self) = @_;
    my $custom_note_path = '/etc/saptune/extra/scheduler-test.conf';
    # Note's version header format is different in SLES 16
    my $note1_content = '"[version]\n# foobar-NOTE=foobar CATEGORY=foobar VERSION=0 DATE=foobar NAME=\" foobar \"\n[block]\nIO_SCHEDULER=noop, none, foobar\n"';
    $note1_content = '"[version]\nVERSION=0\nDATE=foobar\nDESCRIPTION=\" foobar \"\nREFERECENCES=https://me.sap.com/notes/1234\n[block]\nIO_SCHEDULER=noop, none, foobar\n"' if is_sle('>=16');
    my $note2_content = '"[version]\n# foobar-NOTE=foobar CATEGORY=foobar VERSION=0 DATE=foobar NAME=\" foobar \"\n[block]\nIO_SCHEDULER=foobar, noop, none\n"';
    $note2_content = '"[version]\n#VERSION=0\nDATE=foobar\nDESCRIPTION=\" foobar \"\nREFERENCES=https://me.sap.com/notes/1234\n[block]\nIO_SCHEDULER=foobar, noop, none\n"' if is_sle('>=16');

    my $SLE = is_sle(">=16") ? "SLE16" : is_sle(">=15") ? "SLE15" : "SLE12";
    $result = "ok";
    $self->result("$result");
    record_info "bsc1152598";

    $self->wrap_script_run("mr_test verify Pattern/${SLE}/testpattern_bsc1152598#1_1");
    $self->wrap_assert_script_run_with_newlines($note1_content, $custom_note_path);
    $self->wrap_script_run("saptune note apply scheduler-test");
    $self->wrap_script_run("mr_test verify Pattern/${SLE}/testpattern_bsc1152598#1_2");
    $self->wrap_script_run("saptune revert all");
    $self->wrap_script_run("mr_test verify Pattern/${SLE}/testpattern_bsc1152598#1_1");
    $self->wrap_assert_script_run_with_newlines($note2_content, $custom_note_path);
    $self->wrap_script_run('saptune note apply scheduler-test');
    $self->wrap_script_run("grep -E -q '\[(noop|none)\]' /sys/block/sda/queue/scheduler");
    $self->wrap_script_run("mr_test verify Pattern/${SLE}/testpattern_bsc1152598#1_2");
    $self->wrap_script_run("saptune revert all");

    assert_script_run "echo Test test_bsc1152598: $result >> $log_file";
    $self->result("$result");
}

=head2 test_delete

    $self->test_delete;

Run C<saptune delete note 2161991> and then run the B<saptune-delete> test patterns to verify
the note has been properly deleted from the System Under Test.

=cut

sub test_delete {
    my ($self) = @_;
    # Note's version header is different in SLES 16
    my $note_content = "'[version]\n# SAP-NOTE=testnote CATEGORY=test VERSION=0 DATE=01.01.1971 NAME=\"testnote\"'";
    $note_content = "'[version]\nVERSION=0\nDATE=01.01.1971\nDESCRIPTION=testnote\nREFERENCES=https://me.sap.com/notes/1234\n'" if is_sle('>=16');

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
    $self->wrap_assert_script_run_with_newlines($note_content, "/etc/saptune/override/${note}");
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
    $self->wrap_assert_script_run_with_newlines($note_content, '/etc/saptune/extra/testnote.conf');
    $self->wrap_script_run("saptune note apply testnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#2_2");
    $self->wrap_script_run("! saptune note delete testnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-delete#2_2");

    # (applied, override)
    $self->wrap_assert_script_run_with_newlines($note_content, '/etc/saptune/override/testnote');
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
    $self->wrap_assert_script_run_with_newlines($note_content, '/etc/saptune/extra/testnote.conf');
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

=head2 test_rename

    $self->test_rename;

Run C<saptune rename note 2161991 newnote>, create a custom note B<testnote> and run
C<saptune rename note testnote newnote>, while checking changes to the System Under Test with
the appropiarte B<saptune-rename> test patterns.

=cut

sub test_rename {
    my ($self) = @_;

    my $dir = "Pattern/testpattern_saptune-delete+rename";
    my $note = "2161991";
    # Note's header format is different in SLES 16
    my $note_content = "'[version]\n# SAP-NOTE=testnote CATEGORY=test VERSION=0 DATE=01.01.1971 NAME=\"testnote\"'";
    $note_content = "'[version]\nVERSION=0\nDATE=01.01.1971\nDESCRIPTION=testnote\nREFERENCES=https://me.sap.com/notes/1234\n'" if is_sle('>=16');

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
    $self->wrap_assert_script_run_with_newlines($note_content, "/etc/saptune/override/${note}");
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
    $self->wrap_assert_script_run_with_newlines($note_content, '/etc/saptune/extra/testnote.conf');
    $self->wrap_script_run("saptune note apply testnote");
    $self->wrap_script_run("! saptune note rename testnote newnote");
    $self->wrap_script_run("mr_test verify ${dir}/testpattern_saptune-rename#2_2");

    # (applied, override)
    $self->wrap_assert_script_run_with_newlines($note_content, '/etc/saptune/override/testnote');
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
    $self->wrap_assert_script_run_with_newlines($note_content, '/etc/saptune/extra/testnote.conf');
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

=head2 test_note

    $self->test_note($note);

Apply the note specified by C<$note> with C<saptune note apply $note> and then verify
the note was successfully applied in the System Under Test by checking with the C<mr_test>
patterns related to the specified note.

Reboot the SUT, and test the note is still applied.

Finally, revert the note with C<saptune note revert $note> and reboot the SUT.

=cut

sub test_note {
    my ($self, $note) = @_;

    my $SLE = is_sle(">=16") ? "SLE16" : is_sle(">=15") ? "SLE15" : "SLE12";
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

=head2 test_override

    $self->test_override($note);

Copy the override configuration files related to the note specified by C<$note>, apply the note
with C<saptune note apply $note> and then verify the overrides related to the note were successfully
applied in the System Under Test by checking with the C<mr_test> patterns related to the specified note
and overrides.

Reboot the SUT, and test the note and overrides are still applied.

Finally, revert the note with C<saptune note revert $note> and remove the override configuration file,
and reboot the SUT again.

=cut

sub test_override {
    my ($self, $note) = @_;

    my $SLE = is_sle(">=16") ? "SLE16" : is_sle(">=15") ? "SLE15" : "SLE12";
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

=head2 test_solution

    $self->test_solution($solution);

Apply in the System Under Test the solution referenced by C<$solution> with the command
C<saptune solution apply $solution> and then check the solution was successfully applied
by running the B<mr_test> related pattern tests.

Before applying the solution, verify with B<mr_test> against an expected baseline.

Reboot the SUT, and verify again the solution is applied.

Finally, revert the solution with C<saptune solution revert $solution> and reboot the
SUT again.

On SLES for SAP 16 or newer, revert the solution B<SAP_Base> before starting the test.

=cut

sub test_solution {
    my ($self, $solution) = @_;

    my $SLE = is_sle('>=16') ? 'SLE16' : is_sle('>=15') ? 'SLE15' : 'SLE12';
    $result = 'ok';
    $self->result("$result");
    record_info "solution $solution";

    # SLES for SAP 16 comes pre-configured with the SAP_Base solution. We need to revert it before starting
    $self->wrap_script_run('saptune solution revert SAP_Base') if is_sle('>=16');
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

=head2 test_notes

    $self->test_notes;

Call C<$self-E<gt>test_note()> for all notes returned by C<get_notes()>.

=cut

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

=head2 test_overrides

    $self->test_overrides;

Call C<$self-E<gt>test_override()> for all notes returned by C<get_notes()>.

=cut

sub test_overrides {
    my ($self) = @_;

    foreach my $note (get_notes()) {
        $self->test_override($note);
    }
}

=head2 test_solutions

    $self->test_solutions;

Call C<$self-E<gt>test_solution()> for all solutions returned by C<get_solutions()>.

=cut

sub test_solutions {
    my ($self) = @_;

    foreach my $solution (get_solutions()) {
        $self->test_solution($solution);
    }
}

=head2 test_ppc64le

    $self->test_ppc64le;

Run B<mr_test> pattern test specific for the B<ppc64le> architecture. Apply all notes
returned by C<get_notes> with the exception of note 1805750 which does not apply to the
B<ppc64le> architecture and verify with the pattern tests that the changes were applied.
Finally, revert all notes, and do another pattern test.

=cut

sub test_ppc64le {
    my ($self) = @_;

    die "This test cannot be run on QEMU" if (is_qemu);
    my $SLE = is_sle(">=16") ? "SLE16" : is_sle(">=15") ? "SLE15" : "SLE12";
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

=head2 test_x86_64

    $self->test_x86_64;

Run Intel specific pattern tests from B<mr_test> after applying and reverting one
specific note depending on the OS version in the System Under Test.

=cut

sub test_x86_64 {
    my ($self) = @_;

    my $SLE;
    my $note;

    if (is_sle('>=16')) {
        $SLE = 'SLE16';
        $note = '3577842';
    }
    elsif (is_sle('>=15')) {
        $SLE = 'SLE15';
        $note = '2684254';
    }
    else {
        $SLE = 'SLE12';
        $note = '2205917';
    }

    record_info "x86_64";
    $result = "ok";
    $self->result("$result");

    # automatically applied SAP_Base solution on SLE 16.0 for SAP
    # we need to revert it first
    $self->wrap_script_run("saptune revert all") if (is_sle('>=16'));
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
    $self->wrap_assert_script_run_with_newlines("'[cpu]\\nenergy_perf_bias=powersave\\ngovernor=powersave\\nforce_latency='", "/etc/saptune/override/$note");
    $self->wrap_script_run("saptune note apply $note");
    $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_Cust#Intel_3");
    $self->wrap_script_run("saptune note revert $note");
    $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_Cust#Intel_1");
    $self->wrap_assert_script_run_with_newlines("'[cpu]\\nenergy_perf_bias=\\ngovernor=\\nforce_latency=\\n'", "/etc/saptune/override/$note");
    $self->wrap_script_run("saptune note apply $note");
    $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_Cust#Intel_4");
    $self->wrap_script_run("saptune note revert $note");
    $self->wrap_script_run("mr_test verify Pattern/$SLE/testpattern_Cust#Intel_1");

    assert_script_run "echo Test test_x86_64_$note: $result >> $log_file";
    $self->result("$result");
}

=head2 wrapup_log_file

    wrapup_log_file();

Parse B<mr_test> logfiles and create from its contents a results file in JSON format
which can later be use to upload results for the openQA test.

=cut

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
        elsif ($1 eq 'softfail') {
            $aux{outcome} = 'softfailed';
        }
        $aux{test_index} = 0;
        push @{$results{tests}}, \%aux;
    }
    my $json = encode_json \%results;
    assert_script_run "echo '$json' > $results_file";
}

=head2 wrap_assert_script_run_with_newlines

    $self->wrap_assert_script_run_with_newlines($string, $file);

Create in the System Under Test a file in the location specified by C<$file> with the
content specified in C<$string>. Avoid doing this with C<assert_script_run> as it can
fail if the file content contains newlines. Instead verify the file can be created,
add the content with C<enter_cmd> and wait for the result with C<wait_serial>.

=cut

sub wrap_assert_script_run_with_newlines {
    my ($self, $content, $file) = @_;
    # When calling assert_script_run() with a text that includes newlines (\n), the
    # wait_serial() API called by assert_script_run() internally, can fail and show
    # error details even on tests which are otherwise working. Since this module
    # uses this a lot to create custom notes in the form:
    # assert_script_run "echo -e 'note\ncontent\n' > /path/to/file";
    # This method provides a workaround to avoid wait_serial() errors:

    # 1. First it checks the file can be written to, with assert_script_run() and an
    #    empty content
    assert_script_run "echo > $file";

    # 2. Then actually writes to the file using enter_cmd() and print the return value
    #    of the command
    enter_cmd "echo -e $content > $file ; echo enter_cmd_DONE-\$?";

    # 3. Finally waits for the return value
    wait_serial qr/enter_cmd_DONE-\d/;
}

=head2 wrap_script_run

    $self->wrap_script_run($command);

Run the command specified in C<$command> in the System Under Test.

In cases where the command execution fails (return value different than 0), parse the log
to extract probably causes of the failure and set C<$result> to B<fail>.

=cut

sub wrap_script_run {
    my ($self, $args) = @_;
    my $ret = '';
    my $ret_tmp = '';
    my $log = '/tmp/log';

    $ret = script_run "$args > $log 2>&1";
    if ($ret) {
        # Debug purpose
        my $output = script_output("cat $log");
        record_info("Issue Found", "$output");

        # These are known issues so mark them as 'softfail' not 'fail' for not blocking 'bot' auto approval:
        # For more details please refer to: https://confluence.suse.com/display/qasle/TEAM-8662+%5Bsaptune%5D+mr_test+in+CSP+for+saptune+3.1
        #   In saptune 3.1 we have added SAP Note 1868829 to all HANA-related solutions as well removed 1410736 from ASE.
        #   The current mr_test patterns simply do not reflect that change. See TEAM-7435
        #     - HANA (notes) 1868829
        #     - ASE (notes) 1410736
        #   Leftover
        #     - soft memlock for sybase      [FAIL]  8192 == 64
        #     - hard memlock for sybase      [FAIL]  8192 == 64

        if ($output =~ /.*memlock\sfor\ssybase/) {
            record_info('Issue can be ignored, see jsc#TEAM-8662 for more details', "$output");
        }
        elsif ($output =~ /HANA.*notes.*1868829/) {
            record_info('Issue can be ignored, see jsc#TEAM-8662 for more details', "$output");
        }
        elsif ($output =~ /ASE.*notes.*1410736/) {
            record_info('Issue can be ignored, see jsc#TEAM-8662 for more details', "$output");
        }
        elsif ($output =~ /transparent_hugepage.*always\s\[madvise\]\snever ==/) {
            # Default is changed to madavise in two contexts:
            # - for Power
            # - on 15-SP5+ according to SAP Note 2131662 and 2031375
            if (is_pvm or is_sle('>=15-SP5')) {
                record_info('Issue can be ignored, see jsc#TEAM-9086', "$output");
            }
            else {
                $result = 'fail';
                record_info('Issue can NOT be ignored, see jsc#TEAM-8662 for more details', "$output");
            }
        }
        elsif ($output =~ /solution.*notes.*==.*1410736/ && $output =~ /net\.ipv4\.tcp_keepalive_time.*1250/) {
            # SP6 is shipped with saptune v3.1.2. The ASE solution in this version contains the Notes: 941735 1680803 1771258 2578899 2993054 1656250.
            # The test still assumes, that 1410736 is part of the solution, which sets (among others) net.ipv4.tcp_keepalive_time.
            record_info('Issue can be ignored, see jsc#TEAM-9086', "$output");
        }
        else {
            $result = 'fail';
            record_info('Issue can NOT be ignored, see jsc#TEAM-8662 for more details', "$output");
        }

        if (is_public_cloud() && ($result == 'fail')) {
            # Mark Public Cloud test cases as 'softfail' not 'fail' for not blocking 'bot' auto approval
            # as for 'saptune 3.1' current/old 'mr_test' do not fit cloud instances
            #   UserTasksMax
            #     - UserTasksMax [FAIL] max == 12288
            #     - UserTasksMax (sapconf DropIn) [FAIL] regular == missing
            $ret_tmp = script_run("grep -E '(UserTasksMax.*[FAIL])' $log");
            if ($ret_tmp == 0) {
                my $ret0
                  = script_run("cat $log | grep -E '([FAIL]|[WARN])' | grep -Ev '(UserTasksMax.*max.*12288|UserTasksMax.*sapconf DropIn.*regular.*missing)'");
                if ($ret0) {
                    $result = 'softfail';
                }
            }
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
