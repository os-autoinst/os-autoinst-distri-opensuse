# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that mirror used for installation is added as a repo in the installed system.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use repo_tools 'validate_repo_properties';
use registration 'scc_version';

sub run {
    select_console 'root-console';

    my $method = uc get_required_var('INSTALL_SOURCE');
    my $mirror_src = get_required_var("MIRROR_$method");
    $mirror_src .= '\?ssl_verify=no' if ($method eq 'HTTPS');
    my $sle_prod = uc get_var('SLE_PRODUCT') . get_var('VERSION');
    my $name = $sle_prod . '-' . scc_version() . '-0';

    record_info("Mirror Validation", "Validate $mirror_src used for installation is added in the installed system");
    validate_repo_properties({
            Filter => $name,
            Alias => $sle_prod,
            Name => $sle_prod,
            URI => $mirror_src,
            Enabled => 'Yes',
            Autorefresh => 'On'
    });
}

1;
