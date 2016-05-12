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
use lib "/var/lib/openqa/share/tests/sle-12-SP2/tests/virt_autotest/Prj2_Host_Upgrade/";
use base "host_upgrade_base";

use testapi;

#sub execute_script_run($$) {
#    my ($self, $cmd, $timeout) = @_;
#
#    my $ret = $self->local_string_output($cmd, $timeout);
#
#    if ($ret == 1 ) {
#        die "Timeout due to cmd run :[" . $cmd . "]\n";
#    }
#    return $ret
#
#}

sub get_scrip_run() {
	my $self = shift;
	my $pre_test_cmd;

	my $mode = get_var("TEST_MODE", "");
	my $hypervisor = get_var("HOST_HYPERVISOR", "");
	my $base = get_var("BASE_PRODUCT", ""); #EXAMPLE, sles-11-sp3
	my $upgrade = get_var("UPGRADE_PRODUCT", ""); #EXAMPLE, sles-12-sp2
	my $upgrade_repo = get_var("UPGRADE_REPO", "");
	my $guest_list = get_var("GUEST_LIST", "");

	$pre_test_cmd = "/usr/share/qa/tools/_generate_vh-update_tests.sh";
	$pre_test_cmd .= " -m $mode";
	$pre_test_cmd .= " -v $hypervisor";
	$pre_test_cmd .= " -b $base";
	$pre_test_cmd .= " -u $upgrade";
	$pre_test_cmd .= " -r $upgrade_repo";
	$pre_test_cmd .= " -i $guest_list";

	return "$pre_test_cmd";
}

sub run() { 
	my $self = shift;
	# Got script run according to different kind of system
	my $pre_test_cmd = $self->get_scrip_run();

	# Execute script run
	my $ret = $self->execute_script_run($pre_test_cmd, 180);
	save_screenshot;
	if ( $ret !~ /Generated test run file/ ) {
		die "Generate test files failed!";
	}

	# Debug 
	print "command to execute is: $ret.";
	return 999;
	# Parse test result and generate junit file
#	my $tc_result = $self->analyzeResult($ret);
#	my $xml_result = $self->generateXML($tc_result);
#
#	# Upload and parse junit file.
#	$self->push_junit_log($xml_result);

}

1;

