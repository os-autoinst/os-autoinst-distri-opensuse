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
use version_utils qw(is_storage_ng is_leap is_sle);

sub run {
    record_soft_failure 'boo#1093372' if (!get_var('TOGGLEHOME') && is_leap('15.1+'));
    send_key $cmd{guidedsetup};
    if (is_storage_ng) {
        assert_screen [qw(existing-partitions partition-scheme)];
        if (match_has_tag 'existing-partitions') {
            send_key $cmd{next};
            assert_screen 'partition-scheme';
        }
        send_key $cmd{next};
        installation_user_settings::await_password_check if get_var('ENCRYPT');
    }
    assert_screen [qw(inst-partition-radio-buttons enabledhome disabledhome)];
    # For s390x there was no offering of separated home partition until SLE 15 See bsc#1072869
    if ((!check_var('ARCH', 's390x') or is_storage_ng()) and !match_has_tag('disabledhome')) {
        # older versions have radio buttons and no separate swap block
        if (match_has_tag 'inst-partition-radio-buttons') {
            $cmd{toggle_home} = 'alt-r';
        }    # Have different shortkey on storage-ng without LVM
        elsif (is_storage_ng && !get_var('LVM')) {
            $cmd{toggle_home} = 'alt-o';
        }
        send_key $cmd{toggle_home};
        assert_screen 'disabledhome';
    }
    send_key(is_storage_ng() ? 'alt-n' : 'alt-o');    # finish editing settings
    assert_screen 'partitioning-edit-proposal-button';
}

1;
