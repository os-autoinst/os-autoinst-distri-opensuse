# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HPC_Module: Add test for conman  package
#
#    https://fate.suse.com/321724
#
#    This tests the conman package from the HPC module
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'hpcbase', -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use susedistribution;

our $file = 'tmpresults.xml';

sub run ($self) {
    my $rt = zypper_call('in conman');
    test_case('Check installation', 'conman installation', $rt);

    # test with unix domain socket
    assert_script_run("echo 'CONSOLE name=\"socket1\" dev=\"unix:/tmp/testsocket\"' >> /etc/conman.conf");
    assert_script_run("cat /etc/conman.conf");

    $self->enable_and_start('conman');

    # check service status
    $rt = systemctl 'status conman';
    test_case('Check service status', 'conman status', $rt);

    select_console('root-console');
    # run netcat on this socket
    enter_cmd("netcat -ClU /tmp/testsocket &");

    # If needed change group:
    my $conman_chgrp = q!GRP=$(ps -Ao group,fname | grep conmand | cut -d' ' -f 1);!;
    $conman_chgrp .= q! [ "$GRP" = "root" ] || { chgrp $GRP /tmp/testsocket; chmod g+w /tmp/testsocket; }!;
    enter_cmd($conman_chgrp . "");

    # do not restart conmand after starting netcat!

    # start conman on this socket
    $rt = enter_cmd("conman socket1 &");
    test_case('Config socket', 'conman socket', $rt);

    # test from netcat side
    $rt = eval {
        enter_cmd("fg 1");
        wait_still_screen(1, 2);
        enter_cmd("Hello from nc...");
        send_key('ctrl-z');
        enter_cmd("fg 2");
        assert_screen('socket-response');
        return 0;
    };
    test_case('Test communication from netstat', 'conman test communication', $rt);

    # test from conman side
    $rt = eval {
        enter_cmd("&E");    # enable echoing
        enter_cmd("Hello from conman...");
        send_key('ctrl-l');    # send \n
        type_string '&.';
        assert_screen("connection-closed");
        enter_cmd "fg 1";
        assert_screen('nc-response');
        send_key('ctrl-c');
        return 0;
    };
    test_case('Test conman communication', 'conman test communication', 0);
}

sub post_run_hook ($self) {
    select_serial_terminal;
    pars_results('HPC conman tests', $file, @all_tests_results);
    parse_extra_log('XUnit', $file);
    $self->SUPER::post_run_hook();
}
sub post_fail_hook ($self) {
    select_serial_terminal;
    $self->upload_service_log('conman');
    $self->SUPER::post_fail_hook;
}

1;
