# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This test verifies whether on host installed with specific product, the guests can successfully upgrade to the target upgrade product.
#          It is provides as part of the test for fate https://fate.suse.com/320424.
#          The other part of the fate test is already added as prj2_host_upgrade test.
#
# Maintainer: xlai@suse.com

use strict;
use warnings;
use base "virt_autotest_base";
use testapi;

sub get_script_run {
    my $pre_test_cmd         = "/usr/share/qa/tools/test_virtualization-guest-upgrade-run";
    my $product_upgrade      = get_var("PRODUCT_UPGRADE", "sles-12-sp2-64");
    my $product_upgrade_repo = get_var("PRODUCT_UPGRADE_REPO", "");
    my $guest_list           = get_var("GUEST_LIST", "sles-12-sp1-64");
    my $max_test_time        = get_var("MAX_TEST_TIME", "36000");

    $pre_test_cmd = "$pre_test_cmd -p $product_upgrade -r $product_upgrade_repo -t $max_test_time -g \"$guest_list\"";

    return $pre_test_cmd;
}

sub run {
    my $self = shift;
    my $timeout = get_var("MAX_TEST_TIME", "36000") + 10;
    script_run("echo \"Debug info: max_test_time is $timeout\"");
    $self->run_test($timeout, "Test run completed successfully", "no", "yes", "/var/log/qa/ctcs2/", "guest-upgrade-logs");
}

sub test_flags {
    return {important => 1};
}

1;

