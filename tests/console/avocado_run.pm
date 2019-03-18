# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run avocado tests and upload results, --vt-type qemu (by default)
# Maintainer: Jozef Pupava <jpupava@suse.cz>

use base 'opensusebasetest';
use warnings;
use strict;
use testapi;
use lockapi;

sub upload_avocado_results {
    assert_script_run 'tar -czf avocado_results.tar.gz /root/avocado/job-results';
    upload_logs 'avocado_results.tar.gz';
    assert_script_run 'rm -rf /root/avocado*';
}

sub run {
    my ($self) = @_;
    my $test_group = $self->{name};
    my $tests;
    if ($test_group eq 'block_device_hotplug') {
        $tests = 'block_hotplug.data_plane.block_{scsi,virtio}.fmt_{qcow2,raw}.with_plug.with_system_reset block_hotplug.default.block_{scsi,virtio}.fmt_{qcow2,raw}.{{with,without}_plug.default,with_plug.with_{block_resize,reboot,shutdown.after_plug,shutdown.after_unplug},without_plug.with_{reboot,shutdown.after_unplug}}';
    }
    elsif ($test_group eq 'cpu') {
        $tests = 'boot_cpu_model.cpu_host qemu_cpu.cpuid.custom.{{family,model}.{NaN,out_of_range},level.NaN,stepping.{Nan,out_of_range},vendor.{empty,normal,tooshort},xlevel.Nan}.kvm.cpu_model_unset.host_cpu_vendor_unknown';
    }
    elsif ($test_group eq 'disk_image') {
        $tests = 'qemu_disk_img.{commit,commit.cache_mode,convert.{base_to_raw,base_to_qcow2,snapshot_to_qcow2},info.{backing_chain,default},snapshot}';
    }
    elsif ($test_group eq 'memory_hotplug') {
        $tests = 'hotplug_memory.{before,after}.{guest_reboot,pause_vm,vm_system_reset}.hotplug.backend_{file,ram}.policy_default.two.default hotplug_memory.after.guest_reboot.hotplug.backend_{file,ram}.policy_default.one.default hotplug_memory.during.{guest_reboot,pause_vm}.hotplug.backend_{file,ram}.policy_default.two.default';
    }
    elsif ($test_group eq 'nic_hotplug') {
        $tests = '{multi_nics_hotplug,nic_hotplug.{additional,migration,used_netdev,vhost_nic}}';
    }
    elsif ($test_group eq 'qmp') {
        $tests = 'qmp_command.qmp_{query-{kvm,mice,status,name,uuid,blockstats,vnc,block,commands,pci,events,command-line-options},pmemsave,cpu,cont,stop,device_del,block_resize,negative,human-monitor-command,netdev_del,device-list-properties} qmp_event_notification.qmp_{quit,resume,rtc_change,stop,system_{powerdown,reset},watchdog.qmp_{pause,reset,shutdown}}';
    }
    elsif ($test_group eq 'usb') {
        $tests = 'usb.usb_reboot.usb_hub.{without_usb_hub,with_usb_hub.{max_usb_hub_dev,one_usb_dev}} usb.usb_reboot.usb_{kbd,mouse,tablet}.{without_usb_hub,with_usb_hub.{max_usb_dev,one_usb_dev}}';
    }
    script_output "avocado run $tests", 6000;
    upload_avocado_results();
}

sub post_fail_hook {
    select_console('log-console');
    upload_avocado_results();
}

sub test_flags {
    return {fatal => 0};
}

1;

