# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";
use testapi;

sub run() {

    my $svirt = console('svirt');

    $svirt->change_domain_element(os => initrd  => undef);
    $svirt->change_domain_element(os => kernel  => undef);
    $svirt->change_domain_element(os => cmdline => undef);

    $svirt->change_domain_element(on_reboot => undef);

    $svirt->define_and_start;
}

1;
