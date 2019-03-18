# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: rasdaemon may have to be tested on a physical system, as EDAC support
#may not be available in a VM. To check this, install rasdaemon:
# zypper in rasdaemon and run
# ras-mc-ctl --status.
#If the message returned indicates that there is no EDAC driver loaded, the system  does
# not support it thus not all tests below can be performed
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
# Tags: https://fate.suse.com/318824

use base 'hpcbase';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;

    zypper_call('in rasdaemon');

    assert_script_run('! ras-mc-ctl --status');
    systemctl 'start rasdaemon';
    my $mainboard_output = script_output('ras-mc-ctl --mainboard');
    # Validating output of "ras-mc-ctl --mainboard"
    die 'Not expected mainboard - ' . $mainboard_output unless $mainboard_output =~ /mainboard/;
    my $summary_output = script_output('ras-mc-ctl --summary');
    # Validating output of 'ras-mc-ctl --summary'
    die 'Not expected summary - ' . $summary_output
      unless $summary_output =~ /No Memory errors/ && $summary_output =~ /No PCIe AER errors/ && $summary_output =~ /No MCE errors/;
    my $error_output = script_output('ras-mc-ctl --errors');
    # Validating output of 'ras-mc-ctl --errors'
    die 'Not expected error - ' . $error_output
      unless $error_output =~ /No Memory errors/ && $error_output =~ /No PCIe AER errors/ && $error_output =~ /No MCE errors/;
}

1;
