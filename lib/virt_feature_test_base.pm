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
use testapi;
use utils;
use virt_utils;
use xen;

sub run_test {
    die('Please override this subroutine in children modules to run desired tests.');
}

sub run {
    my ($self) = @_;
    $self->{"start_run"} = time();
    $self->run_test;
    $self->{"stop_run"} = time();
    #(caller(0))[3] can help pass calling subroutine name into called subroutine
    $self->junit_log_provision((caller(0))[3]) if get_var("VIRT_AUTOTEST");
}

sub junit_log_provision {
    my ($self, $runsub) = @_;
    my $status    = eval { $runsub =~ /post_fail_hook/img ? 'FAILED' : 'PASSED' };
    my $tc_result = $self->analyzeResult($status);
    $self->junit_log_params_provision($tc_result);
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
    my $xml_result = generateXML_from_data($tc_result, \%stats);
    script_run "echo \'$xml_result\' > /tmp/output.xml";
    save_screenshot;
    parse_junit_log("/tmp/output.xml");
}

sub junit_log_params_provision {
    my ($self, $data) = @_;
    my %my_hash   = %$data;
    my $pass_nums = 0;
    my $fail_nums = 0;
    my $skip_nums = 0;
    $self->{"product_tested_on"} = script_output("cat /etc/issue | grep -io \"SUSE.*\$(arch))\"");
    $self->{"product_name"}      = ref($self);
    $self->{"package_name"}      = ref($self);

    foreach my $item (keys(%my_hash)) {
        if ($my_hash{$item}->{status} =~ m/PASSED/) {
            $pass_nums += 1;
            push @{$self->{success_guest_list}}, $item;
        }
        elsif ($my_hash{$item}->{status} =~ m/SKIPPED/ && $item =~ m/iso/) {
            $skip_nums += 1;
        }
        else {
            $fail_nums += 1;
        }
    }
    $self->{"pass_nums"} = $pass_nums;
    $self->{"skip_nums"} = $skip_nums;
    $self->{"fail_nums"} = $fail_nums;

    diag '@{$self->{success_guest_list}} content is: ' . Dumper(@{$self->{success_guest_list}});
}

sub analyzeResult {
    my ($self, $test_status) = @_;
    my $result;
    my $start_time = $self->{"start_run"};
    my $stop_time  = $self->{"stop_run"};
    foreach (keys %xen::guests) {
        $result->{$_}{status} = $test_status;
        $result->{$_}{time}   = strftime("\%H:\%M:\%S", gmtime($stop_time - $start_time));
    }
    delete $self->{"start_run"};
    delete $self->{"stop_run"};
    return $result;
}

sub post_fail_hook {
    my ($self) = shift;
    $self->{"stop_run"} = time();
    $self->SUPER::post_fail_hook;
    #(caller(0))[3] can help pass calling subroutine name into called subroutine
    $self->junit_log_provision((caller(0))[3]) if get_var("VIRT_AUTOTEST");
}

1;
