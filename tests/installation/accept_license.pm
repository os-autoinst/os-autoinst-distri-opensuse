# Copyright 2017-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test module is used to accept license during SLE 15 installation
# Should be improved to be more product specific.
# - Check for license-agreement
# - If INSTALLER_EXTENDED_TEST is set
#   - Check if after just pressing next, there's a warning about license not
#   being accepted
#   - Unless sles is 15+, set language to English US
# - Press next
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use y2_logs_helper qw(verify_license_has_to_be_accepted verify_license_translations accept_license);
use testapi;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    assert_screen('license-agreement', 120);
    # optional checks for the extended installation
    if (get_var('INSTALLER_EXTENDED_TEST')) {
        $self->verify_license_has_to_be_accepted;
        $self->verify_license_translations;
    }
    $self->accept_license;
    send_key $cmd{next};
}

1;
