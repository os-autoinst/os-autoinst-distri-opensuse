# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: s390x disk activation test
# Maintainer: Matthias Griessmeier <mgriessmeier@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use version_utils 'is_sle';

sub format_dasd {
    while (check_screen 'process-dasd-format', 30) {
        diag("formatting DASD ...");
        sleep 20;
    }
}

sub add_zfcp_disk {
    my $channel = shift;
    assert_screen 'zfcp-disk-management';
    send_key 'alt-a';
    assert_screen 'zfcp-add-device';
    send_key 'alt-a';
    assert_screen 'zfcp-channel-select';
    for (1 .. 9) { send_key "backspace"; }
    type_string "$channel";
    assert_screen "zfcp-channel-$channel-selected";
    send_key $cmd{next};
    assert_screen 'zfcp-disk-management';
}

sub run {
    # use zfcp as install disk
    if (check_var('S390_DISK', 'ZFCP')) {
        assert_screen 'disk-activation-zfcp';
        wait_screen_change { send_key 'alt-z' };
        add_zfcp_disk('0.0.fa00');
        add_zfcp_disk('0.0.fc00');
        assert_screen 'zfcp-activated';
        send_key $cmd{next};
        wait_still_screen 5;
    }
    else {
        # use default DASD as install disk
        assert_screen 'disk-activation', 15;
        wait_screen_change { send_key 'alt-d' };

        assert_screen 'dasd-disk-management';

        # we need to type backspace to delete the content of the input field in textmode
        if (check_var("VIDEOMODE", "text")) {
            send_key 'alt-m';    # minimum channel ID
            for (1 .. 9) { send_key "backspace"; }
            type_string '0.0.0150';
            send_key 'alt-x';    # maximum channel ID
            for (1 .. 9) { send_key "backspace"; }
            type_string '0.0.0150';
            send_key 'alt-f';    # filter button
            assert_screen 'dasd-unselected';
            send_key 'alt-s';    # select all
            assert_screen 'dasd-selected';
            send_key 'alt-a';    # perform action button
            assert_screen 'action-list';
            send_key 'alt-a';    # activate
        }
        else {
            send_key 'alt-m';    # minimum channel ID
            type_string '0.0.0150';
            send_key 'alt-x';    # maximum channel ID
            type_string '0.0.0150';
            send_key 'alt-f';    # filter button
            assert_screen 'dasd-unselected';
            send_key 'alt-s';    # select all
            assert_screen 'dasd-selected';
            send_key 'alt-a';    # perform action button
            assert_screen 'action-list';
            send_key 'a';        # activate
        }

        # sometimes it happens, that the DASD is in a unstable state, so
        # if the systems wants to format the DASD by itself, do it.
        if (check_screen 'dasd-format-device', 10) {    # format device pop-up
            send_key 'alt-o';                           # continue
            format_dasd;
        }

        # format DASD if the variable is that, because we format it as pre-installation step by default
        elsif (check_var('FORMAT_DASD', 'install')) {
            send_key 'alt-s';                           # select all
            assert_screen 'dasd-selected';
            send_key 'alt-a';                           # perform action button
            if (check_screen 'dasd-device-formatted', 30) {
                assert_screen 'action-list';
                # shortcut changed for sle 15
                send_key 'o';
                assert_screen 'confirm-dasd-format';    # confirmation popup
                send_key 'alt-y';
                format_dasd;
            }
        }
        assert_screen 'dasd-active';
        send_key $cmd{next};
    }
    assert_screen 'disk-activation', 15;
    send_key $cmd{next};
}

1;
