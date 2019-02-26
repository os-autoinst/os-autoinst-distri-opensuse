# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Register Toolchain channel for CaaSP and do basic tests
# Maintainer: Tomas Hehejik <thehejik@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use caasp 'process_reboot';

sub run {
    my $list_addons = script_output('LANG=C SUSEConnect --list');
    record_soft_failure('bsc#1090729') if $list_addons =~ /SUSE CaaS Plattform/;
    my $install_command = ($list_addons =~ /Activate with:\s+(.*)/) ? $1 : die "Command for installing not available";
    if (script_run($install_command, 60)) {
        record_soft_failure('bsc#1090200');
        # Workarond for registering by transactional-update instead of SUSEConnect
        assert_script_run 'transactional-update register -p caasp-toolchain/' . get_var('VERSION') . '/x86_64';
    }

    # Option --no-confirm is actually used in zypper call
    assert_script_run 'transactional-update pkg install --no-confirm gcc gdb make strace tcpdump';

    # Reboot to use a new btrfs snapshot with installed tools
    process_reboot 1;

    # tcpdump test
    record_info 'tcpdump';
    type_string("tcpdump port 443 -s 0 -B 1000 -c 1 -w tcpdump.pcap > /dev/null 2>&1 &\n");
    assert_script_run('curl https://google.com');
    assert_script_run('tcpdump -r tcpdump.pcap -vv');

    # strace test
    record_info 'strace';
    assert_script_run('strace -o strace.log uname');
    assert_script_run('cat strace.log');

    # gcc+make test
    record_info 'gcc make';
    assert_script_run('mkdir hello; cd hello');

    my $hello = <<'EOF';
#include <stdio.h>

int main() {
  printf("Hello openQA!\n");
  return 0;
}
EOF

    script_run("echo '$hello' > hello.c");

    my $makefile = <<'EOF';
hello: hello.o

hello.o: hello.c
\tgcc -c hello.c
clean:
\trm hello.o hello
EOF

    script_run("echo -e '$makefile' > Makefile");
    assert_script_run('gcc --version');
    assert_script_run('make');
    assert_script_run('make clean');
    assert_script_run('make');
    assert_script_run('./hello | grep openQA');

    # gdb test
    record_info 'gdb';
    assert_script_run('gdb ./hello -ex run -ex \'set confirm off\' -ex quit');

    # TODO KMP tests for NVIDIA drivers
}

1;
