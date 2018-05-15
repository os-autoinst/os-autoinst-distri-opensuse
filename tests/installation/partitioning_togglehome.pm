# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test/execute the toggling of a separate home partition
# Maintainer: Stephan Kulow <coolo@suse.de>

use strict;
use base "y2logsstep";
use testapi;
use installation_user_settings;
use version_utils qw(is_storage_ng is_leap);
use partition_setup 'unselect_xen_pv_cdrom';

sub run {
    record_soft_failure 'boo#1093372' if (!get_var('TOGGLEHOME') && is_leap('15.1+'));
    wait_screen_change { send_key($cmd{guidedsetup}) };    # open proposal settings
    if (is_storage_ng) {
        unselect_xen_pv_cdrom;
        assert_screen 'partition-scheme';
        send_key $cmd{next};
        installation_user_settings::await_password_check if get_var('ENCRYPT');
    }
    # For s390x there was no offering of separated home partition until SLE 15 See bsc#1072869
    if (!check_var('ARCH', 's390x') or is_storage_ng()) {
        if (!check_screen 'disabledhome', 0) {
            # toggle_home hotkey can change
            if (check_screen('inst-partition-radio-buttons', 0)) {
                $cmd{toggle_home} = 'alt-r';
            }
            elsif (check_screen('proposed-separated-swap', 0)) {
                $cmd{toggle_home} = 'alt-o';
            }
            send_key $cmd{toggle_home};
        }
        assert_screen 'disabledhome';
    }
    send_key(is_storage_ng() ? 'alt-n' : 'alt-o');    # finish editing settings
    save_screenshot;
}

1;
