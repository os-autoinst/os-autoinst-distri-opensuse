# SUSE's openQA tests
#
# Copyright 2012-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Testopia Case#1595207 - FIPS: x3270
# Package: x3270 openssl
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

    # Install x3270
    zypper_call "install x3270";

    # SLE-16633: [post GA] Update x3270 package for SLES 15 SP1 to support noverifycert option
    # Check x3270 version
    # x3270 3.6ga version has been submitted to SLE15 SP1, SP2, and SP3
    zypper_call('info x3270');
    my $current_ver = script_output("rpm -q --qf '%{version}\n' x3270");
    record_info("x3270_ver", "Current x3270 package version: $current_ver");

    #Generate self-signed x509 certificate
    type_string
"openssl req -new -x509 -newkey rsa:2048 -keyout $key_file -days 3560 -out $cert_file -nodes -subj \"/C=CN/ST=BJ/L=BJ/O=SUSE/OU=QA/CN=suse/emailAddress=test\@suse.com\" 2>&1 | tee /dev/$serialdev\n";

    wait_serial "writing new private", 60 || die "openssl req output doesn't match";

    #Workaround for avoiding missing charactors in following commands
    for (1 ... 3) {
        send_key "ret";
    }

    #Setup openssl s_server
    enter_cmd "openssl s_server -accept 8443 -cert $cert_file -key $key_file 2>&1 | tee /dev/$serialdev";

    wait_serial "ACCEPT", 10 || die "openssl s_server output doesn't match";

    select_console 'x11';

    x11_start_program('xterm');
    mouse_hide(1);

    # Launch x3270
    # Add noverifycert option if x3270 is or greater than v3.6ga
    my $noverifycert = ($current_ver < 3.6 ? '' : '-noverifycert');

    # Run x3270 as background since backend code adjust warning policy
    # It introduces run error if the command is not quit
    background_script_run("x3270 -trace $noverifycert -tracefile $tracelog_file L:localhost:8443");

    assert_screen 'x3270_fips_launched_with_TLS_SSL';

    # Exit and back to generic desktop
    send_key "ctrl-c";
    send_key "alt-tab";
    send_key "ctrl-c";
    assert_screen 'x3270_ssl_desktop';

    # Terminate openssl s_server
    select_console 'root-console';
    send_key "ctrl-c";
    clear_console;

    enter_cmd "cat $tracelog_file | tee /dev/$serialdev";

    if ($current_ver >= 3.6) {
        wait_serial "SSL_connect trace: SSLOK  SSL negotiation finished successfully", 5 || die "x3270 output doesn't match";
    }
    else {
        wait_serial "TLS/SSL tunneled connection complete", 5 || die "x3270 output doesn't match";
    }

    # Clean up
    script_run "rm -f $tracelog_file $cert_file $key_file";
    script_run 'pkill -9 x3270';
    enter_cmd 'killall xterm';

    # Return to x11
    select_console 'x11';
}

sub test_flags {
    return {always_rollback => 1};
}

1;
