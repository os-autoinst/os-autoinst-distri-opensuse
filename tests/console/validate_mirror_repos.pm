# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validate that mirror used for installation is added as a repo in the installed system.
#
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use Test::Assert ':all';

sub run {
    select_console 'root-console';

    my $method     = uc get_required_var('INSTALL_SOURCE');
    my $mirror_src = get_required_var("MIRROR_$method");
    $mirror_src .= '?ssl_verify=no' if ($method eq 'HTTPS');

    my $output   = script_output('zypper lr --uri');
    my $sle_prod = uc get_var('SLE_PRODUCT') . get_var('VERSION');
    $output =~ /
        \d\s+\|                 # #
        \s+$sle_prod.*\s+\|     # Alias
        \s+$sle_prod.*\s+\|     # Name
        \s+Yes\s+\|             # Enabled
        \s+\(r\s+\)\s+Yes\s+\|  # GPG Check
        \s+Yes\s+\|             # Refresh
        \s+(?<uri>.*)           # URI
    /x;
    assert_equals($mirror_src, $+{uri},
        "Repository on the installed system does not match mirror for installation");
}

1;
