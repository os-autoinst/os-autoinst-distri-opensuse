# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: weechat
# Summary: Test basic weechat start and stop
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils 'package_version_cmp';

sub run {
    select_console('root-console');
    zypper_call('in weechat');
    select_console('user-console');
    my $weechat_version = script_output("rpm -q --qf '%{version}' weechat");
    record_info('weechat', "Weechat version $weechat_version detected");
    my $ssl = package_version_cmp($weechat_version, '4') < 0 ? 'ssl' : 'tls';

    script_run("weechat; echo weechat-status-\$? > /dev/$serialdev", 0);
    assert_screen('weechat');

    run_weechat_command("/server add znc localhost/12345 -${ssl} -${ssl}_verify=0 -username=bernhard/freenode -password=$testapi::password");
    assert_screen('weechat-server-added');

    run_weechat_command("/connect znc");
    assert_screen('weechat-welcome_to_znc');

    run_weechat_command("/query *status");
    send_key 'ret';

    run_weechat_command("Version");
    assert_screen('weechat-znc-status-version');

    run_weechat_command("/quit");
    wait_serial("weechat-status-0") || die "'weechat' could not finish successfully";
}

sub run_weechat_command {
    type_string(shift);
    wait_still_screen 2;
    save_screenshot;
    send_key 'ret';
}

1;

