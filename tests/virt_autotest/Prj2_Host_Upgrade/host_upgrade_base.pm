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
package host_upgrade_base;
use strict;
use warnings;
use lib "/var/lib/openqa/share/tests/sle-12-SP2/tests/virt_autotest/lib";
use base "teststepapi";
use testapi;

our $PRODUCT_TESTED_ON = "SLES-12-SP2";
our $PROJECT_NAME = "Host_Upgrade";

sub execute_script_run($$) {
    my ($self, $cmd, $timeout) = @_;

    my $ret = $self->local_string_output($cmd, $timeout);

    if ($ret == 1 ) {
        die "Timeout due to cmd run :[" . $cmd . "]\n";
    }
    return $ret;

}

sub get_test_name_prefix() {
	my $self = shift;
	my $test_name_prefix = "";

	my $mode = get_var("TEST_MODE", "");
	my $hypervisor = get_var("HOST_HYPERVISOR", "");
	my $base = get_var("BASE_PRODUCT", ""); #EXAMPLE, sles-11-sp3
	my $upgrade = get_var("UPGRADE_PRODUCT", ""); #EXAMPLE, sles-12-sp2

	$base =~ s/-//g;
	$upgrade =~ s/-//g;

	$test_name_prefix = "/usr/share/qa/tools/test-VH-Upgrade-$mode-$hypervisor-$base-$upgrade";

	return "$test_name_prefix";
}

1;

