# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: powerpc-utils
# Summary: regression test powerpc-utils, verify that powerpc-utils works as expected
# Maintainer: Zaoliang Luo <zluo@suse.com>

use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    zypper_call('refresh');
    zypper_call('in powerpc-utils');
    # check installed or updated power-utils version
    assert_script_run("rpm -q powerpc-utils");

    # run powerpc-utils and save logs
    my $logs = "/tmp/powerpc-utils.log";
    assert_script_run('echo -e "__________ lparstat __________\n\n\n" > ' . $logs);
    assert_script_run("lparstat |& tee -a $logs");

    assert_script_run('echo -e "___________ lsslot ___________\n\n\n" >> ' . $logs);
    assert_script_run("lsslot |& tee -a $logs");

    assert_script_run('echo -e "________ serv_config _________\n\n\n" >> ' . $logs);
    assert_script_run("serv_config -l |& tee -a $logs");

    assert_script_run('echo -e "_________ sys_ident __________\n\n\n" >> ' . $logs);
    assert_script_run("sys_ident -p |& tee -a $logs");

    assert_script_run('echo -e "__________ ls-vdev ___________\n\n\n" >> ' . $logs);
    assert_script_run("ls-vdev |& tee -a $logs");

    assert_script_run('echo -e "__________ ls-veth ___________\n\n\n" >> ' . $logs);
    assert_script_run("ls-veth |& tee -a $logs");

    # Upload logs for references
    upload_logs("$logs");
}

1;
