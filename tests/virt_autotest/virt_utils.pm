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
# Summary: virt_utils: The initial version of virtualization automation test in openqa.
#          This file provides fundamental utilities.
# Maintainer: alice <xlai@suse.com>

use base Exporter;
use Exporter;
use strict;
use warnings;
use File::Basename;
use testapi;
use Data::Dumper;
use XML::Writer;
use IO::File;
use proxymode;
use virt_autotest_base;

our @EXPORT = qw(set_serialdev setup_console_in_grub repl_repo_in_sourcefile resetup_console);

my $grub_ver;

sub set_serialdev() {
    script_run("clear");
    script_run("cat /etc/SuSE-release");
    save_screenshot;
    assert_screen([qw(on_host_sles_12_sp2_or_above on_host_lower_than_sles_12_sp2)]);

    if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
        if (match_has_tag("on_host_sles_12_sp2_or_above")) {
            $serialdev = "hvc0";
        }
        elsif (match_has_tag("on_host_lower_than_sles_12_sp2")) {
            $serialdev = "xvc0";
        }
    }
    else {
        $serialdev = get_var('SERIALDEV', 'ttyS1');
    }

    if (match_has_tag("grub1")) {
        $grub_ver = "grub1";
    }
    else {
        $grub_ver = "grub2";
    }

    type_string("echo \"Debug info: serial dev is set to $serialdev. Grub version is $grub_ver.\"\n");

    return $serialdev;
}

sub setup_console_in_grub {
    my $ipmi_console = shift;
    $ipmi_console //= $serialdev;

    my $grub_cfg_file;

    if ($grub_ver eq "grub2") {
        $grub_cfg_file = "/boot/grub2/grub.cfg";
    }
    elsif ($grub_ver eq "grub1") {
        $grub_cfg_file = "/boot/grub/menu.lst";
    }
    else {
        die "The grub version is not supported!";
    }

    my $cmd;

    if ($grub_ver eq "grub2") {
        #grub2
        my $grub_default_file = "/etc/default/grub";
        $cmd
          = "if [ -d /boot/grub2 ]; then cp $grub_default_file ${grub_default_file}.org; sed -ri '/GRUB_CMDLINE_(LINUX|LINUX_DEFAULT|XEN_DEFAULT)=/ {s/(console|com\\d+|loglevel|log_lvl|guest_loglvl)=[^ \"]*//g; /LINUX=/s/\"\$/ loglevel=5 console=$ipmi_console,115200 console=tty\"/;/XEN_DEFAULT=/ s/\"\$/ log_lvl=all guest_loglvl=all console=com2,115200\"/;}' $grub_default_file ; fi";
        script_run("$cmd");
        wait_idle 3;
        save_screenshot;
        script_run("clear; cat $grub_default_file");
        wait_idle 3;
        save_screenshot;
        $cmd = "if [ -d /boot/grub2 ]; then grub2-mkconfig -o $grub_cfg_file; fi";
    }
    elsif ($grub_ver eq "grub1") {
        $cmd
          = "cp $grub_cfg_file ${grub_cfg_file}.org; sed -i 's/timeout [0-9]*/timeout 10/; /module \\\/boot\\\/vmlinuz/{s/console=.*,115200/console=$ipmi_console,115200/g;}' $grub_cfg_file";
    }

    script_run("$cmd", 40);
    wait_idle 3;
    save_screenshot;
    script_run("clear; cat $grub_cfg_file");
    wait_idle 3;
    save_screenshot;
}

sub repl_repo_in_sourcefile() {
    # Replace the daily build repo as guest installation resource in source file (like source.cn; source.de ..)
    my $veritem = "source.http.sles-" . lc(get_var("VERSION")) . "-64";
    if (get_var("REPO_0")) {
        my $location = &virt_autotest_base::execute_script_run("", "perl /usr/share/qa/tools/location_detect_impl.pl", 60);
        $location =~ s/[\r\n]+$//;
        my $soucefile = "/usr/share/qa/virtautolib/data/" . "sources." . "$location";
        my $newrepo   = "ftp://openqa.suse.de/" . get_var("REPO_0");
        my $shell_cmd
          = "if grep $veritem $soucefile >> /dev/null;then sed -i \"s#$veritem=.*#$veritem=$newrepo#\" $soucefile;else echo \"$veritem=$newrepo\" >> $soucefile;fi";
        assert_script_run($shell_cmd);
        assert_script_run("cat $soucefile");
    }
    else {
        print "Do not need to change resource for $veritem item\n";
    }
}

sub resetup_console() {
    my $ipmi_console = set_serialdev();
    if (get_var("PROXY_MODE")) {
        &proxymode::set_serialdev();
    }
    setup_console_in_grub($ipmi_console);
}

1;

