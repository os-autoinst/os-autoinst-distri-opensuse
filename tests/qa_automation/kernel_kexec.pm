# Copyright (C) 2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary:  [qa_automation] kexec testsuite
# Maintainer: Nathan Zhao <jtzhao@suse.com>

use base "qa_run";
use strict;
use testapi;

sub run() {
    my $self = shift;
    $self->system_login();
    # Copy current kernel and rename it
    $_ = $self->qa_script_output("uname -r", 10);
    s/-default$/-kexec/;
    my $kernel_file = "vmlinuz-$_";
    my $initrd_file = "initrd-$_";
    assert_script_run("cp /boot/vmlinu*-`uname -r` /boot/$kernel_file");
    assert_script_run("cp /boot/initrd-`uname -r` /boot/$initrd_file");
    # kernel cmdline parameter
    $_ = $self->qa_script_output("cat /proc/cmdline");
    s/-default /-kexec /;
    my $cmdline = "$_ debug";
    # kexec -l
    assert_script_run("kexec -l /boot/$kernel_file --initrd=/boot/$initrd_file --command-line='$cmdline'");
    # kexec -e
    type_string("systemctl kexec\n");
    # wait for reboot
    wait_idle();
    reset_consoles();
    if (get_var('VIRTIO_CONSOLE')) {
        select_console('root-virtio-terminal');
    }
    else {
        select_console('root-console');
    }
    # Check kernel cmdline parameter
    my $result = $self->qa_script_output("cat /proc/cmdline");
    print "Checking kernel boot parameter...\nCurrent:  $result\nExpected: $cmdline\n";
    if ($cmdline ne $result) {
        die "kexec failed";
    }
}

1;
