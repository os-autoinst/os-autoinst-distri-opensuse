# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
use base "virt_autotest_base";
use testapi;

sub get_script_run() {
    my $prd_version = script_output("cat /etc/issue");
    my $pre_test_cmd;
    if ($prd_version =~ m/SUSE Linux Enterprise Server 12/) {
        $pre_test_cmd = "/usr/share/qa/tools/test_virtualization-virt_install_withopt-run";
    }
    else {
        $pre_test_cmd = "/usr/share/qa/tools/test_virtualization-standalone-run";
    }

    $guest_pattern = get_var('GUEST_PATTERN', 'sles-12-sp2-64-[p|f]v-def-net');
    $parallel_num  = get_var("PARALLEL_NUM",  "2");
    $pre_test_cmd  = $pre_test_cmd . " -f " . $guest_pattern . " -n " . $parallel_num . " -r ";

    return $pre_test_cmd;
}

sub analyzeResult($) {
    my ($self, $text) = @_;
    my $result;
    $text =~ /Test in progress(.*)Test run complete/s;
    my $rough_result = $1;
    foreach (split("\n", $rough_result)) {
        if ($_ =~ /(\S+)\s+\.{3}\s+\.{3}\s+(PASSED|FAILED)\s+\((\S+)\)/g) {
            $result->{$1}{"status"} = $2;
            $result->{$1}{"time"}   = $3;
        }
    }
    return $result;
}

sub run() {
    my $self = shift;

    $self->{"product_tested_on"} = "SLES-12-SP2";
    $self->{"product_name"}      = "GuestIn_stallation";
    $self->{"package_name"}      = "Guest Installation Test";

    $self->run_test(7600, "", "yes");
}

sub test_flags {
    return {important => 1};
}

1;

