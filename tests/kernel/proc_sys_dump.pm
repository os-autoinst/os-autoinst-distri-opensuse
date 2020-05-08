# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Partially dump /sys and /proc
# - Download test script from "https://raw.githubusercontent.com/richiejp/ltp/dump/scripts/proc_sys_dump.sh"
# - Make executable and create a temp dir
# - Run test script
# - Upload logs
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi qw(is_serial_terminal :DEFAULT);
use utils;
use serial_terminal;
require bmwqemu;
use Utils::Architectures 'is_aarch64';

sub run {
    my ($self)         = @_;
    my $tar_dir        = '/tmp/proc_sys_dump/';
    my $tar            = $tar_dir . 'tar.xz';
    my $ps_dump        = 'proc_sys_dump.sh';
    my $white_list     = '~/proc_sys_whitelist.txt';
    my $use_white_list = check_var('PROC_SYS_USE_WHITELIST', 1);
    my $wl_opt  = $use_white_list ? 'u' : 'w';
    my $timeout = $use_white_list ? 120 : 300;
    my $script_url = data_url("ltp/$ps_dump");

    $timeout *= 2 if is_aarch64;

    assert_script_run("curl -sS -o /tmp/$ps_dump $script_url");
    assert_script_run("chmod u+x /tmp/$ps_dump", timeout => 300);
    assert_script_run("mkdir -p $tar_dir");
    assert_script_run("/tmp/$ps_dump -c $tar -$wl_opt $white_list", timeout => $timeout);
    upload_logs($tar);
}

=head1 Discussion

The /proc and /sys directories contain lots of useful information which is
only available on a running system or in a crash dump. In order to get this
information, we would usually need a system image or an actual live system.

However a system image or the actual system may not be available when it comes
to debugging so instead we can attempt to dump the contents of these
files.

Many of the files in proc and sys are not meant to be read from at all or
block until an event occurs. I am not aware of any programmatic way to find
out which files are practically readable, so the script attempts to read all
of them (expect process files) and gives up after a timeout or if the file
produces too much information.

This module relies on a shell script I have created for the LTP.

=head1 Configuration

=head2 PROC_SYS_DUMP

This is the variable used by the LTP to decide if the module should be run.

=head2 PROC_SYS_USE_WHITELIST

In order to speed up the process, a whitelist can be generated which contains
a list of successful files from the previous run. This also dramatically
reduces the size of the output because larger files are filtered out when
generating the whitelist.

=cut
