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

use virt_autotest_base;

our @EXPORT = qw(set_serialdev setup_console_in_grub repl_repo_in_sourcefile);

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

    my $cmd = "if [ -d /boot/grub2 ]; then cp $grub_default_file ${grub_default_file}.org; sed -ri '/GRUB_CMDLINE_(LINUX|LINUX_DEFAULT|XEN_DEFAULT)=/ {s/(console|com\\d+)=[^ \"]*//g; /LINUX=/s/\"\$/ console=$serialdev,115200 console=tty\"/;/XEN_DEFAULT=/ s/\"\$/ console=com2,115200\"/;}' $grub_default_file ; fi";
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

sub repl_repo_in_sourcefile() {
    # Replace the daily build repo as guest installation resource in source file (like source.cn; source.de ..)
    my $veritem = "source.http.sles-" . lc(get_var("VERSION")) . "-64";
    if (get_var("REPO_0")) {
        my $location = &virt_autotest_base::execute_script_run("", "perl /usr/share/qa/tools/location_detect_impl.pl", 10);
        $location =~ s/[\r\n]+$//;
        my $soucefile = "/usr/share/qa/virtautolib/data/" . "sources." . "$location";
        my $newrepo   = "ftp://openqa.suse.de/" . get_var("REPO_0");
        script_run("sed -i \"s#$veritem=.*#$veritem=$newrepo#\" $soucefile");
        script_run("cat $soucefile");
    }
    else {
        print "Do not need to change resource for $veritem item\n";
    }
}

1;

