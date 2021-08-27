# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: Add test for conman  package
#
#    https://fate.suse.com/321724
#
#    This tests the conman package from the HPC module
#
# Maintainer: Matthias Griessmeier <mgriessmeier@suse.com>


use base 'hpcbase';
use strict;
use warnings;
use testapi;
use utils;
use susedistribution;

sub run {
    my $self = shift;

    zypper_call('in conman');

    # test with unix domain socket
    assert_script_run("echo 'CONSOLE name=\"socket1\" dev=\"unix:/tmp/testsocket\"' >> /etc/conman.conf");
    assert_script_run("cat /etc/conman.conf");

    $self->enable_and_start('conman');

    # check service status
    systemctl 'status conman';

    select_console('root-console');

    # run netcat on this socket
    enter_cmd("netcat -ClU /tmp/testsocket &");

    # If needed change group:
    my $conman_chgrp = q!GRP=$(ps -Ao group,fname | grep conmand | cut -d' ' -f 1);!;
    $conman_chgrp .= q! [ "$GRP" = "root" ] || { chgrp $GRP /tmp/testsocket; chmod g+w /tmp/testsocket; }!;
    enter_cmd($conman_chgrp . "");

    # do not restart conmand after starting netcat!

    # start conman on this socket
    enter_cmd("conman socket1 &");

    # test from netcat side
    enter_cmd("fg 1");
    wait_still_screen(1, 2);
    enter_cmd("Hello from nc...");
    send_key('ctrl-z');
    enter_cmd("fg 2");
    assert_screen('socket-response');

    # test from conman side
    enter_cmd("&E");       # enable echoing
    enter_cmd("Hello from conman...");
    send_key('ctrl-l');    # send \n
    type_string '&.';
    assert_screen("connection-closed");
    enter_cmd "fg 1";
    assert_screen('nc-response');

    send_key 'ctrl-d';
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    $self->upload_service_log('conmand');
    $self->SUPER::post_fail_hook;
}

1;
