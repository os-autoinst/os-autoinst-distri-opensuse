# SUSE's openQA tests
#
# Copyright 2012-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
package virt_utils;
# Summary: virt_utils: The initial version of virtualization automation test in openqa.
#          This file provides fundamental utilities.
# Maintainer: alice <xlai@suse.com>

use base Exporter;
use Exporter;
use Sys::Hostname;
use File::Basename;
use testapi;
use Utils::Architectures;
use Data::Dumper;
use XML::Writer;
use IO::File;
use List::Util 'first';
use LWP::Simple 'head';
use virt_autotest::utils;
use version_utils qw(is_sle is_alp get_os_release);

our @EXPORT = qw(
  enable_debug_logging
  update_guest_configurations_with_daily_build
  locate_sourcefile
  get_repo_0_prefix
  repl_repo_in_sourcefile
  repl_addon_with_daily_build_module_in_files
  repl_module_in_sourcefile
  handle_sp_in_settings
  handle_sp_in_settings_with_fcs
  handle_sp_in_settings_with_sp0
  clean_up_red_disks
  lpar_cmd
  generate_guest_asset_name
  get_guest_disk_name_from_guest_xml
  compress_single_qcow2_disk
  get_guest_list
  download_guest_assets
  is_installed_equal_upgrade_major_release
  generateXML_from_data
  check_guest_disk_type
  perform_guest_restart
  collect_host_and_guest_logs
  cleanup_host_and_guest_logs
  monitor_guest_console
  start_monitor_guest_console
  stop_monitor_guest_console
  is_developing_sles
);

sub enable_debug_logging {

    turn_on_libvirt_debugging_log;

    # enable journal log with previous reboot
    if (is_sle('>=15-SP6')) {
        unless (get_var('AUTOYAST')) {
            my $journald_conf_file = "/etc/systemd/journald.conf.d/01-virt-test.conf";
            script_run("echo -e \"[Journal]\\\nStorage=persistent\" > $journald_conf_file");
            script_run "systemd-analyze cat-config systemd/journald.conf | grep Storage";
            script_run 'systemctl restart systemd-journald';
        }
    }
    else {
        my $journald_conf_file = "/etc/systemd/journald.conf";
        script_run "sed -i '/^[# ]*Storage *=/{h;s/^[# ]*Storage *=.*\$/Storage=persistent/};\${x;/^\$/{s//Storage=persistent/;H};x}' $journald_conf_file";
        script_run "grep Storage $journald_conf_file";
        script_run 'systemctl restart systemd-journald';
    }

    # enable qemu core dumps
    my $qemu_conf_file = "/etc/libvirt/qemu.conf";
    if (!script_run "ls $qemu_conf_file") {
        script_run "sed -i '/max_core *=/{h;s/^[# ]*max_core *=.*\$/max_core = \"unlimited\"/};\${x;/^\$/{s//max_core = \"unlimited\"/;H};x}' $qemu_conf_file";
        script_run "grep max_core $qemu_conf_file";
    }
    save_screenshot;

}

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

sub locate_sourcefile {
    my $location = '';
    if (!is_s390x) {
        $location = script_output("perl /usr/share/qa/tools/location_detect_impl.pl", 60, proceed_on_failure => 1);
        if ($location) {
            $location =~ s/[\r\n]+$//;
        }
        else {
            $location = 'de';
        }
    }
    else {
        #S390x LPAR just be only located at DE now.
        #No plan move S390x LPAR to the other location.
        #So, define variable location as "de" for S390x LPAR.
        $location = 'de';
    }
    return $location;
}

sub get_repo_0_prefix {
    # Get customized repo location from REPO_0_PREFIX and append missing forward slash to the end
    my $repo_0_prefix = get_var("REPO_0_PREFIX", "");
    $repo_0_prefix .= '/' unless $repo_0_prefix =~ /\/$/;
    $repo_0_prefix = ($repo_0_prefix ne "/" ? $repo_0_prefix : "http://openqa.suse.de/assets/repo/");
    return $repo_0_prefix;
}

