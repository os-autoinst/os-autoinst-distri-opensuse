# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Boot from existing image to desktop
# Maintainer: mitiao <mitiao@gmail.com>

use base 'bootbasetest';
use strict;
use warnings;
use testapi;
use version_utils qw(is_upgrade is_sles4sap);

sub run {
    my ($self) = @_;
    $self->{in_boot_desktop} = 1;
    # In some cases default wait for boot should be increased due to different reasons.
    # currently we awere about such reasons :
    # - tests which boot from HDD and wait for boot menu's timeout ( UEFI DVD)
    # - reboot from pre-migration system
    # - skipping GRUB menu detection for unknown reason slowdown boot process
    my $timeout = get_var('UEFI') || get_var('KEEP_GRUB_TIMEOUT') || get_var('PATCH') || get_var('ONLINE_MIGRATION') ? 140 : 80;
    # Do not attempt to log into the desktop of a system installed with SLES4SAP
    # being prepared for upgrade, as it does not have an unprivileged user to test
    # with other than the SAP Administrator
    my $nologin = (get_var('HDDVERSION') and is_upgrade() and is_sles4sap());
    if (check_var('VIRSH_VMM_TYPE', 'linux')) {
        wait_serial('Welcome to SUSE Linux', $timeout) || die "System did not boot in $timeout seconds.";
    }
    else {
        $self->wait_boot(bootloader_time => $timeout, nologin => $nologin);
    }
}

sub test_flags {
    # add milestone flag to save setup in lastgood VM snapshot
    return {fatal => 1, milestone => 1};
}

1;
