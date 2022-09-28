# SUSE's openQA tests
#
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
package virt_utils;
# Summary: virt_utils: The initial version of virtualization automation test in openqa.
#          This file provides fundamental utilities.
# Maintainer: alice <xlai@suse.com>

use base Exporter;
use Exporter;
use strict;
use warnings;
use Sys::Hostname;
use File::Basename;
use testapi;
use Utils::Architectures;
use Data::Dumper;
use XML::Writer;
use IO::File;
use List::Util 'first';
use LWP::Simple 'head';
use proxymode;
use version_utils 'is_sle';
use virt_autotest::utils;
use version_utils qw(is_sle get_os_release);

our @EXPORT
  = qw(enable_debug_logging update_guest_configurations_with_daily_build locate_sourcefile get_repo_0_prefix repl_repo_in_sourcefile repl_addon_with_daily_build_module_in_files repl_module_in_sourcefile handle_sp_in_settings handle_sp_in_settings_with_fcs handle_sp_in_settings_with_sp0 clean_up_red_disks lpar_cmd upload_virt_logs generate_guest_asset_name get_guest_disk_name_from_guest_xml compress_single_qcow2_disk get_guest_list remove_vm download_guest_assets restore_downloaded_guests is_installed_equal_upgrade_major_release generateXML_from_data check_guest_disk_type recreate_guests perform_guest_restart collect_host_and_guest_logs cleanup_host_and_guest_logs monitor_guest_console start_monitor_guest_console stop_monitor_guest_console is_developing_sles is_registered_sles);

sub enable_debug_logging {

    #turn on debug and log filter for libvirtd
    #set log_level = 1 'debug'
    #the size of libvirtd with debug level and without any filter on sles15sp3 xen is over 100G,
    #which consumes all the disk space. Now get comfirmation from virt developers,
    #log filter is set to store component logs with different levels.
    my $libvirtd_conf_file = "/etc/libvirt/libvirtd.conf";
    if (!script_run "ls $libvirtd_conf_file") {
        script_run "sed -i '/^[# ]*log_level *=/{h;s/^[# ]*log_level *= *[0-9].*\$/log_level = 1/};\${x;/^\$/{s//log_level = 1/;H};x}' $libvirtd_conf_file";
        script_run "sed -i '/^[# ]*log_outputs *=/{h;s%^[# ]*log_outputs *=.*[0-9].*\$%log_outputs=\"1:file:/var/log/libvirt/libvirtd.log\"%};\${x;/^\$/{s%%log_outputs=\"1:file:/var/log/libvirt/libvirtd.log\"%;H};x}' $libvirtd_conf_file";
        script_run "sed -i '/^[# ]*log_filters *=/{h;s%^[# ]*log_filters *=.*[0-9].*\$%log_filters=\"1:qemu 1:libvirt 4:object 4:json 4:event 3:util 1:util.pci\"%};\${x;/^\$/{s%%log_filters=\"1:qemu 1:libvirt 4:object 4:json 4:event 3:util 1:util.pci\"%;H};x}' $libvirtd_conf_file";
        script_run "grep -e log_level -e log_outputs -e log_filters $libvirtd_conf_file";
    }
    save_screenshot;

    # enable journal log with prvious reboot
    my $journald_conf_file = "/etc/systemd/journald.conf";
    if (!script_run "ls $journald_conf_file") {
        script_run "sed -i '/^[# ]*Storage *=/{h;s/^[# ]*Storage *=.*\$/Storage=persistent/};\${x;/^\$/{s//Storage=persistent/;H};x}' $journald_conf_file";
        script_run "grep Storage $journald_conf_file";
        script_run 'systemctl restart systemd-journald';
    }
    save_screenshot;

    # enable qemu core dumps
    my $qemu_conf_file = "/etc/libvirt/qemu.conf";
    if (!script_run "ls $qemu_conf_file") {
        script_run "sed -i '/max_core *=/{h;s/^[# ]*max_core *=.*\$/max_core = \"unlimited\"/};\${x;/^\$/{s//max_core = \"unlimited\"/;H};x}' $qemu_conf_file";
        script_run "grep max_core $qemu_conf_file";
    }
    save_screenshot;

    #restart libvirtd to make debug level and coredump take effect
    if (is_sle('<12')) {
        script_run 'rclibvirtd restart';
    }
    else {
        script_run 'systemctl restart libvirtd';
    }
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
    my $location = script_output("perl /usr/share/qa/tools/location_detect_impl.pl", 60);
    $location =~ s/[\r\n]+$//;
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
        my $location = '';
        if (!is_s390x) {
            $location = locate_sourcefile;
        }
        else {
            #S390x LPAR just be only located at DE now.
            #No plan move S390x LPAR to the other location.
            #So, define variable location as "de" for S390x LPAR.
            $location = 'de';
        }
        my $soucefile = "/usr/share/qa/virtautolib/data/" . "sources." . "$location";
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
    die 'Command not provided' unless $cmd;

    $args->{ignore_return_code} ||= 0;
    my $ret = console('svirt')->run_cmd($cmd);
    if ($ret == 0) {
        record_info('INFO', "Command $cmd run on S390X LPAR: SUCESS");
    }
    unless ($args->{ignore_return_code} || !$ret) {
        record_info('INFO', "Command $cmd run on S390X LPAR: FAIL");
        die 'Find new failure, please check manually';
    }
}