sub repl_repo_in_sourcefile {
    # Replace the daily build repo as guest installation resource in source file (like source.cn; source.de ..)
    my $verorig = "source.http.sles-" . get_version_for_daily_build_guest . "-64";
    my $veritem = is_x86_64 ? $verorig : get_required_var('ARCH') . ".$verorig";
    if (get_var("REPO_0")) {
        my $soucefile = "/usr/share/qa/virtautolib/data/" . "sources." . locate_sourcefile;
        my $newrepo = get_repo_0_prefix . get_var("REPO_0");
        # for sles15sp2+, install host with Online installer, while install guest with Full installer
        $newrepo =~ s/-Online-/-Full-/ if ($verorig =~ /15-sp[2-9]/i);
        my $shell_cmd
          = "if grep $veritem $soucefile >> /dev/null;then sed -i \"s#^$veritem=.*#$veritem=$newrepo#\" $soucefile;else echo \"$veritem=$newrepo\" >> $soucefile;fi";
        if (is_s390x) {
            lpar_cmd("$shell_cmd");
            lpar_cmd("grep \"$veritem\" $soucefile");
        }
        else {
            assert_script_run($shell_cmd);
            assert_script_run("grep \"$veritem\" $soucefile");
        }
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
    my $daily_build_module = get_repo_0_prefix;
    # for sles15sp2+, install host with Online installer, while install guest with Full installer
    if ($version =~ /15-SP[2-9]/) {
        $daily_build_module .= get_var("REPO_0") . "/Module-\\2/";
        $daily_build_module =~ s/-Online-/-Full-/;
    }
    else {
        $daily_build_module .= "SLE-${version}-Module-\\2-POOL-" . get_required_var('ARCH') . "-Build" . get_required_var('BUILD') . "-Media1/";
    }
    my $source_file = "/usr/share/qa/virtautolib/data/sources." . locate_sourcefile;
    my $command = "sed -ri 's#^(${replaced_item}).*\$#\\1$daily_build_module#g' $source_file";
    print "Debug: the command to execute is:\n$command \n";
    if (is_s390x) {
        lpar_cmd("$command");
        lpar_cmd("grep Module $source_file -r");
        upload_asset "/usr/share/qa/virtautolib/data/sources.de", 1, 1;
    }
    else {
        assert_script_run($command, timeout => 120);
        save_screenshot;
        assert_script_run("grep Module $source_file -r");
        save_screenshot;
        upload_logs "/usr/share/qa/virtautolib/data/sources.de";
    }
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
    my $file_list = script_output("find $autoyast_root_dir -type f");
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
    my $wait_script = "600";
    my $get_disks_not_used = "ls /dev/sd* | grep -v -e \"/dev/sd[a].*\" | grep -o -e \"/dev/sd[b-z]\\\{1,\\\}[[:digit:]]\\\{0,\\\}\"";
    my $disks_not_used = script_output($get_disks_not_used, $wait_script, type_command => 1, proceed_on_failure => 1);
    my $get_disks_nu_num = "$get_disks_not_used | wc -l";
    my $disks_nu_num = script_output($get_disks_nu_num, $wait_script, type_command => 1, proceed_on_failure => 1);
    my $get_disks_fs_overview = "lsblk -f";
    my $get_fs_type_supported = "$get_disks_fs_overview | grep sda | awk \'{print \$2}\' | grep -v swap | tail -1";
    my $fs_type_supported = script_output($get_fs_type_supported, $wait_script, type_command => 1, proceed_on_failure => 1);
    my $make_fs_cmd = "mkfs.$fs_type_supported";
    my @disks_nu_array = split(/\n+/, $disks_not_used);
    my $disks_nu_length = scalar @disks_nu_array;
    my $get_swaps_not_need = "$get_disks_fs_overview | grep -v -e \"sd[a].*\" | grep -i \"\\\[SWAP\\\]\" | grep -o -e \"sd[b-z]\\\{1,\\\}[[:digit:]]\\\{0,\\\}\"";
    my $swaps_not_used = script_output($get_swaps_not_need, $wait_script, type_command => 1, proceed_on_failure => 1);

    my $wipe_fs_cmd = "";
    my $installed_os_ver = get_var('VERSION_TO_INSTALL', get_var('VERSION', ''));
    ($installed_os_ver) = $installed_os_ver =~ /^(\d+)/;
    if ($installed_os_ver eq '11') {
        $wipe_fs_cmd = "wipefs -a";
    }
    else {
        $wipe_fs_cmd = "wipefs -a -f";
    }

    $make_fs_cmd = "mkfs.$fs_type_supported -f" if ($fs_type_supported eq 'btrfs');

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
                assert_script_run("echo \"y\\n\" | $wipe_fs_cmd $item &&  echo \"y\\n\" | $make_fs_cmd $item", $wait_script);
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

sub lpar_cmd {
    my ($cmd, $args) = @_;
    my $timeout = $args->{timeout} // 300;
    die 'Command not provided' unless $cmd;
    $args->{ignore_return_code} ||= 0;
    my $ret = console('svirt')->run_cmd($cmd, timeout => $timeout);
    record_info('INFO', "Command $cmd run on S390X LPAR: SUCESS") if ($ret == 0);
    die 'Find new failure, please check manually' unless ($args->{ignore_return_code} || !$ret);
}

# Guest xml will be uploaded with name format [generated_name_by_this_func].xml
# Guest disk will be uploaded with name format [generated_name_by_this_func].disk
# When reusing these assets, needs to recover the names to original by reverting this process
sub generate_guest_asset_name {
    my $guest = shift;

    #get build number
    my $build_num;
    # for a clone job, the setting BUILD must be set as it was in its original job, for example, BUILD=98.1
    # or the job will not know in which build guest assets should be download or uploaded
    if (get_var('CASEDIR') and get_var('BUILD') !~ /^\d+[\._]?\d*$/) {
        die "Downloading guest assets is not allowed without a particular build number. Please trigger job with BUILD=<build_number> or with SKIP_GUEST_INSTALL=1 not to download guest assets from openqa server";
    }

    my $composed_name
      = 'guest_'
      . $guest
      . '_on-host_'
      . get_required_var('DISTRI') . '-'
      . get_var('VERSION_TO_INSTALL', get_required_var('VERSION'))
      . '_build'
      . (get_var('VERSION_TO_INSTALL') ? 'gm' : get_required_var('BUILD')) . '_'
      . lc(get_required_var('SYSTEM_ROLE')) . '_'
      . get_required_var('ARCH');

    return $composed_name;
}

sub get_guest_disk_name_from_guest_xml {
    my $guest = shift;

    # Our automation only supports single guest disk
    my $disk_from_xml = script_output "virsh dumpxml $guest | xmlstarlet sel -t -v //disk/source/\@file";
    record_info('Guest disk config from xml', "Guest $guest disk_from_xml is: $disk_from_xml.");
    die 'There is no guest disk file parsed out from guest xml configuration!' unless $disk_from_xml;

    return $disk_from_xml;
}

# Should only do compress from qcow2 disk to qcow2 in our automation(upload guest asset scheme).
# If disk compression fails at the first time, try again with --force-share option to avoid shared "write" lock conflict.
# Generally speaking, guest image compressing and uploading should only be done on successful guest installation and after any other operations is done on the guest.
# If qemu image operation on the guest still can not proceed due to failing to get "write" lock, then "--force-share" option can be tried to solve the problem.
# And "--force-share" is a new option that is introduced to modern SLES, it might be available on some older SLES, for example, 11-SP4 or some 12-SPx.
# Please refer to https://qemu.readthedocs.io/en/latest/tools/qemu-img.html to ease your mind on working with --force-share and convert and many others.
sub compress_single_qcow2_disk {
    my ($orig_disk, $compressed_disk) = @_;
    my $timeout = '720';
    my $cmd = "time nice ionice qemu-img convert --force-share -c -m 1 -p -O qcow2 $orig_disk $compressed_disk";

    if ($orig_disk =~ /qcow2/) {
        die("Disk compression failed from $orig_disk to $compressed_disk.") if (script_run($cmd, timeout => $timeout, die => 0, retry => 2) ne 0);
        save_screenshot;
        record_info('Disk compression', "Disk compression done from $orig_disk to $compressed_disk.");
    }
}

# get the guest list from the test suite settings
sub get_guest_list {

    #get the guest pattern from test suite settings
    #GUEST_PATTERN, GUEST_LIST, or GUEST_LIST is used in different test suites,
    #thus I use GUEST_LIST uniformly.
    if (get_var('GUEST_PATTERN')) {
        set_var('GUEST_LIST', get_var('GUEST_PATTERN'));
    }
    elsif (get_var('GUEST')) {
        set_var('GUEST_LIST', get_var('GUEST'));
    }
    handle_sp_in_settings_with_fcs("GUEST_LIST");
    my $guest_pattern = get_required_var("GUEST_LIST");

    #parse the guest list from the pattern
    return $guest_pattern if ($guest_pattern =~ /win/i);
    my $qa_guest_config_file = "/usr/share/qa/virtautolib/data/vm_guest_config_in_vh_update";
    my $hypervisor_type = get_var('SYSTEM_ROLE', '');
    my $guest_list = script_output "source /usr/share/qa/virtautolib/lib/virtlib; get_vms_from_config_file $qa_guest_config_file $guest_pattern $hypervisor_type";
    record_info('Softfail', "Not found guest pattern $guest_pattern in $qa_guest_config_file", result => 'softfail') if ($guest_list eq '');
    return $guest_list;
}

# Download guest image and xml which are defined in ASSET_*
# fg. ASSET_10=guest_%-GUEST_LIST%fv-def-net_on-host_%DISTRI%-%VERSION%_build%BUILD%_%SYSTEM_ROLE%_%ARCH%.xml
# ASSET_11=guest_%-GUEST_LIST%fv-def-net_on-host_%DISTRI%-%VERSION%_build%BUILD%_%SYSTEM_ROLE%_%ARCH%.disk
# Need set SKIP_GUEST_INSTALL=1 in the test suite settings
# Return the account of the guests downloaded
# Only available on x86_64
sub download_guest_assets {

    # guest_pattern is a string, like sles-11-sp4-64, may or may not with pv or fv given.
    my ($guests_list, $vm_xml_dir) = @_;

    # clean up vm stuff
    script_run "[ -d $vm_xml_dir ] && rm -rf $vm_xml_dir; mkdir -p $vm_xml_dir";
    my $disk_image_dir = script_output "source /usr/share/qa/virtautolib/lib/virtlib; get_vm_disk_dir";
    script_run "[ -d /tmp/prj3_guest_migration/ ] && rm -rf /tmp/prj3_guest_migration/" if get_var('VIRT_NEW_GUEST_MIGRATION_SOURCE');

    # check if vm xml files have been uploaded
    my @guests = split "\n", $guests_list;
    my @downloaded_guests;
    foreach my $guest (@guests) {
        my $guest_asset_name = generate_guest_asset_name("$guest");
        for my $i (1 .. @guests) {
            # ASSET_n0: put the guest xml file
            # ASSET_n1: put the guest disk file
            if (get_var("ASSET_${i}0", "") =~ /$guest_asset_name/) {

                # Download the guest xml file
                script_run("curl " . autoinst_url("/assets/other/" . get_var("ASSET_${i}0")) . " -o $vm_xml_dir/$guest.xml");
                script_run("ls -l $vm_xml_dir");

                # Download the guest disk file
                my $local_guest_image = script_output "grep '<source file=' $vm_xml_dir/$guest.xml | sed \"s/^\\s*<source file='\\([^']*\\)'.*\$/\\1/\"";
                # For prj3, put the downloded xml and disk files in the backup dir directory
                # in case of being flushed up by the NFS workaround from dst job
                if (get_var('VIRT_NEW_GUEST_MIGRATION_SOURCE')) {
                    my $backupRootDir = "/tmp/prj3_guest_migration/vm_backup";
                    my $backupCfgXmlDir = "$backupRootDir/vm-config-xmls";
                    my $backupDiskDir = "$backupRootDir/vm-disk-files";
                    script_run "mkdir -p $backupCfgXmlDir; mkdir -p $backupDiskDir";
                    script_run "cp $vm_xml_dir/$guest.xml $backupCfgXmlDir";
                    script_run "ls -l $backupCfgXmlDir";
                    $local_guest_image = $backupDiskDir . $local_guest_image;
                }
                script_run "[ -d `dirname $local_guest_image` ] || mkdir -p `dirname $local_guest_image`";
                # It took 14s to download vm disk file from worker cache to SUT
                script_run("curl " . autoinst_url("/assets/other/" . get_var("ASSET_${i}1")) . " -o $local_guest_image");
                script_run "ls -l $local_guest_image";
                push @downloaded_guests, $guest;
                record_info("$guest downloaded", "$guest_asset_name");
            }
        }
        record_info('Softfail', "$guest_asset_name not found!", result => 'softfail') unless grep $guest, @downloaded_guests;
    }

    record_info("Downloaded guests", "@downloaded_guests") if @downloaded_guests;
    return @downloaded_guests;
}

sub is_installed_equal_upgrade_major_release {
    #get the version that the host is installed to
    my $host_installed_version = get_var('VERSION_TO_INSTALL', get_var('VERSION', ''));    #format 15 or 15-SP1
    ($host_installed_version) = $host_installed_version =~ /^(\d+)/;
    #get the version that the host should upgrade to
    my $host_upgrade_version = get_var('UPGRADE_PRODUCT', 'sles-1-sp0');    #format sles-15-sp0
    ($host_upgrade_version) = $host_upgrade_version =~ /sles-(\d+)-sp/i;
    return $host_installed_version eq $host_upgrade_version;
}

#Generate XML to be consumed by junit log utilities
sub generateXML_from_data {
    my ($tc_data, $data) = @_;

    my %my_hash = %$tc_data;
    my %xmldata = %$data;
    my $writer = XML::Writer->new(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => 'self');
    #Initialize undefined counters to zero
    my @tc_status_counters = ('pass', 'fail', 'skip', 'softfail', 'timeout', 'unknown');
    foreach (@tc_status_counters) {
        $xmldata{"$_" . "_nums"} = 0 if (!defined $xmldata{"$_" . "_nums"});
    }
    my $count = $xmldata{"pass_nums"} + $xmldata{"fail_nums"} + $xmldata{"skip_nums"} + $xmldata{"softfail_nums"} + $xmldata{"timeout_nums"} + $xmldata{"unknown_nums"};
    my $timestamp = localtime(time);
    $writer->startTag(
        'testsuites',
        id => "0",
        error => "n/a",
        failures => $xmldata{"fail_nums"},
        softfailures => $xmldata{"softfail_nums"},
        name => $xmldata{"product_name"},
        skipped => $xmldata{"skip_nums"},
        tests => "$count",
        time => $xmldata{"test_time"}
    );
    $writer->startTag(
        'testsuite',
        id => "0",
        error => "n/a",
        failures => $xmldata{"fail_nums"},
        softfailures => $xmldata{"softfail_nums"},
        hostname => hostname(),
        name => $xmldata{"product_tested_on"},
        package => $xmldata{"package_name"},
        skipped => $xmldata{"skip_nums"},
        tests => $count,
        time => $xmldata{"test_time"},
        timestamp => $timestamp
    );

    #Generate testcase xml by calling subroutine generate_testcase_xml
    foreach my $item (keys %my_hash) {
        #Testsuite in JUnit XML uses completely different set of status representation, which are success, failure, skipped and etc.
        #So we need to do mapping here to convert testcase status to JUnit language
        my $case_status = "";
        my %item_status_hash = (passed => "success", failed => "failure", skipped => "skipped", softfailed => "softfail", timeout => "timeout_exceeded", unknown => "unknown");
        #The legacy test scenarios like guest_installation_run takes this 'if' branch path
        if (defined $my_hash{$item}->{status}) {
            my $item_status = $my_hash{$item}->{status};
            my $item_status_key = first { /^$item_status/i } (keys %item_status_hash);
            if ($item_status_hash{$item_status_key} =~ /SKIPPED/im && $item =~ m/iso/) {
                $case_status = 'skipped';
            }
            else {
                $case_status = $item_status_hash{$item_status_key};
                $case_status = 'failure' if $case_status eq 'skipped';
            }
            $my_hash{$item}->{status} = $case_status;
            $my_hash{$item}->{guest} = $item;
            generate_testcase_xml($writer, $item, $my_hash{$item});
        }
        #The newly developed feature test takes this 'else' branch path
        else {
            foreach my $subitem (keys %{$my_hash{$item}}) {
                my $subitem_status = $my_hash{$item}->{$subitem}->{status};
                my $subitem_status_key = first { /^$subitem_status/i } (keys %item_status_hash);
                my $case_status = $item_status_hash{$subitem_status_key};
                $my_hash{$item}->{$subitem}->{status} = $case_status;
                $my_hash{$item}->{$subitem}->{guest} = $item;
                generate_testcase_xml($writer, $subitem, $my_hash{$item}->{$subitem});
            }
        }
    }
    $writer->endTag('testsuite');
    $writer->endTag('testsuites');
    $writer->end();
    $writer->to_string();

    return $writer;
}

#Generate individual testcase xml to be the part of entire JUnit log
sub generate_testcase_xml {
    my ($xml_writer, $testcase, $testinfo) = @_;

    my $testcase_time = eval { $testinfo->{test_time} ? $testinfo->{test_time} : 'n/a' };
    my $testerror = eval { $testinfo->{error} ? $testinfo->{error} : 'n/a' };
    my $testoutput = eval { $testinfo->{output} ? $testinfo->{output} : 'n/a' };
    my $testcase_status = $testinfo->{status};
    my $testguest = $testinfo->{guest};
    $xml_writer->startTag(
        'testcase',
        classname => $testcase,
        name => $testcase,
        status => $testcase_status,
        time => $testcase_time);
    $xml_writer->startTag('system-err');
    $xml_writer->characters($testerror);
    $xml_writer->endTag('system-err');
    $xml_writer->startTag('system-out');
    $xml_writer->characters("$testoutput" . " time cost: $testcase_time");
    $xml_writer->endTag('system-out');
    $xml_writer->dataElement(failure => "affected subject: $testguest") unless $testcase_status eq 'success';
    $xml_writer->endTag('testcase');
}

#RAW do not support Snapshot, so skip Snapshot test if guest disk type as RAW
sub check_guest_disk_type {
    my $guest = shift;
    my $guest_disk_type = script_output("virsh dumpxml $guest | grep \"<driver \" | grep -o \"type='.*'\" | cut -d \"'\" -f2 | tail -n1");
    if ($guest_disk_type =~ /raw/) {
        record_info "INFO", "SKIP Snapshot test if guest disk type as $guest_disk_type";
        return 1;
    }
    else {
        if ($guest_disk_type =~ /qcow2/) {
            record_info "INFO", "Start Snapshot test with the guest disk type as $guest_disk_type";
            return 0;
        }
    }
}

#Perform restart operation on desired guests of local or remote host
#User should check guest status as expected in his/her customized and
#suitable way after restart if there are associated specific concerns
#guest_to_restart argument is reference to array of desired guest domains
#wait_script argument is timeout to wait for execution to complete
#host_addr argument takes format in ip address or fqdn as host address
#For example, $host_ip = "10.12.13.14"; @guest_name = ('guest1', 'guest2');
#Call this subroutine by using perform_guest_restart(\@guest_name, 90, $host_ip);
#All these arguments can be left empty which means all guests, 120s and local host
sub perform_guest_restart {
    my ($guest_to_restart, $wait_script, $host_addr) = @_;
    my $connect_uri = "";
    my @guest_restart_array = ();
    $connect_uri = "-c qemu+ssh://root\@$host_addr/system" if ((defined $host_addr) && ($host_addr ne ''));
    @guest_restart_array = @$guest_to_restart if ((defined $guest_to_restart) && ($guest_to_restart ne ''));
    $wait_script = "120" if ((!defined $wait_script) || ($wait_script eq ''));
    my $guest_types = "sles|win";
    my $get_guest_domains = "virsh $connect_uri list --all | grep -E \"${guest_types}\" | awk \'{print \$2}\'";
    my $guest_domains = script_output($get_guest_domains, $wait_script, type_command => 0, proceed_on_failure => 0);
    my @guest_domains_array = split(/\n+/, $guest_domains);
    if (scalar(@guest_restart_array) == 0) {
        script_run "virsh $connect_uri destroy $_", $wait_script foreach (@guest_domains_array);
        script_run "virsh $connect_uri start $_", $wait_script foreach (@guest_domains_array);
    }
    else {
        foreach my $guest (@guest_restart_array) {
            if (grep { $_ eq $guest } @guest_domains_array) {
                script_run "virsh $connect_uri destroy $guest", $wait_script;
                script_run "virsh $connect_uri start $guest", $wait_script;
            }
            else {
                record_info("Guest missing", "Guest $guest does not exist");
                diag("Guest $guest does not exist");
            }
        }
    }
}

#This subroutine collects desired logs from host and guest, and place them into folder /tmp/virt_logs_residence on host then compress it to /tmp/virt_logs_all.tar.gz
#Please refer to virt_logs_collector.sh and fetch_logs_from_guest.sh in data/virt_autotest for their detailed functionality, implementation and usage
sub collect_host_and_guest_logs {
    my %args = @_;
    $args{guest} //= '';
    $args{extra_host_log} //= '';
    $args{extra_guest_log} //= '';
    $args{full_supportconfig} //= 1;
    $args{token} //= '';
    $args{keep} //= 'false';
    $args{timeout} //= 3600;

    $args{full_supportconfig} = ($args{full_supportconfig} ? 'true' : 'false');
    my $logs_collector_script_url = data_url("virt_autotest/virt_logs_collector.sh");
    script_output("curl -s -o ~/virt_logs_collector.sh $logs_collector_script_url", timeout => 180, type_command => 0, proceed_on_failure => 0);
    save_screenshot;
    script_output("chmod +x ~/virt_logs_collector.sh && ~/virt_logs_collector.sh -l \"$args{extra_host_log}\" -g \"$args{guest}\" -e \"$args{extra_guest_log}\" -a \"$args{full_supportconfig}\"", timeout => $args{timeout}, type_command => 1, proceed_on_failure => 1);
    save_screenshot;

    send_key("ret");
    my $logs_fetching_script_url = data_url("virt_autotest/fetch_logs_from_guest.sh");
    script_output("curl -s -o ~/fetch_logs_from_guest.sh $logs_fetching_script_url", 180, type_command => 0, proceed_on_failure => 0);
    save_screenshot;
    script_output("chmod +x ~/fetch_logs_from_guest.sh && ~/fetch_logs_from_guest.sh -g \"$args{guest}\" -e \"$args{extra_guest_log}\"", timeout => $args{timeout}, type_command => 1, proceed_on_failure => 1);
    save_screenshot;

    send_key("ret");
    upload_logs("/tmp/virt_logs_all.tar.gz", log_name => "virt_logs_all$args{token}.tar.gz", timeout => 600);
    upload_logs("/var/log/virt_logs_collector.log", log_name => "virt_logs_collector$args{token}.log");
    upload_logs("/var/log/fetch_logs_from_guest.log", log_name => "fetch_logs_from_guest$args{token}.log");
    save_screenshot;
    script_run("rm -f -r /tmp/virt_logs_all.tar.gz /var/log/virt_logs_collector.log /var/log/fetch_logs_from_guest.log") if ($args{keep} eq 'false');
    save_screenshot;
}

#The script clean_up_virt_logs.sh records its output in /var/log/clean_up_virt_logs.log, you can choose to upload it when necessary
#Please refer to clean_up_virt_logs.sh data/virt_autotest for its detailed functionality, implementation and usage
sub cleanup_host_and_guest_logs {
    my ($extra_logs_to_cleanup) = @_;
    $extra_logs_to_cleanup //= '';

    #Clean dhcpd and named services up explicity
    my ($os_running_version) = get_os_release;
    if (get_var('VIRT_AUTOTEST') and $os_running_version < 16) {
        my $bridge_name = "br123";
        if (script_run("ip link show $bridge_name") != 0) {
            script_run("brctl addbr $bridge_name;brctl setfd $bridge_name 0;ip addr add 192.168.123.1/24 dev $bridge_name;ip link set $bridge_name up");
        }
        if (!get_var('VIRT_UNIFIED_GUEST_INSTALL')) {
            my @control_operation = ('restart');
            virt_autotest::utils::manage_system_service('dhcpd', \@control_operation);
            virt_autotest::utils::manage_system_service('named', \@control_operation);
        }
    }
    my $logs_cleanup_script_url = data_url("virt_autotest/clean_up_virt_logs.sh");
    script_output("curl -s -o ~/clean_up_virt_logs.sh $logs_cleanup_script_url", 180, type_command => 0, proceed_on_failure => 0);
    save_screenshot;
    script_output("chmod +x ~/clean_up_virt_logs.sh && ~/clean_up_virt_logs.sh -l \"$extra_logs_to_cleanup\"", 1800, type_command => 1, proceed_on_failure => 1);
    save_screenshot;
}

#The script guest_console_monitor.sh records its output in /var/log/guest_console_monitor.log, you can choose to upload it when necessary
#The recorded guest console output is placed in folder /tmp/virt_logs_residence on host, you can choose to upload it separately or by calling
#collect_host_and_guest_logs. Please refer to guest_console_monitor.sh in data/virt_autotest for its detailed functionality, implementation and usage
sub monitor_guest_console {
    my ($monitor_button) = @_;
    my $monitor_option = "";

    if ($monitor_button eq "start") {
        $monitor_option = "-s";
    }
    elsif ($monitor_button eq "stop") {
        $monitor_option = "-e";
    }
    else {
        diag("Guest console monitor can only accept start or stop as options.");
        return;
    }

    my $guest_console_script_url = data_url("virt_autotest/guest_console_monitor.sh");
    script_output("curl -s -o ~/guest_console_monitor.sh $guest_console_script_url", 180, type_command => 0, proceed_on_failure => 0);
    save_screenshot;
    script_output("chmod +x ~/guest_console_monitor.sh && ~/guest_console_monitor.sh $monitor_option", 1800, type_command => 1, proceed_on_failure => 1);
    save_screenshot;
}

#Start monitoring guest console
sub start_monitor_guest_console {
    monitor_guest_console('start');
    save_screenshot;
}

#Stop monitor guest console
sub stop_monitor_guest_console {
    monitor_guest_console('stop');
    save_screenshot;
}

#Detect whether running sles is the developing version
sub is_developing_sles {
    my ($running_sles_rel, $running_sles_sp) = get_os_release;
    my $developing_sles_version = get_required_var('VERSION');
    $developing_sles_version = get_required_var('TARGET_DEVELOPING_VERSION') if get_var('REPO_0_TO_INSTALL');
    my ($developing_sles_rel) = $developing_sles_version =~ /^(\d+).*/img;
    my ($developing_sles_sp) = $developing_sles_version =~ /^.*sp(\d+)$/img;
    if ($running_sles_rel eq $developing_sles_rel && $running_sles_sp eq $developing_sles_sp) {
        return 1;
    }
    else {
        return 0;
    }
}

1;
