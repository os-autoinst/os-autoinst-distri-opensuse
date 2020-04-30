# VIRSH TEST MODULE BASE PACKAGE
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: This is the base package for virsh test modules, for example,
# tests/virtualization/xen/hotplugging.pm
# tests/virt_autotest/virsh_internal_snapshot.pm
# tests/virt_autotest/virsh_external_snapshot.pm
# and etc.
#
# The elements that author of newly developed feature test can customize
# are:
# 1. $self->{test_results}->{$guest}->{CUSTOMIZED_TEST1}->{status} which can
# be given 'SKIPPED', 'FAILED', 'PASSED', 'SOFTFAILED', 'TIMEOUT' or 'UNKNOWN'.
# 2. $self->{test_results}->{$guest}->{CUSTOMIZED_TEST1}->{test_time} which
# should be given time cost duration in format like 'XXmYYs'.
# 3. $self->{test_results}->{$guest}->{CUSTOMIZED_TEST1}->{error} which can
# be given any customized error message that is suitable to be placed in
# system-err section.
# 4. $self->{test_results}->{$guest}->{CUSTOMIZED_TEST1}->{output} which can
# be given any customized output message that is suitable to be placed in
# system-out section.
# Maintainer: Wayne Chen <wchen@suse.com>

package virt_feature_test_base;

use base "consoletest";
use strict;
use warnings;
use POSIX 'strftime';
use File::Basename;
use Data::Dumper;
use XML::Writer;
use IO::File;
use List::Util 'first';
use testapi;
use utils;
use virt_utils;
use xen;

sub run_test {
    die('Please override this subroutine in children modules to run desired tests.');
}

sub run {
    my ($self) = @_;
    script_run("rm -f /root/{commands_history,commands_failure}");
    assert_script_run("history -c");
    $self->{"start_run"} = time();
    $self->run_test;
    $self->{"stop_run"} = time();
    #(caller(0))[3] can help pass calling subroutine name into called subroutine
    $self->junit_log_provision((caller(0))[3]) if get_var("VIRT_AUTOTEST");
}

sub junit_log_provision {
    my ($self, $runsub) = @_;
    my $overall_status = eval { $runsub =~ /post_fail_hook/img ? 'FAILED' : 'PASSED' };
    $self->analyzeResult($overall_status);
    $self->junit_log_params_provision;
    ###Load instance attributes into %stats
    my %stats;
    foreach (keys %{$self}) {
        if (defined($self->{$_})) {
            if (ref($self->{$_}) eq 'HASH') {
                %{$stats{$_}} = %{$self->{$_}};
            }
            elsif (ref($self->{$_}) eq 'ARRAY') {
                @{$stats{$_}} = @{$self->{$_}};
            }
            else {
                $stats{$_} = $self->{$_};
            }
        }
        else {
            next;
        }
    }
    print "The data to be used for xml generation:", Dumper(\%stats);
    my %tc_result  = %{$stats{test_results}};
    my $xml_result = generateXML_from_data(\%tc_result, \%stats);
    script_run "echo \'$xml_result\' > /tmp/output.xml";
    save_screenshot;
    parse_junit_log("/tmp/output.xml");
}

sub junit_log_params_provision {
    my $self = shift;

    my $start_time = $self->{"start_run"};
    my $stop_time  = $self->{"stop_run"};
    $self->{"test_time"}         = strftime("\%H:\%M:\%S", gmtime($stop_time - $start_time));
    $self->{"product_tested_on"} = script_output("cat /etc/issue | grep -io \"SUSE.*\$(arch))\"");
    $self->{"product_name"}      = ref($self);
    $self->{"package_name"}      = ref($self);
}

sub analyzeResult {
    my ($self, $status) = @_;

    #Initialize all test status counters to zero
    #Then count up all counters by the number of tests in corresponding status
    my @test_item_status_array = ('pass', 'fail', 'skip', 'softfail', 'timeout', 'unknown');
    $self->{$_ . '_nums'} = 0 foreach (@test_item_status_array);
    foreach my $guest (keys %xen::guests) {
        foreach my $item (keys %{$self->{test_results}->{$guest}}) {
            my $item_status      = $self->{test_results}->{$guest}->{$item}->{status};
            my $test_item_status = first { $item_status =~ /^$_/i } @test_item_status_array;
            $self->{$test_item_status . '_nums'} += 1;
        }
    }

    #If test failed at undefined checkpoint, it still needs to be counted in to maintain
    #the correctness and effectivenees of entire JUnit log
    if ($status eq 'FAILED' && $self->{"fail_nums"} eq '0') {
        $self->{"fail_nums"} = '1';
        my $uncheckpoint_failure       = script_output("cat /root/commands_history | tail -3 | head -1");
        my @involved_failure_guest     = grep { $uncheckpoint_failure =~ /$_/img } (keys %xen::guests);
        my $uncheckpoint_failure_guest = "";
        if (!scalar @involved_failure_guest) {
            $uncheckpoint_failure_guest = "NO SPECIFIC TEST GUEST INVOLVED";
        }
        else {
            $uncheckpoint_failure_guest = join(' ', @involved_failure_guest);
        }
        diag "The accidental failure happended at: $uncheckpoint_failure involves: $uncheckpoint_failure_guest";
        script_run("($uncheckpoint_failure) 2>&1 | tee -a /root/commands_failure", quiet => 1);
        my $uncheckpoint_failure_error = script_output("cat /root/commands_failure", type_command => 0, proceed_on_failure => 1, quiet => 1);
        $self->{test_results}->{$uncheckpoint_failure_guest}->{$uncheckpoint_failure}->{status} = 'FAILED';
        $self->{test_results}->{$uncheckpoint_failure_guest}->{$uncheckpoint_failure}->{error}  = $uncheckpoint_failure_error;
    }
}

sub post_fail_hook {
    my ($self) = shift;
    $self->{"stop_run"} = time();
    assert_script_run("history -w /root/commands_history");
    #(caller(0))[3] can help pass calling subroutine name into called subroutine
    $self->junit_log_provision((caller(0))[3]) if get_var("VIRT_AUTOTEST");
    virt_utils::upload_supportconfig_log;
    #(caller(0))[0] can help pass calling package name into called subroutine
    virt_utils::upload_virt_logs("/var/log/libvirt", (caller(0))[0] . "-libvirt-logs");
    $self->SUPER::post_fail_hook;
}

1;