sub upload_virt_logs {
    my ($log_dir, $compressed_log_name) = @_;

    my $full_compressed_log_name = "/tmp/$compressed_log_name.tar.gz";
    script_run("tar -czf $full_compressed_log_name $log_dir; rm $log_dir -r", 60);
    save_screenshot;
    upload_logs "$full_compressed_log_name";
    save_screenshot;
}

# Guest xml will be uploaded with name format [generated_name_by_this_func].xml
# Guest disk will be uploaded with name format [generated_name_by_this_func].disk
# When reusing these assets, needs to recover the names to original by reverting this process
sub generate_guest_asset_name {
    my $guest = shift;

    #get build number
    my $build_num;
    #for clone job, get build number from SCC proxy which is set in Media
    if (get_var('CASEDIR')) {
        get_var('SCC_URL') =~ /^http.*all-([\d\.]*)\.proxy\.*/;
        $build_num = $1;
    }
    else {
        $build_num = get_required_var('BUILD');
    }

    my $composed_name
      = 'guest_'
      . $guest
      . '_on-host_'
      . get_required_var('DISTRI') . '-'
      . get_required_var('VERSION')
      . '_build'
      . $build_num . '_'
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

    if ($orig_disk =~ /qcow2/) {
        my $cmd = "nice ionice qemu-img convert -c -p -O qcow2 $orig_disk $compressed_disk";
        if (script_run($cmd, 360) ne 0) {
            $cmd = "nice ionice qemu-img convert --force-share -c -p -O qcow2 $orig_disk $compressed_disk";
            die("Disk compression failed from $orig_disk to $compressed_disk.") if (script_run($cmd, 360) ne 0);
        }
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
    record_info("Not found guest pattern $guest_pattern in $qa_guest_config_file", result => 'softfail') if ($guest_list eq '');
    return $guest_list;
}

# remove a vm listed via 'virsh list'
sub remove_vm {
    my $vm = shift;
    my $is_persistent_vm = script_output "virsh dominfo $vm | sed -n '/Persistent:/p' | awk '{print \$2}'";
    my $vm_state = script_output "virsh domstate $vm";
    if ($vm_state ne "shut off") {
        assert_script_run("virsh destroy $vm", 30);
    }
    if ($is_persistent_vm eq "yes") {
        assert_script_run("virsh undefine $vm || virsh undefine $vm --keep-nvram", 30);
    }
}

# Download guest image and xml from a NFS location to local
# the image and xml is coming from a guest installation testsuite
# need set SKIP_GUEST_INSTALL=1 in the test suite settings
# return the account of the guests downloaded
# only available on x86_64
sub download_guest_assets {

    # guest_pattern is a string, like sles-11-sp4-64, may or may not with pv or fv given.
    my ($expected_guests, $vm_xml_dir) = @_;

    # mount the remote NFS location of guest assets
    # OPENQA_URL="localhost" in local openQA instead of the IP, so the line below need to be turned on and set to the webUI IP when you are using local openQA
    # Tips: Using local openQA, you need "rcnfs-server start & vi /etc/exports; exportfs -r")
    # set OPENQA_URL="your_ip" on openQA web UI
    my $openqa_server = get_required_var('OPENQA_URL');

    # check if vm xml files have been uploaded
    my @available_guests = ();
    foreach my $guest (split "\n", $expected_guests) {
        my $guest_asset = generate_guest_asset_name("$guest");
        my $vm_disk_url = $openqa_server . "/assets/other/" . $guest_asset . '.disk';
        $vm_disk_url =~ s#^(?!http://)(.*)$#http://$1#;    #add 'http://' at beginning if needed.
        if (head($vm_disk_url)) {
            push @available_guests, $guest;
        }
        else {
            record_info("$vm_disk_url not found!", result => 'softfail');
        }
    }
    return 0 unless @available_guests;

    # clean up vm stuff
    my $mount_point = "/tmp/remote_guest";
    script_run "[ -d $mount_point ] && { if findmnt $mount_point; then umount $mount_point; rm -rf $mount_point; fi }";
    script_run "mkdir -p $mount_point";
    script_run "[ -d $vm_xml_dir ] && rm -rf $vm_xml_dir; mkdir -p $vm_xml_dir";
    my $disk_image_dir = script_output "source /usr/share/qa/virtautolib/lib/virtlib; get_vm_disk_dir";
    script_run "umount $disk_image_dir; rm -rf $disk_image_dir/*";
    script_run "[ -d /tmp/prj3_guest_migration/ ] && rm -rf /tmp/prj3_guest_migration/" if get_var('VIRT_NEW_GUEST_MIGRATION_SOURCE');

    # tip: nfs4 is not supported on sles12sp4, so use '-t nfs' instead of 'nfs4' here.
    $openqa_server =~ s/^http:\/\///;
    my $remote_export_dir = "/var/lib/openqa/factory/other/";
    assert_script_run("mount -t nfs $openqa_server:$remote_export_dir $mount_point", 120);

    # copy guest images and xml files to local
    # test aborts if failing in copying all the guests
    my $guest_count = 0;
    foreach my $guest (@available_guests) {
        my $guest_asset = generate_guest_asset_name("$guest");
        my $remote_guest_xml_file = $guest_asset . '.xml';
        my $remote_guest_disk = $guest_asset . '.disk';

        # download vm xml file
        my $rc = script_run("cp $mount_point/$remote_guest_xml_file $vm_xml_dir/$guest.xml", 60);
        if ($rc) {
            record_info("Failed copying: $mount_point/$remote_guest_xml_file", result => 'softfail');
            next;
        }
        script_run("ls -l $vm_xml_dir", 10);
        save_screenshot;

        # download vm disk files
        my $local_guest_image = script_output "grep '<source file=' $vm_xml_dir/$guest.xml | sed \"s/^\\s*<source file='\\([^']*\\)'.*\$/\\1/\"";
        # put the downloded xml and disk files in the backup dir directory
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
        $rc = script_run("cp $mount_point/$remote_guest_disk $local_guest_image", 300);    #it took 75 seconds copy from vh016 to vh001
        script_run "ls -l $local_guest_image";
        if ($rc) {
            record_info("Failed to download: $remote_guest_disk", result => 'softfail');
            next;
        }
        $guest_count++;
    }

    # umount
    script_run("umount $mount_point");

    return $guest_count;
}

#Start the guest from the downloaded vm xml and vm disk file
sub restore_downloaded_guests {
    my ($guest, $vm_xml_dir) = @_;
    record_info("Guest restored", "$guest");
    my $vm_xml = "$vm_xml_dir/$guest.xml";
    assert_script_run("virsh define $vm_xml", 30);
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

#recreate all defined guests
sub recreate_guests {
    my $based_guest_dir = shift;
    return if get_var('INCIDENT_ID');    # QAM does not recreate guests every time
    my $get_vm_hostnames = "virsh list  --all | grep -e sles -e opensuse | awk \'{print \$2}\'";
    my $vm_hostnames = script_output($get_vm_hostnames, 30, type_command => 0, proceed_on_failure => 0);
    my @vm_hostnames_array = split(/\n+/, $vm_hostnames);
    foreach (@vm_hostnames_array)
    {
        script_run("virsh destroy $_");
        script_run("virsh undefine $_ || virsh undefine $_ --keep-nvram");
        script_run("virsh define /$based_guest_dir/$_.xml");
        script_run("virsh start $_");
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
    my ($guest_wanted, $host_extra_logs, $guest_extra_logs) = @_;
    $guest_wanted //= '';
    $host_extra_logs //= '';
    $guest_extra_logs //= '';

    my $logs_collector_script_url = data_url("virt_autotest/virt_logs_collector.sh");
    script_output("curl -s -o ~/virt_logs_collector.sh $logs_collector_script_url", 180, type_command => 0, proceed_on_failure => 0);
    save_screenshot;
    script_output("chmod +x ~/virt_logs_collector.sh && ~/virt_logs_collector.sh -l \"$host_extra_logs\" -g \"$guest_wanted\" -e \"$guest_extra_logs\"", 3600 / get_var('TIMEOUT_SCALE', 1), type_command => 1, proceed_on_failure => 1);
    save_screenshot;

    my $logs_fetching_script_url = data_url("virt_autotest/fetch_logs_from_guest.sh");
    script_output("curl -s -o ~/fetch_logs_from_guest.sh $logs_fetching_script_url", 180, type_command => 0, proceed_on_failure => 0);
    save_screenshot;
    script_output("chmod +x ~/fetch_logs_from_guest.sh && ~/fetch_logs_from_guest.sh -g \"$guest_wanted\" -e \"$guest_extra_logs\"", 1800, type_command => 1, proceed_on_failure => 1);
    save_screenshot;

    upload_logs("/tmp/virt_logs_all.tar.gz");
    upload_logs("/var/log/virt_logs_collector.log");
    upload_logs("/var/log/fetch_logs_from_guest.log");
    save_screenshot;
    script_run("rm -f -r /tmp/virt_logs_all.tar.gz /var/log/virt_logs_collector.log /var/log/fetch_logs_from_guest.log");
    save_screenshot;
}

#The script clean_up_virt_logs.sh records its output in /var/log/clean_up_virt_logs.log, you can choose to upload it when necessary
#Please refer to clean_up_virt_logs.sh data/virt_autotest for its detailed functionality, implementation and usage
sub cleanup_host_and_guest_logs {
    my ($extra_logs_to_cleanup) = @_;
    $extra_logs_to_cleanup //= '';

    #Clean dhcpd and named services up explicity
    if (get_var('VIRT_AUTOTEST')) {
        script_run("brctl addbr br123;brctl setfd br123 0;ip addr add 192.168.123.1/24 dev br123;ip link set br123 up");
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

#Detect whether SUT host is installed with scc registration
sub is_registered_sles {
    if (!get_var('SCC_REGISTER') || check_var('SCC_REGISTER', 'none') || check_var('SCC_REGISTER', '')) {
        return 0;
    }
    else {
        return 1;
    }
}

1;
