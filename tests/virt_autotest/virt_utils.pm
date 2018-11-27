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
use version_utils 'is_sle';

our @EXPORT
  = qw(update_guest_configurations_with_daily_build repl_addon_with_daily_build_module_in_files repl_module_in_sourcefile handle_sp_in_settings handle_sp_in_settings_with_fcs handle_sp_in_settings_with_sp0 clean_up_red_disks);

sub get_version_for_daily_build_guest {
    my $version = '';
    if (get_var('REPO_0_TO_INSTALL', '')) {
        $version = get_var('TARGET_DEVELOPING_VERSION', '');
    }
    else {
        $version = get_var("VERSION", '');
    }
    $version = lc($version);
    if ($version !~ /sp/m) {
        $version = $version . "-fcs";
    }
    return $version;
}

sub repl_repo_in_sourcefile {
    # Replace the daily build repo as guest installation resource in source file (like source.cn; source.de ..)
    my $verorig = "source.http.sles-" . get_version_for_daily_build_guest . "-64";
    my $veritem = check_var('ARCH', 'x86_64') ? $verorig : get_required_var('ARCH') . ".$verorig";
    if (get_var("REPO_0")) {
        my $location = &virt_autotest_base::execute_script_run("", "perl /usr/share/qa/tools/location_detect_impl.pl", 60);
        $location =~ s/[\r\n]+$//;
        my $soucefile = "/usr/share/qa/virtautolib/data/" . "sources." . "$location";
        my $newrepo   = "http://openqa.suse.de/assets/repo/" . get_var("REPO_0");
        my $shell_cmd
          = "if grep $veritem $soucefile >> /dev/null;then sed -i \"s#^$veritem=.*#$veritem=$newrepo#\" $soucefile;else echo \"$veritem=$newrepo\" >> $soucefile;fi";
        assert_script_run($shell_cmd);
        assert_script_run("grep \"$veritem\" $soucefile");
    }
    else {
        print "Do not need to change resource for $veritem item\n";
    }
    save_screenshot;
}
# Replace module repos configured in sources.* with openqa daily build repos
sub repl_module_in_sourcefile {
    my $version = get_version_for_daily_build_guest;
    $version =~ s/fcs/sp0/;
    my ($release) = ($version =~ /(\d+)-/m);
    # We only support sle product, and only products >= sle15 has module link
    return unless (is_sle && $release >= 15);

    my $replaced_orig = "source.(Basesystem|Desktop-Applications|Legacy|Server-Applications|Development-Tools|Web-Scripting).sles-" . $version . "-64=";
    my $replaced_item = get_required_var('ARCH') . ".$replaced_orig";
    $version =~ s/-sp0//;
    $version = uc($version);
    my $daily_build_module = "http://openqa.suse.de/assets/repo/SLE-${version}-Module-\\2-POOL-" . get_required_var('ARCH') . "-Build" . get_required_var('BUILD') . "-Media1/";
    my $source_file = "/usr/share/qa/virtautolib/data/sources.*";
    my $command     = "sed -ri 's#^(${replaced_item}).*\$#\\1$daily_build_module#g' $source_file";
    print "Debug: the command to execute is:\n$command \n";
    assert_script_run($command);
    save_screenshot;
    assert_script_run("grep Module $source_file -r");
    save_screenshot;
    upload_logs "/usr/share/qa/virtautolib/data/sources.de";
}

sub repl_addon_with_daily_build_module_in_files {
    my $file_list = shift;

    $file_list =~ s/\n/ /g;
    my $version = get_version_for_daily_build_guest;
    $version =~ s/-fcs//;
    $version = uc($version);
    my $command
      = "for file in $file_list;do "
      . "sed -ri 's#^.*(Basesystem|Desktop-Applications|Legacy|Server-Applications|Development-Tools|Web-Scripting).*\$#"
      . "<media_url>http://openqa.suse.de/assets/repo/SLE-${version}-Module-\\1-POOL-x86_64-Build"
      . get_required_var('BUILD')
      . "-Media1/</media_url>#' \$file;done";
    assert_script_run($command);
    save_screenshot;
    assert_script_run("grep media_url $file_list -r");
    save_screenshot;
}

