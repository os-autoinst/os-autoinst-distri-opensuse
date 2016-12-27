# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This module installs and setup services and other things needed for
# networking part of the LTP (Linux Test Project).
# Maintainer: Petr Vorel <pvorel@suse.cz>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;
use utils;

sub install {
    # utils
    zypper_call("in expect iputils net-tools-deprecated telnet", log => 1);

    # clients
    zypper_call("in mrsh-rsh-compat telnet", log => 1);

    # services
    zypper_call("in bind dhcp-server finger-server nfs-kernel-server rdist rpcbind rsync telnet-server vsftpd xinetd", log => 1);
    for my $i (qw(nfsserver rpcbind vsftpd xinetd)) {
        assert_script_run "systemctl enable $i.service";
        assert_script_run "systemctl start $i.service";
    }
}

sub setup {
    my $content;

    $content = <<EOF;
# ltp specific setup
rlogin
rsh
rexec
pts/1
pts/2
pts/3
pts/4
pts/5
pts/6
pts/7
pts/8
pts/9
EOF
    assert_script_run "echo \"$content\" >> '/etc/securetty'";

    # xinetd (echo)
    assert_script_run 'sed -i \'s/\(disable\s*=\s\)yes/\1no/\' /etc/xinetd.d/echo';
    assert_script_run 'sed -i \'s/^#\(\s*bind\s*=\)\s*$/\1 0.0.0.0/\' /etc/xinetd.conf';

    # rlogin
    assert_script_run 'echo "+" > /root/.rhosts';

    # nfs
    assert_script_run 'echo \'/ *(rw,no_root_squash,sync)\' >> /etc/exports';
    assert_script_run 'exportfs';
}

# poo#14402
sub run {
    select_console(get_var('VIRTIO_CONSOLE') ? 'root-virtio-terminal' : 'root-console');
    install;
    setup;
}

sub test_flags {
    return {
        fatal     => 1,
        milestone => 1
    };
}

1;

# vim: set sw=4 et:
