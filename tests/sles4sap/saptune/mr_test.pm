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
use power_action_utils 'power_action';
use version_utils 'is_sle';
use strict;
use warnings;

sub setup {
    my ($self) = @_;

    my $tarball = get_var('MR_TEST_TARBALL', 'https://gitlab.suse.de/rbranco/mr_test/-/archive/master/mr_test-master.tar.gz');

    select_console 'root-console';
    # Disable packagekit
    pkcon_quit;
    # saptune is not installed by default on SLES4SAP 12 on ppc64le
    zypper_call "-n in saptune" if (get_var('OFW') and is_sle('<15'));
    # Install mr_test dependencies
    zypper_call "-n in python3-rpm";
    # Download mr_test and extract it to $HOME
    assert_script_run "curl -sk $tarball | tar zxf - --strip-components 1";
    # Add $HOME to $PATH
    assert_script_run "echo 'export PATH=\$PATH:\$HOME' >> /root/.bashrc";
    # Remove any configuration set by sapconf
    assert_script_run "sed -i.bak '/^@/,\$d' /etc/security/limits.conf";
    assert_script_run 'mv /etc/systemd/logind.conf.d/sap.conf{,.bak}';
    assert_script_run 'saptune daemon start';
    if (check_var('BACKEND', 'qemu')) {
        # Ignore disk_elevator on VM's
        assert_script_run "sed -ri '/:scripts\\/disk_elevator/s/^/#/' \$(fgrep -rl :scripts/disk_elevator Pattern/)";
    }
    $self->reboot;
}

sub reboot {
    my ($self) = @_;

    power_action('reboot');
    $self->wait_boot;
    select_console 'root-console';
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

sub test_sapconf {
    my ($self) = @_;

    my $SLE = is_sle(">=15") ? "SLE15" : "SLE12";

    # Scenario 1: sapconf is running and active with sap-netweaver profile.
    # The test shall show, that a running tuned profile or sapconf is not compromised.
    assert_script_run 'cp /etc/systemd/logind.conf.d/sap.conf{.bak,}';
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
    $self->reboot;
    assert_script_run "mr_test verify Pattern/${SLE}/testpattern_note_${note}${extra}_a";
    assert_script_run "mr_test verify baseline_testpattern_note_${note}${extra}_b";
    assert_script_run "saptune note revert $note";
    $self->reboot;
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
        $self->reboot;
        assert_script_run "mr_test verify Pattern/$SLE/testpattern_note_${override}_a_override";
        assert_script_run "mr_test verify baseline_testpattern_note_${override}_b";
        assert_script_run "saptune note revert $note";
        assert_script_run "rm -f /etc/saptune/override/$note";
        $self->reboot;
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
    $self->reboot;
    assert_script_run "mr_test verify Pattern/${SLE}/testpattern_solution_${solution}_a";
    assert_script_run "mr_test verify baseline_testpattern_solution_${solution}_b";
    assert_script_run "saptune solution revert $solution";
    $self->reboot;
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
    $self->reboot;
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

    my $test = get_required_var("MR_TEST");
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
        $self->test_x86_64 if (check_var('BACKEND', 'ipmi'));
        $self->test_ppc64le if (get_var('OFW'));
    } else {
        die "Invalid value for MR_TEST";
    }
}

1;
