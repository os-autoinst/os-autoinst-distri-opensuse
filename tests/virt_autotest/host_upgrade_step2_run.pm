# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# Maintainer: alice <xlai@suse.com>

use base "host_upgrade_base";
#use virt_utils qw(set_serialdev);
use testapi;
use strict;
use warnings;
use virt_utils;

sub get_script_run {
    my $self = shift;

    my $pre_test_cmd = $self->get_test_name_prefix;
    $pre_test_cmd .= "-run 02";

    return "rm /var/log/qa/old* /var/log/qa/ctcs2/* -r;" . "$pre_test_cmd";
}

sub run {
    my $self = shift;
    $self->run_test(12600, "Host upgrade to .* is done. Need to reboot system|Executing host upgrade to .* offline",
        "no", "yes", "/var/log/qa/", "host-upgrade-prepAndUpgrade");

    #replace module url with openqa daily build modules link
    my $installed_product = get_var('VERSION_TO_INSTALL', get_var('VERSION', ''));
    my ($installed_release) = $installed_product =~ /^(\d+)/;
    my $upgrade_product     = get_required_var('UPGRADE_PRODUCT');
    my ($upgrade_release)   = lc($upgrade_product) =~ /sles-([0-9]+)-sp/;
    if (($upgrade_release >= 15) && ($installed_release ne $upgrade_release)) {
        upload_logs('/root/autoupg.xml');
    }
}

1;
