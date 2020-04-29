# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: saptune testing with mr_test
# Maintainer: Ricardo Branco <rbranco@suse.de>

use base "sles4sap";
use testapi;
use utils;
use version_utils 'is_sle';
use Utils::Architectures;
use strict;
use warnings;

sub reboot_wait {
    my ($self) = @_;

    $self->reboot;

    # Wait for tuned to tune everything
    my $timeout = 60;
    if (is_sle('>=15')) {
        assert_script_run "bash -c 'until tuned-adm verify >/dev/null ; do sleep 1 ; done'", $timeout;
    } else {
        sleep bmwqemu::scale_timeout($timeout);
    }
}

sub setup {
    my ($self) = @_;

    my $tarball = get_var('MR_TEST_TARBALL', 'https://gitlab.suse.de/rbranco/mr_test/-/archive/master/mr_test-master.tar.gz');

    $self->select_serial_terminal;
    # Disable packagekit
    pkcon_quit;
    # saptune is not installed by default on SLES4SAP 12 on ppc64le and in textmode profile
    zypper_call "-n in saptune" if ((is_ppc64le() and is_sle('<15')) or check_var('DESKTOP', 'textmode'));
    # Install mr_test dependencies
    zypper_call "-n in python3-rpm";
    # Download mr_test and extract it to $HOME
    assert_script_run "curl -sk $tarball | tar zxf - --strip-components 1";
    # Add $HOME to $PATH
    assert_script_run "echo 'export PATH=\$PATH:\$HOME' >> /root/.bashrc";
    # Remove any configuration set by sapconf
    assert_script_run "sed -i.bak '/^@/,\$d' /etc/security/limits.conf";
    script_run "mv /etc/systemd/logind.conf.d/sap.conf{,.bak}" unless check_var('DESKTOP', 'textmode');
    assert_script_run 'saptune daemon start';
    if (check_var('BACKEND', 'qemu')) {
        # Ignore disk_elevator on VM's
        assert_script_run "sed -ri '/:scripts\\/disk_elevator/s/^/#/' \$(fgrep -rl :scripts/disk_elevator Pattern/)";
    }
    $self->reboot_wait;
}

