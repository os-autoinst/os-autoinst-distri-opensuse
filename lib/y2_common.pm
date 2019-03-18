# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: This module provides common subroutines for YaST2 modules in graphical and text mode
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

package y2_common;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use version_utils qw(is_opensuse is_leap);

our @EXPORT = qw(is_network_manager_default
  continue_info_network_manager_default
  accept_warning_network_manager_default
);

=head2 is_network_manager_default
openSUSE has network manager as default except for older leap versions
=cut
sub is_network_manager_default {
    return is_opensuse unless is_leap('<=15.0');
}

=head2 continue_info_network_manager_default
Click on Continue when appears info indicating that network interfaces are controlled by Network Manager
=cut
sub continue_info_network_manager_default {
    if (is_network_manager_default) {
        assert_screen 'yast2-lan-warning-network-manager';
        send_key $cmd{continue};
    }
}

=head2 accept_warning_network_manager_default
Click on OK when appears a warning indicating that network interfaces are controlled by Network Manager
=cut
sub accept_warning_network_manager_default {
    if (is_network_manager_default) {
        $cmd{overview_tab} = 'alt-v';
        assert_screen 'yast2-lan-warning-network-manager';
        send_key $cmd{ok};
        assert_screen 'yast2_lan-global-tab';
        send_key $cmd{overview_tab};
    }
}

1;
