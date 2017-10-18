# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: SAP Pattern test
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "sles4sap";
use testapi;
use strict;

sub run {
    my ($self)      = @_;
    my @sappatterns = qw(sap-nw sap-b1 sap-hana);
    my $output      = '';

    select_console 'root-console';

    foreach my $pattern (@sappatterns) {
        assert_script_run("zypper in -y -t pattern $pattern", 100);
        $output = script_output "zypper info -t pattern $pattern";
        die "SAP zypper pattern [$pattern] info check failed"
          unless ($output =~ /i\+\s\|\spatterns-$pattern\s+\|\spackage\s\|\sRequired/);
    }
}

1;
# vim: set sw=4 et:
