# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package virt_utils;
use base Exporter;
use Exporter;
use strict;
use warnings;
use File::Basename;
use testapi;
use Data::Dumper;
use XML::Writer;
use IO::File;

our @EXPORT = qw(set_serialdev setup_console_in_grub);

sub set_serialdev() {
    if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
        type_string("clear\n");
        type_string("cat /etc/SuSE-release \n");
        save_screenshot;
        assert_screen([qw/on_host_sles_12_sp2_or_above on_host_lower_than_sles_12_sp2/], 5);
        if (match_has_tag("on_host_sles_12_sp2_or_above")) {
            $serialdev = "hvc0";
        }
        elsif (match_has_tag("on_host_lower_than_sles_12_sp2")) {
            $serialdev = "xvc0";
        }
    }
    else {
        $serialdev = "ttyS1";
    }
    type_string("echo \"Debug info: serial dev is set to $serialdev.\"\n");
}

sub setup_console_in_grub() {
    #only support grub2
    my $grub_default_file = "/etc/default/grub";
    my $grub_cfg_file     = "/boot/grub2/grub.cfg";

    my $cmd = "if [ -d /boot/grub2 ]; then cp $grub_default_file ${grub_default_file}.org; sed -ri '/GRUB_CMDLINE_(LINUX|XEN_DEFAULT)=/ {s/(console|com\\d+)=[^\\s\"]*//g; /LINUX=/s/\"\$/ console=$serialdev console=tty\"/;/XEN_DEFAULT=/ s/\"\$/ console=com2,115200\"/;}' $grub_default_file ; fi";
    type_string("$cmd \n");
    wait_idle 3;
    save_screenshot;
    type_string("clear; cat $grub_default_file \n");
    wait_idle 3;
    save_screenshot;

    $cmd = "if [ -d /boot/grub2 ]; then grub2-mkconfig -o $grub_cfg_file; fi";
    type_string("$cmd \n", 40);
    wait_idle 3;
    save_screenshot;
    type_string("clear; cat $grub_cfg_file \n");
    wait_idle 3;
    save_screenshot;
}

1;