sub get_notes {
    if (is_sle('>=15')) {
        return qw(1410736 1680803 1771258 1805750 1980196 2161991 2382421 2534844 2578899 2684254 941735 SAP_BOBJ);
    } else {
        return qw(1410736 1557506 1680803 1771258 1805750 1980196 1984787 2161991 2205917 2382421 2534844 941735 SAP_BOBJ);
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

    assert_script_run "mr_test verify Pattern/${SLE}/testpattern_bsc1152598#1_1";
    assert_script_run 'echo -e "[version]\n# foobar-NOTE=foobar CATEGORY=foobar VERSION=0 DATE=foobar NAME=\" foobar \"\n[block]\nIO_SCHEDULER=none, foobar\n" > /etc/saptune/extra/scheduler-test.conf';
    assert_script_run 'grep -q noop /sys/block/[sv]da/queue/scheduler 2>/dev/null && sed -i s/none/noop/ /etc/saptune/extra/scheduler-test.conf';
    assert_script_run "saptune note apply scheduler-test";
    assert_script_run "mr_test verify Pattern/${SLE}/testpattern_bsc1152598#1_2";
    assert_script_run "saptune revert all";
    assert_script_run "mr_test verify Pattern/${SLE}/testpattern_bsc1152598#1_1";
    assert_script_run 'echo -e "[version]\n# foobar-NOTE=foobar CATEGORY=foobar VERSION=0 DATE=foobar NAME=\" foobar \"\n[block]\nIO_SCHEDULER=foobar, none\n" > /etc/saptune/extra/scheduler-test.conf';
    assert_script_run 'grep -q noop /sys/block/[sv]da/queue/scheduler 2>/dev/null && sed -i s/none/noop/ /etc/saptune/extra/scheduler-test.conf';
    assert_script_run 'saptune note apply scheduler-test';
    assert_script_run "mr_test verify Pattern/${SLE}/testpattern_bsc1152598#1_2";
    assert_script_run "saptune revert all";
}

sub test_delete {
    my ($self) = @_;

    my $dir  = "Pattern/testpattern_saptune-delete+rename";
    my $note = "2161991";

    ### Deleting a shipped Note (without override/with override + not applied/applied)

    assert_script_run "rm -f /etc/saptune/extra/* /etc/saptune/override/*";

    # (not-applied, no override)
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#1_1";
    assert_script_run "! saptune note delete ${note}";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#1_1";

    # (applied, no override)
    assert_script_run "saptune note apply ${note}";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#1_2";
    assert_script_run "saptune note delete ${note}";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#1_2";

    # (applied, override)
    assert_script_run "EDITOR=/bin/echo saptune note customise ${note}";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#1_3";
    assert_script_run "saptune note delete ${note}";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#1_3";

    # (not applied, override)
    assert_script_run "saptune note revert ${note}";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#1_4";
    assert_script_run "echo n | saptune note delete ${note}";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#1_4";
    assert_script_run "echo y | saptune note delete ${note}";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#1_1";

    ### Deleting a created Note (without override/with override + not applied/applied)

    assert_script_run "rm -f /etc/saptune/extra/* /etc/saptune/override/*";

    # (applied, no override)
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#2_1";
    assert_script_run "EDITOR=/bin/echo saptune note create testnote";
    assert_script_run "saptune note apply testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#2_2";
    assert_script_run "saptune note delete testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#2_2";

    # (applied, override)
    assert_script_run "EDITOR=/bin/echo saptune note customise testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#2_3";
    assert_script_run "saptune note delete testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#2_3";

    # (not applied, override)
    assert_script_run "saptune note revert testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#2_4";
    assert_script_run "echo n | saptune note delete testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#2_4";
    assert_script_run "echo y | saptune note delete testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#2_1";

    # (not-applied, no override)
    assert_script_run "EDITOR=/bin/echo saptune note create testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#2_5";
    assert_script_run "echo n | saptune note delete testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#2_5";
    assert_script_run "echo y | saptune note delete testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#2_1";

    ### Deleting a non-existent Note

    assert_script_run "rm -f /etc/saptune/extra/* /etc/saptune/override/*";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#3_1";
    assert_script_run "! saptune note delete 999999";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-delete#3_1";

    ### Renaming a shipped Note (without override/with override + not applied/applied)

    assert_script_run "rm -f /etc/saptune/extra/* /etc/saptune/override/*";
}

sub test_rename {
    my ($self) = @_;

    my $dir  = "Pattern/testpattern_saptune-delete+rename";
    my $note = "2161991";

    ### Renaming a shipped Note (without override/with override + not applied/applied)

    assert_script_run "rm -f /etc/saptune/extra/* /etc/saptune/override/*";

    # (not-applied, no override)
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#1_1";
    assert_script_run "! saptune note rename ${note} newnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#1_1";

    # (applied, no override)
    assert_script_run "saptune note apply ${note}";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#1_2";
    assert_script_run "! saptune note rename ${note} newnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#1_2";

    # (applied, override)
    assert_script_run "EDITOR=/bin/echo saptune note customise ${note}";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#1_3";
    assert_script_run "! saptune note rename ${note} newnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#1_3";

    # (not applied, override)
    assert_script_run "saptune note revert ${note}";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#1_4";
    assert_script_run "! saptune note rename ${note} newnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#1_4";

    ### Renaming a created Note (without override/with override + not applied/applied)

    assert_script_run "rm -f /etc/saptune/extra/* /etc/saptune/override/*";

    # (applied, no override)
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#2_1";
    assert_script_run "EDITOR=/bin/echo saptune note create testnote";
    assert_script_run "saptune note apply testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#2_2";
    assert_script_run "saptune note rename testnote newnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#2_2";

    # (applied, override)
    assert_script_run "EDITOR=/bin/echo saptune note customise testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#2_3";
    assert_script_run "saptune note rename testnote newnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#2_3";

    # (not applied, override)
    assert_script_run "saptune note revert testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#2_4";
    assert_script_run "echo n | saptune note rename testnote newnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#2_4";
    assert_script_run "echo y | saptune note rename testnote newnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#2_5";

    # (not-applied, no override)
    assert_script_run "rm /etc/saptune/override/newnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#2_6";
    assert_script_run "echo n | saptune note rename newnote testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#2_6";
    assert_script_run "echo y | saptune note rename newnote testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#2_7";

    ### Renaming a created Note to an existing note (not applied)

    assert_script_run "rm -f /etc/saptune/extra/* /etc/saptune/override/*";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#3_1";
    assert_script_run "EDITOR=/bin/echo saptune note create testnote";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#3_2";
    assert_script_run "! saptune note rename testnote ${note}";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#3_2";

    ### Renaming a non-existent Note

    assert_script_run "rm -f /etc/saptune/extra/* /etc/saptune/override/*";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#4_1";
    assert_script_run "! saptune note rename 999999 999999";
    assert_script_run "mr_test verify ${dir}/testpattern_saptune-rename#4_1";
}

sub test_sapconf {
    my ($self) = @_;

    my $SLE = is_sle(">=15") ? "SLE15" : "SLE12";

    # Scenario 1: sapconf is running and active with sap-netweaver profile.
    # The test shall show, that a running tuned profile or sapconf is not compromised.
    script_run 'cp /etc/systemd/logind.conf.d/sap.conf{.bak,}';
    # Otherwise sapconf will fail to start. See bsc#1139176
    assert_script_run "tuned-adm off" if is_sle('>=15');
    systemctl "enable --now sapconf";
    systemctl "disable tuned";
    systemctl "start tuned";
    if (is_sle('>=15')) {
        assert_script_run "tuned-adm profile sapconf";
    } else {
        assert_script_run "sapconf netweaver";
    }
    $self->reboot;
    assert_script_run "mr_test verify Pattern/$SLE/testpattern_Upd#2_2";

    # Scenario 2: sapconf has been disabled (only the service), but the package is still there.
    assert_script_run "cp /etc/security/limits.conf{.bak,}";
    systemctl "disable --now sapconf";
    $self->reboot;
    assert_script_run "mr_test verify Pattern/$SLE/testpattern_Upd#3_2";
}

sub test_note {
    my ($self, $note) = @_;

    my $SLE   = is_sle(">=15")       ? "SLE15" : "SLE12";
    my $extra = ($note eq "1771258") ? "-1"    : "";

    assert_script_run "mr_test verify Pattern/${SLE}/testpattern_baseline_Cust";
    assert_script_run "mr_test dump Pattern/${SLE}/testpattern_note_${note}${extra}_b > baseline_testpattern_note_${note}${extra}_b";
    assert_script_run "saptune note apply $note";
    assert_script_run "mr_test verify Pattern/${SLE}/testpattern_note_${note}${extra}_a";
    assert_script_run "mr_test verify baseline_testpattern_note_${note}${extra}_b";
    tune_baseline("baseline_testpattern_note_${note}${extra}_b");
    $self->reboot_wait;
    assert_script_run "mr_test verify Pattern/${SLE}/testpattern_note_${note}${extra}_a";
    assert_script_run "mr_test verify baseline_testpattern_note_${note}${extra}_b";
    assert_script_run "saptune note revert $note";
    $self->reboot_wait;
}

sub test_override {
    my ($self, $note) = @_;

    my $SLE = is_sle(">=15") ? "SLE15" : "SLE12";

    # With notes 1557506 & 1771258 we have to test 2 override files
    my @overrides = ($note =~ m/^(1557506|1771258)$/) ? ("${note}-1", "${note}-2") : (${note});

    if ($note eq "1680803") {
        # Ignore the tests for the scheduler if we can't set "noop" on /dev/sr0
        assert_script_run(
            "if [ -f /sys/block/sr0/queue/scheduler ] ; then "
              . "grep -q noop /sys/block/sr0/queue/scheduler || "
              . "sed -i '/:scripts\\/nr_requests/s/^/#/' Pattern/$SLE/testpattern_note_${note}_a_override ; fi"
        );
    }
    foreach my $override (@overrides) {
        assert_script_run "mr_test verify Pattern/${SLE}/testpattern_baseline_Cust";
        assert_script_run "mr_test dump Pattern/$SLE/testpattern_note_${override}_b > baseline_testpattern_note_${override}_b";
        assert_script_run "cp Pattern/$SLE/override/$override /etc/saptune/override/$note";
        assert_script_run "saptune note apply $note";
        assert_script_run "mr_test verify Pattern/$SLE/testpattern_note_${override}_a_override";
        assert_script_run "mr_test verify baseline_testpattern_note_${override}_b";
        tune_baseline("baseline_testpattern_note_${override}_b");
        $self->reboot_wait;
        assert_script_run "mr_test verify Pattern/$SLE/testpattern_note_${override}_a_override";
        assert_script_run "mr_test verify baseline_testpattern_note_${override}_b";
        assert_script_run "saptune note revert $note";
        assert_script_run "rm -f /etc/saptune/override/$note";
        $self->reboot_wait;
    }
}

sub test_solution {
    my ($self, $solution) = @_;

    my $SLE = is_sle(">=15") ? "SLE15" : "SLE12";

    assert_script_run "mr_test verify Pattern/${SLE}/testpattern_baseline_Cust";
    assert_script_run "mr_test dump Pattern/${SLE}/testpattern_solution_${solution}_b > baseline_testpattern_solution_${solution}_b";
    assert_script_run "saptune solution apply $solution";
    assert_script_run "mr_test verify Pattern/${SLE}/testpattern_solution_${solution}_a";
    assert_script_run "mr_test verify baseline_testpattern_solution_${solution}_b";
    tune_baseline("baseline_testpattern_solution_${solution}_b");
    $self->reboot_wait;
    assert_script_run "mr_test verify Pattern/${SLE}/testpattern_solution_${solution}_a";
    assert_script_run "mr_test verify baseline_testpattern_solution_${solution}_b";
    assert_script_run "saptune solution revert $solution";
    $self->reboot_wait;
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

    die "This test cannot be run on QEMU" if (check_var('BACKEND', 'qemu'));
    my $SLE = is_sle(">=15") ? "SLE15" : "SLE12";

    assert_script_run "mr_test verify Pattern/$SLE/testpattern_Cust#Power_1";
    # Apply all notes except 1805750
    foreach my $note (get_notes()) {
        next if ($note eq "1805750");
        assert_script_run "saptune note apply $note";
    }
    assert_script_run "mr_test verify Pattern/$SLE/testpattern_Cust#Power_2";
    assert_script_run "saptune revert all";
    assert_script_run "mr_test verify Pattern/$SLE/testpattern_Cust#Power_3";
}

sub test_x86_64 {
    my ($self) = @_;

    my $SLE;
    my $note;

    if (is_sle(">=15")) {
        $SLE  = "SLE15";
        $note = "2684254";
    } else {
        $SLE  = "SLE12";
        $note = "2205917";
    }

    # energy_perf_bias=6
    assert_script_run 'cpupower set -b 6';
    # governor=powersave
    assert_script_run 'cpupower frequency-set -g powersave';
    # force_latency=max
    assert_script_run 'cpupower idle-set -E';
    $self->reboot_wait;
    assert_script_run "mr_test verify Pattern/$SLE/testpattern_Cust#Intel_1";
    assert_script_run "saptune apply note $note";
    assert_script_run "mr_test verify Pattern/$SLE/testpattern_Cust#Intel_2";
    assert_script_run "saptune revert note $note";
    assert_script_run "mr_test verify Pattern/$SLE/testpattern_Cust#Intel_1";
    assert_script_run "echo -e '[cpu]\\nenergy_perf_bias=powersave\\ngovernor=powersave\\nforce_latency=' > /etc/saptune/override/$note";
    assert_script_run "saptune apply note $note";
    assert_script_run "mr_test verify Pattern/$SLE/testpattern_Cust#Intel_3";
    assert_script_run "saptune revert note $note";
    assert_script_run "mr_test verify Pattern/$SLE/testpattern_Cust#Intel_1";
    assert_script_run "echo -e '[cpu]\\nenergy_perf_bias=\\ngovernor=\\nforce_latency=\\n' > /etc/saptune/override/$note";
    assert_script_run "saptune apply note $note";
    assert_script_run "mr_test verify Pattern/$SLE/testpattern_Cust#Intel_4";
    assert_script_run "saptune revert note $note";
    assert_script_run "mr_test verify Pattern/$SLE/testpattern_Cust#Intel_1";
}

sub run {
    my ($self) = @_;

    $self->setup;

    my $test = quotemeta(get_required_var("MR_TEST"));
    if ($test eq "sapconf") {
        $self->test_sapconf;
    } elsif ($test eq "solutions") {
        $self->test_solutions;
    } elsif ($test eq "notes") {
        $self->test_notes;
    } elsif ($test eq "overrides") {
        $self->test_overrides;
    } elsif (grep { /^${test}$/ } get_solutions()) {
        $self->test_solution($test);
    } elsif (grep { /^${test}$/ } get_notes()) {
        # Skip 1805750 (SYB: Usage of HugePages on Linux Systems with Sybase ASE)
        # The ASE docs don't recommend any specific value or formula, so it must
        # be tested with an override file
        $self->test_note($test) if ($test ne "1805750");
        $self->test_override($test);
    } elsif ($test =~ m/^(x86_64|ppc64le)$/) {
        $self->test_x86_64     if (check_var('BACKEND', 'ipmi'));
        $self->test_ppc64le    if is_ppc64le();
        $self->test_bsc1152598 if is_sle('>12-SP3');
    } elsif ($test eq "delete_rename") {
        $self->test_delete;
        $self->test_rename;
    } else {
        die "Invalid value for MR_TEST";
    }
}

1;
