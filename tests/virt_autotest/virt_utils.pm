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
use Sys::Hostname;
use File::Basename;
use testapi;
use Data::Dumper;
use XML::Writer;
use IO::File;
use List::Util 'first';
use proxymode;
use version_utils 'is_sle';

our @EXPORT
  = qw(enable_debug_logging update_guest_configurations_with_daily_build repl_addon_with_daily_build_module_in_files repl_module_in_sourcefile handle_sp_in_settings handle_sp_in_settings_with_fcs handle_sp_in_settings_with_sp0 clean_up_red_disks lpar_cmd upload_virt_logs generate_guest_asset_name get_guest_disk_name_from_guest_xml compress_single_qcow2_disk upload_supportconfig_log download_guest_assets is_installed_equal_upgrade_major_release generateXML_from_data check_guest_disk_type recreate_guests perform_guest_restart);

sub enable_debug_logging {

    # turn on debug for libvirtd
    my $libvirtd_conf_file = "/etc/libvirt/libvirtd.conf";
    if (!script_run "ls $libvirtd_conf_file") {
        script_run "sed -i '/log_level *=/{h;s/^[# ]*log_level *= *[0-9].*\$/log_level = 1/};\${x;/^\$/{s//log_level = 1/;H};x}' $libvirtd_conf_file";
        script_run "sed -i '/log_outputs *=/{h;s%^[# ]*log_outputs *=.*[0-9].*\$%log_outputs=\"1:file:/var/log/libvirt/libvirtd.log\"%};\${x;/^\$/{s%%log_outputs=\"1:file:/var/log/libvirt/libvirtd.log\"%;H};x}' $libvirtd_conf_file";
        script_run "grep -e log_level -e log_outputs $libvirtd_conf_file";
        if (is_sle('<12')) {
            script_run 'rclibvirtd restart';
        }
        else {
            script_run 'systemctl restart libvirtd';
        }
    }
    save_screenshot;

    # enable journal log with prvious reboot
    my $journald_conf_file = "/etc/systemd/journald.conf";
    if (!script_run "ls $journald_conf_file") {
        script_run "sed -i '/Storage *=/{h;s/^[# ]*Storage *=.*\$/Storage=persistent/};\${x;/^\$/{s//Storage=persistent/;H};x}' $journald_conf_file";
        script_run "grep Storage $journald_conf_file";
        script_run 'systemctl restart systemd-journald';
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

sub repl_repo_in_sourcefile {
    # Replace the daily build repo as guest installation resource in source file (like source.cn; source.de ..)
    my $verorig = "source.http.sles-" . get_version_for_daily_build_guest . "-64";
    my $veritem = check_var('ARCH', 'x86_64') ? $verorig : get_required_var('ARCH') . ".$verorig";
    if (get_var("REPO_0")) {
        my $location = '';
        if (!check_var('ARCH', 's390x')) {
            $location = script_output("perl /usr/share/qa/tools/location_detect_impl.pl", 60);
            $location =~ s/[\r\n]+$//;
        }
        else {
            #S390x LPAR just be only located at DE now.
            #No plan move S390x LPAR to the other location.
            #So, define variable location as "de" for S390x LPAR.
            $location = 'de';
        }
        my $soucefile = "/usr/share/qa/virtautolib/data/" . "sources." . "$location";
        my $newrepo   = "http://openqa.suse.de/assets/repo/" . get_var("REPO_0");
        # for sles15sp2+, install host with Online installer, while install guest with Full installer
        $newrepo =~ s/-Online-/-Full-/ if ($verorig =~ /15-sp[2-9]/i);
        my $shell_cmd
          = "if grep $veritem $soucefile >> /dev/null;then sed -i \"s#^$veritem=.*#$veritem=$newrepo#\" $soucefile;else echo \"$veritem=$newrepo\" >> $soucefile;fi";
        if (check_var('ARCH', 's390x')) {
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
    my $daily_build_module = "http://openqa.suse.de/assets/repo/";
    # for sles15sp2+, install host with Online installer, while install guest with Full installer
    if ($version =~ /15-SP[2-9]/) {
        $daily_build_module .= get_var("REPO_0") . "/Module-\\2/";
        $daily_build_module =~ s/-Online-/-Full-/;
    }
    else {
        $daily_build_module .= "SLE-${version}-Module-\\2-POOL-" . get_required_var('ARCH') . "-Build" . get_required_var('BUILD') . "-Media1/";
    }
    my $source_file = "/usr/share/qa/virtautolib/data/sources.*";
    my $command     = "sed -ri 's#^(${replaced_item}).*\$#\\1$daily_build_module#g' $source_file";
    print "Debug: the command to execute is:\n$command \n";
    if (check_var('ARCH', 's390x')) {
        lpar_cmd("$command");
        lpar_cmd("grep Module $source_file -r");
        upload_asset "/usr/share/qa/virtautolib/data/sources.de", 1, 1;
    }
    else {
        assert_script_run($command);
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
    my $file_list         = script_output("find $autoyast_root_dir -type f");
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

    my $wipe_fs_cmd      = "";
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

    my $composed_name
      = 'guest_'
      . $guest
      . '_on-host_'
      . get_required_var('DISTRI') . '-'
      . get_required_var('VERSION')
      . '_build'
      . get_required_var('BUILD') . '_'
      . lc(get_required_var('SYSTEM_ROLE')) . '_'
      . get_required_var('ARCH');

    record_info('Guest asset info', "Guest asset name is : $composed_name");

    return $composed_name;
}

sub get_guest_disk_name_from_guest_xml {
    my $guest = shift;

    # Our automation only supports single guest disk
    my $disk_from_xml = script_output("virsh dumpxml $guest | sed -n \'/disk/,/\\\/disk/p\' | grep 'source file=' | grep -v iso");
    record_info('Guest disk config from xml', "Guest $guest disk_from_xml is: $disk_from_xml.");
    $disk_from_xml =~ /file='(.*)'/;
    $disk_from_xml = $1;
    die 'There is no guest disk file parsed out from guest xml configuration!' unless $disk_from_xml;
    record_info('Guest disk name', "Guest $guest disk_from_xml is: $disk_from_xml.");

    return $disk_from_xml;
}

# Should only do compress from qcow2 disk to qcow2 in our automation(upload guest asset scheme).
sub compress_single_qcow2_disk {
    my ($orig_disk, $compressed_disk) = @_;

    if ($orig_disk =~ /qcow2/) {
        my $cmd = "nice ionice qemu-img convert -c -p -O qcow2 $orig_disk $compressed_disk";
        assert_script_run($cmd, 360);
        save_screenshot;
        record_info('Disk compression', "Disk compression done from $orig_disk to $compressed_disk.");
    }
}

sub upload_supportconfig_log {
    my $datetab = script_output("date '+%Y%m%d%H%M%S'");
    script_run("cd;supportconfig -t . -B supportconfig.$datetab", 600);
    script_run("tar zcvfP nts_supportconfig.$datetab.tar.gz nts_supportconfig.$datetab");
    upload_logs("nts_supportconfig.$datetab.tar.gz");
    script_run("rm -rf nts_supportconfig.*");
    save_screenshot;
}

# Download guest image and xml from a NFS location to local
# the image and xml is coming from a guest installation testsuite
# need set SKIP_GUEST_INSTALL=1 in the test suite settings
# only available on x86_64
sub download_guest_assets {

    # guest_pattern is a string, like sles-11-sp4-64, may or may not with pv or fv given.
    my ($guest_pattern, $vm_xml_dir) = @_;

    # list the guests matched the pattern
    my $qa_guest_config_file = "/usr/share/qa/virtautolib/data/vm_guest_config_in_vh_update";
    my $hypervisor_type      = get_var('SYSTEM_ROLE', '');
    my $install_guest_list = script_output "source /usr/share/qa/virtautolib/lib/virtlib; get_vms_from_config_file $qa_guest_config_file $guest_pattern $hypervisor_type";
    save_screenshot;
    if ($install_guest_list eq '') {
        record_soft_failure("Not found guest pattern $guest_pattern in $qa_guest_config_file");
        return 1;
    }

    # mount the remote NFS location of guest assets
    # OPENQA_URL="localhost" in local openQA instead of the IP, so the line below need to be turned on and set to the webUI IP when you are using local openQA
    # Tips: Using local openQA, you need "rcnfs-server start & vi /etc/exports; exportfs -r")
    # set_var('OPENQA_URL', "your_ip");
    my $openqa_server = get_required_var('OPENQA_URL');
    $openqa_server =~ s/^http:\/\///;
    my $remote_export_dir = "/var/lib/openqa/factory/other/";
    my $mount_point       = "/tmp/remote_guest";

    # clean up vm stuff
    script_run "[ -d $mount_point ] && { if findmnt $mount_point; then umount $mount_point; rm -rf $mount_point; fi }";
    script_run "mkdir -p $mount_point";
    script_run "[ -d $vm_xml_dir ] && rm -rf $vm_xml_dir; mkdir -p $vm_xml_dir";
    my $disk_image_dir = script_output "source /usr/share/qa/virtautolib/lib/virtlib; get_vm_disk_dir";
    script_run "umount $disk_image_dir; rm -rf $disk_image_dir";
    script_run "[ -d /tmp/prj3_guest_migration/ ] && rm -rf /tmp/prj3_guest_migration/" if get_var('VIRT_NEW_GUEST_MIGRATION_SOURCE');
    save_screenshot;

    # tip: nfs4 is not supported on sles12sp4, so use '-t nfs' instead of 'nfs4' here.
    assert_script_run("mount -t nfs $openqa_server:$remote_export_dir $mount_point", 120);
    save_screenshot;

    # copy guest images and xml files to local
    # test aborts if failing in copying all the guests
    my $remote_guest_count = 0;
    foreach my $guest (split "\n", $install_guest_list) {
        my $guest_asset           = generate_guest_asset_name("$guest");
        my $remote_guest_xml_file = $guest_asset . '.xml';
        my $remote_guest_disk     = $guest_asset . '.disk';

        # download vm xml file
        my $rc = script_run("cp $mount_point/$remote_guest_xml_file $vm_xml_dir/$guest.xml", 60);
        save_screenshot;
        if ($rc) {
            record_soft_failure("Failed copying: $mount_point/$remote_guest_xml_file");
            next;
        }
        script_run("ls -l $vm_xml_dir", 10);
        save_screenshot;

        # download vm disk files
        my $local_guest_image = script_output "grep '<source file=' $vm_xml_dir/$guest.xml | sed \"s/^\\s*<source file='\\([^']*\\)'.*\$/\\1/\"";
        # put the downloded xml and disk files in the backup dir directory
        # in case of being flushed up by the NFS workaround from dst job
        if (get_var('VIRT_NEW_GUEST_MIGRATION_SOURCE')) {
            my $backupRootDir   = "/tmp/prj3_guest_migration/vm_backup";
            my $backupCfgXmlDir = "$backupRootDir/vm-config-xmls";
            my $backupDiskDir   = "$backupRootDir/vm-disk-files";
            script_run "mkdir -p $backupCfgXmlDir; mkdir -p $backupDiskDir";
            script_run "cp $vm_xml_dir/$guest.xml $backupCfgXmlDir";
            script_run "ls -l $backupCfgXmlDir";
            $local_guest_image = $backupDiskDir . $local_guest_image;
        }
        script_run "[ -d `dirname $local_guest_image` ] || mkdir -p `dirname $local_guest_image`";
        $rc = script_run("cp $mount_point/$remote_guest_disk $local_guest_image", 300);    #it took 75 seconds copy from vh016 to vh001
        script_run "ls -l $local_guest_image";
        save_screenshot;
        if ($rc) {
            record_soft_failure("Failed to download: $remote_guest_disk");
            next;
        }
        $remote_guest_count++;
    }

    # umount
    script_run("umount $mount_point");
    save_screenshot;

    return 1 if ($remote_guest_count == 0);
}

sub is_installed_equal_upgrade_major_release {
    #get the version that the host is installed to
    my $host_installed_version = get_var('VERSION_TO_INSTALL', get_var('VERSION', ''));    #format 15 or 15-SP1
    ($host_installed_version) = $host_installed_version =~ /^(\d+)/;
    #get the version that the host should upgrade to
    my $host_upgrade_version = get_var('UPGRADE_PRODUCT', 'sles-1-sp0');                   #format sles-15-sp0
    ($host_upgrade_version) = $host_upgrade_version =~ /sles-(\d+)-sp/i;
    return $host_installed_version eq $host_upgrade_version;
}

#Generate XML to be consumed by junit log utilities
sub generateXML_from_data {
    my ($tc_data, $data) = @_;

    my %my_hash = %$tc_data;
    my %xmldata = %$data;
    my $writer  = XML::Writer->new(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => 'self');
    #Initialize undefined counters to zero
    my @tc_status_counters = ('pass', 'fail', 'skip', 'softfail', 'timeout', 'unknown');
    foreach (@tc_status_counters) {
        $xmldata{"$_" . "_nums"} = 0 if (!defined $xmldata{"$_" . "_nums"});
    }
    my $count = $xmldata{"pass_nums"} + $xmldata{"fail_nums"} + $xmldata{"skip_nums"} + $xmldata{"softfail_nums"} + $xmldata{"timeout_nums"} + $xmldata{"unknown_nums"};
    my $timestamp = localtime(time);
    $writer->startTag(
        'testsuites',
        id           => "0",
        error        => "n/a",
        failures     => $xmldata{"fail_nums"},
        softfailures => $xmldata{"softfail_nums"},
        name         => $xmldata{"product_name"},
        skipped      => $xmldata{"skip_nums"},
        tests        => "$count",
        time         => $xmldata{"test_time"}
    );
    $writer->startTag(
        'testsuite',
        id           => "0",
        error        => "n/a",
        failures     => $xmldata{"fail_nums"},
        softfailures => $xmldata{"softfail_nums"},
        hostname     => hostname(),
        name         => $xmldata{"product_tested_on"},
        package      => $xmldata{"package_name"},
        skipped      => $xmldata{"skip_nums"},
        tests        => $count,
        time         => $xmldata{"test_time"},
        timestamp    => $timestamp
    );

    #Generate testcase xml by calling subroutine generate_testcase_xml
    foreach my $item (keys %my_hash) {
        #Testsuite in JUnit XML uses completely different set of status representation, which are success, failure, skipped and etc.
        #So we need to do mapping here to convert testcase status to JUnit language
        my $case_status = "";
        my %item_status_hash = (passed => "success", failed => "failure", skipped => "skipped", softfailed => "softfail", timeout => "timeout_exceeded", unknown => "unknown");
        #The legacy test scenarios like guest_installation_run takes this 'if' branch path
        if (defined $my_hash{$item}->{status}) {
            my $item_status     = $my_hash{$item}->{status};
            my $item_status_key = first { /^$item_status/i } (keys %item_status_hash);
            if ($item_status_hash{$item_status_key} =~ /SKIPPED/im && $item =~ m/iso/) {
                $case_status = 'skipped';
            }
            else {
                $case_status = $item_status_hash{$item_status_key};
                $case_status = 'failure' if $case_status eq 'skipped';
            }
            $my_hash{$item}->{status} = $case_status;
            $my_hash{$item}->{guest}  = $item;
            generate_testcase_xml($writer, $item, $my_hash{$item});
        }
        #The newly developed feature test takes this 'else' branch path
        else {
            foreach my $subitem (keys %{$my_hash{$item}}) {
                my $subitem_status     = $my_hash{$item}->{$subitem}->{status};
                my $subitem_status_key = first { /^$subitem_status/i } (keys %item_status_hash);
                my $case_status        = $item_status_hash{$subitem_status_key};
                $my_hash{$item}->{$subitem}->{status} = $case_status;
                $my_hash{$item}->{$subitem}->{guest}  = $item;
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
    my $testerror     = eval { $testinfo->{error}     ? $testinfo->{error}     : 'n/a' };
    my $testoutput    = eval { $testinfo->{output}    ? $testinfo->{output}    : 'n/a' };
    my $testcase_status = $testinfo->{status};
    my $testguest       = $testinfo->{guest};
    $xml_writer->startTag(
        'testcase',
        classname => $testcase,
        name      => $testcase,
        status    => $testcase_status,
        time      => $testcase_time);
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
    my $guest           = shift;
    my $guest_disk_type = script_output("virsh dumpxml $guest | grep \"<driver \" | grep -o \"type='.*'\" | cut -d \"'\" -f2");
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
    my $get_vm_hostnames   = "virsh list  --all | grep sles | awk \'{print \$2}\'";
    my $vm_hostnames       = script_output($get_vm_hostnames, 30, type_command => 0, proceed_on_failure => 0);
    my @vm_hostnames_array = split(/\n+/, $vm_hostnames);
    foreach (@vm_hostnames_array)
    {
        script_run("virsh destroy $_");
        script_run("virsh undefine $_");
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
    my $connect_uri         = "";
    my @guest_restart_array = ();
    $connect_uri         = "-c qemu+ssh://root\@$host_addr/system" if ((defined $host_addr)        && ($host_addr ne ''));
    @guest_restart_array = @$guest_to_restart                      if ((defined $guest_to_restart) && ($guest_to_restart ne ''));
    $wait_script = "120" if ((!defined $wait_script) || ($wait_script eq ''));
    my $guest_types         = "sles|win";
    my $get_guest_domains   = "virsh $connect_uri list --all | grep -E \"${guest_types}\" | awk \'{print \$2}\'";
    my $guest_domains       = script_output($get_guest_domains, $wait_script, type_command => 0, proceed_on_failure => 0);
    my @guest_domains_array = split(/\n+/, $guest_domains);
    if (scalar(@guest_restart_array) == 0) {
        script_run "virsh $connect_uri destroy $_", $wait_script foreach (@guest_domains_array);
        script_run "virsh $connect_uri start $_",   $wait_script foreach (@guest_domains_array);
    }
    else {
        foreach my $guest (@guest_restart_array) {
            if (grep { $_ eq $guest } @guest_domains_array) {
                script_run "virsh $connect_uri destroy $guest", $wait_script;
                script_run "virsh $connect_uri start $guest",   $wait_script;
            }
            else {
                record_info("Guest missing", "Guest $guest does not exist");
                diag("Guest $guest does not exist");
            }
        }
    }
}

1;
