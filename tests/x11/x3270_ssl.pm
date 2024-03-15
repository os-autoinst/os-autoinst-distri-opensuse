# SUSE's openQA tests
#
# Copyright 2012-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: x3270 for SSL support testing, with openssl s_server running on local system
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#65570, poo#65615, poo#89005, poo#106504, poo#109566

use base "x11test";
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use utils;
use power_action_utils 'power_action';

sub run {

    my ($self) = @_;

    # Reboot the system when x11 launch fail to Workaround the Switch Console error
    # (s390x limitation) s390x does not support snapshot to rollback the lastgood snapshot
    # This workaround can avoid the blocked test fail from the last case
    if (is_s390x && check_var('FIPS_ENABLED', 1) && !get_var("FIPS_ENV_MODE")) {
        power_action('reboot', textmode => 1);
        $self->wait_boot(bootloader_time => 200);
    }

    select_console 'root-console';

    # On s390x platform, make sure that non-root user has
    # permissions for $serialdev to get openQA work properly.
    ensure_serialdev_permissions if (is_s390x);

    my $cert_file = '/tmp/server.cert';
    my $key_file = '/tmp/server.key';
    my $tracelog_file = '/tmp/x3270-trace.log';

    zypper_call "install x3270";

    # x3270 3.6ga version has been submitted to >=15-sp1
    zypper_call('info x3270');

    assert_script_run qq(openssl req -new -x509 -newkey rsa:2048 -keyout $key_file -days 3560 -out $cert_file -nodes -subj "/C=CN/ST=BJ/L=BJ/O=SUSE/OU=QA/CN=suse/emailAddress=test\@suse.com");

    #Workaround for avoiding missing charactors in following commands
    for (1 ... 3) {
        send_key "ret";
    }

    enter_cmd "openssl s_server -accept 8443 -cert $cert_file -key $key_file 2>&1 | tee /dev/$serialdev";
    wait_serial "ACCEPT", 10 || die "openssl s_server output doesn't match";

    select_console 'x11';

    x11_start_program('xterm');
    mouse_hide(1);

    # Run x3270 as background since backend code adjust warning policy
    # It introduces run error if the command is not quit
    background_script_run("x3270 -trace -noverifycert -tracefile $tracelog_file L:localhost:8443");
    wait_still_screen;

    # Exit and back to generic desktop
    send_key "ctrl-c";
    send_key "alt-tab";
    send_key "ctrl-c";
    assert_screen 'x3270_ssl_desktop';

    # Terminate openssl s_server
    select_console 'root-console';
    send_key "ctrl-c";
    clear_console;

    record_info("SSL Trace", "x3270-trace.log contains passed SSL negotiation data");
    enter_cmd "cat $tracelog_file | tee /dev/$serialdev";

    assert_script_run("grep -E 'Cipher:\\s+TLS_AES_256_GCM_SHA384' /tmp/x3270-trace.log");
    assert_script_run("grep -E 'SSL_connect trace:\\s+SSLOK\\s+SSL\\s+negotiation\\s+finished\\s+successfully' /tmp/x3270-trace.log");

    script_run "rm -f $tracelog_file $cert_file $key_file";
    script_run 'pkill -9 x3270';
    enter_cmd 'killall xterm';

    select_console 'x11';
}

sub test_flags {
    return {always_rollback => 1};
}

1;