sub repl_guest_autoyast_addon_with_daily_build_module {
    #replace the addons url in guest autoyast file in qa_lib_virtauto-data with the daily build module repos
    my $version = get_version_for_daily_build_guest;
    $version =~ s/-/\//;
    my $autoyast_root_dir = "/usr/share/qa/virtautolib/data/autoinstallation/sles/" . $version . "/";
    my $file_list         = &script_output("find $autoyast_root_dir -type f");
    repl_addon_with_daily_build_module_in_files("$file_list");
}

# Many virtualization testsuites contain settings composed by %DISTRI%s-%VERSION%
# that need special handling for sp0/fcs, when integer products are being tested, eg sle15
sub handle_sp_in_settings {
    my ($var_name, $value_for_sp) = @_;

    die "We only support sles product currently!" unless is_sle;

    # We need small case variable value
    my $var_value = lc(get_required_var("$var_name"));
    # Add $value_for_sp after release for products like sle15, sle16
    if ($var_value !~ /sp|fcs/ && $value_for_sp) {
        $var_value =~ s/(sles-\d+)/$1-$value_for_sp/;
    }
    set_var("$var_name", "$var_value");
    bmwqemu::save_vars();
}

sub handle_sp_in_settings_with_fcs {
    my $var_name = shift;
    handle_sp_in_settings($var_name, "fcs");
}

sub handle_sp_in_settings_with_sp0 {
    my $var_name = shift;
    handle_sp_in_settings($var_name, "sp0");
}

sub update_guest_configurations_with_daily_build {
    repl_repo_in_sourcefile;
    repl_module_in_sourcefile;
    # qa_lib_virtauto pkg will handle replacing module url with module link in source.xx for sle15 and 15+
    # repl_guest_autoyast_addon_with_daily_build_module;
}

sub clean_up_red_disks {
    my $wait_script           = "600";
    my $get_disks_not_used    = "ls /dev/sd* | grep -v -e \"/dev/sd[a].*\" | grep -o -e \"/dev/sd[b-z]\\\{1,\\\}[[:digit:]]\\\{0,\\\}\"";
    my $disks_not_used        = script_output($get_disks_not_used, $wait_script, type_command => 1, proceed_on_failure => 1);
    my $get_disks_nu_num      = "$get_disks_not_used | wc -l";
    my $disks_nu_num          = script_output($get_disks_nu_num, $wait_script, type_command => 1, proceed_on_failure => 1);
    my $get_disks_fs_overview = "lsblk -f";
    my $get_fs_type_supported = "$get_disks_fs_overview | grep sda | awk \'{print \$2}\' | grep -v swap | tail -1";
    my $fs_type_supported     = script_output($get_fs_type_supported, $wait_script, type_command => 1, proceed_on_failure => 1);
    my $make_fs_cmd           = "mkfs.$fs_type_supported";
    my @disks_nu_array        = split(/\n+/, $disks_not_used);
    my $disks_nu_length       = scalar @disks_nu_array;
    my $get_swaps_not_need = "$get_disks_fs_overview | grep -v -e \"sd[a].*\" | grep -i \"\\\[SWAP\\\]\" | grep -o -e \"sd[b-z]\\\{1,\\\}[[:digit:]]\\\{0,\\\}\"";
    my $swaps_not_used = script_output($get_swaps_not_need, $wait_script, type_command => 1, proceed_on_failure => 1);

    if ($swaps_not_used) {
        my @swaps_nu_array = split(/\n+/, $swaps_not_used);
        foreach my $swapitem (@swaps_nu_array) {
            if ($swapitem =~ /sd[b-z].*/) {
                assert_script_run("swapoff /dev/$swapitem", $wait_script);
            }
        }
    }

    if (($disks_nu_length eq $disks_nu_num) && $disks_nu_num && $fs_type_supported) {
        foreach my $item (@disks_nu_array) {
            if ($item =~ /^\/dev\/sd[b-z]$/) {
                assert_script_run("wipefs -a -f $item && $make_fs_cmd $item", $wait_script);
            }
        }
        diag("Debug info: Redundant disks have already been formatted using mkfs.");
    }
    else {
        diag("Debug info: Maybe there are no other disks functioning other than /dev/sda. Or something unexpected happened during obtaining available file system type.");
    }
    my $disks_fs_overview = script_output($get_disks_fs_overview, $wait_script, type_command => 1, proceed_on_failure => 1);
    diag("Debug info: Disks and File Systems Overview:\n $disks_fs_overview");
}

1;
