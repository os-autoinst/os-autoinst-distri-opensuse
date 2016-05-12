# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
use lib "/var/lib/openqa/share/tests/sle-12-SP2/tests/virt_autotest/lib";
use base "teststepapi";

use testapi;

our $PRODUCT_TESTED_ON = "SLES-12-SP2";
our $PROJECT_NAME = "GuestIn_stallation";


sub get_guest_pattern() {
    my $self = shift;
    my $guest_pattern = get_var("GUEST_PATTERN", "");
    if ( $guest_pattern eq "") {
        #$guest_pattern = "sles-11-sp[34]|sles-12";
        $guest_pattern = "sles-12-sp1";
    }
    return $guest_pattern
}

sub get_parallel_num() {
    my $self = shift;
    my $parallel_num = get_var("PARALLEL_NUM", "");
    if ( $parallel_num eq "") {
        $parallel_num = "3";
    }

    return $parallel_num;
}


sub run() { 
	my $self = shift;
	# Got script run according to different kind of system
	my $pre_test_cmd = $self->get_scrip_run();

	# Execute script run
	my $ret = $self->execute_script_run($pre_test_cmd, 3600);

	# Parse test result and generate junit file
	my $tc_result = $self->analyzeResult($ret);
	my $xml_result = $self->generateXML($tc_result);

	# Upload and parse junit file.
	$self->push_junit_log($xml_result);

}

sub test_flags {
    return {important => 1};
}

1;

