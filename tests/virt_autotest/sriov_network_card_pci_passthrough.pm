# SUSE's openQA tests

# Copyright (C) 2020 SUSE LLC
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
#
# Summary: A test to pass SR-IOV Ethernet VFs to guest via libvirt. Both KVM & XEN hosts are supported.
# Test environment: one or more Ethernet card with SR-IOV features in host machine as a secondary network card;
#                   hvm or pv domains defined in the host, and they are ssh accessible from host.
# Test flow:
#    - search the SR-IOV Ethernet cards installed in host.
#    - enable 8 vfs for each of them. 8 is set fixed, other values work as well.
#    - choose one of the vfs randomly and pass it thru to the domain.
#    - choose another vf randomly and pass it thru to the domain. Set $passthru_vf_count to other values in case you'd like to pass thru more vfs.
#    - reboot the domain.
#    - unplug the first vf from domain; then unplug all the others.
#    - for each of the plugging/unplugging step above, check domain network status and host&guest status.
# Maintainer: Julie CAO <JCao@suse.com>

use base "virt_feature_test_base";
use strict;
use warnings;
use utils;
use testapi;
use xen;
use set_config_as_glue;
use virt_autotest::utils;
use virt_autotest::virtual_network_utils qw(save_guest_ip test_network_interface);
use virt_utils qw(upload_virt_logs);

sub run_test {
    my $self = shift;

    #set up ssh, packages and iommu on host
    prepare_host();

    #clean up test logs
    my $log_dir = "/tmp/sriov_pcipassthru";
    script_run "[ -d $log_dir ] && rm -rf $log_dir; mkdir -p $log_dir";

    #get the SR-IOV device BDF and interface
    my @host_pfs;
    @host_pfs = find_sriov_ethernet_devices();
    if (@host_pfs == ()) {
        $self->{test_results}->{host}->{"Error: there is no SR-IOV ethernet devices in the host!"}->{status} = 'FAILED';
        return 1;
    }
    record_info("Find SR-IOV devices", "@host_pfs");

    #get/set nessisary variables for test
    my $gateway = script_output "ip r s | grep 'default via' | cut -d ' ' -f3";
    set_var("SRIOV_NETWORK_CARD_PCI_PASSSHTROUGH", 1);    #to differenciate virtual network tests

    # enable 8 vfs for the SR-IOV device on host
    my @host_vfs = enable_vf(@host_pfs);
    record_info("VFs enabled", "@host_vfs");

    foreach my $guest (keys %xen::guests) {

        record_info("Test $guest");
        prepare_guest($guest);
        save_network_device_status_logs($log_dir, $guest, "1-initial");

        #passthrough 2 vf ethernet devices from host
        my @vfs               = ();
        my $passthru_vf_count = 2;    #the number of vfs to be passed through to guests
        for (my $i = 0; $i < $passthru_vf_count; $i++) {

            my %vf;

            #detach the vf from host
            $vf{host_bdf} = $host_vfs[int(rand($#host_vfs + 1))];
            for (my $j = 0; $j < $i; $j++) {
                if ($vf{host_bdf} eq $vfs[$j]->{host_bdf}) {
                    $vf{host_bdf} = $host_vfs[int(rand($#host_vfs + 1))];
                    $j = 0;
                }
            }
            $vf{host_id} = detach_vf_from_host($vf{host_bdf});

            #add the vf to the list of passthrough devices
            push @vfs, \%vf;

            #plug the vf in guest
            plugin_device($guest, $vfs[$i]);

            #upload test specific logs
            save_network_device_status_logs($log_dir, $guest, $i + 2 . "-after_hotplug_$vfs[$i]->{host_id}");

            #check the networking of the plugged interface
            #use br123 as ssh connection
            test_network_interface($guest, gate => $gateway, mac => $vfs[$i]->{vm_mac}, net => 'br123');

        }

        #reboot the guest
        record_info("VM reboot", "$guest");
        script_run "ssh root\@$guest 'reboot'";    #don't use assert_script_run, or may fail on xen guests
        save_network_device_status_logs($log_dir, $guest, $passthru_vf_count + 2 . '-after_guest_reboot');
        script_retry("nmap $guest -PN -p ssh | grep open", delay => 10, retry => 18, die => 1);

        #check again the networking inside vm
        for (my $i = 0; $i < $passthru_vf_count; $i++) {
            test_network_interface($guest, gate => $gateway, mac => $vfs[$i]->{vm_mac}, net => 'br123');
        }

        #unplug the first vf from vm
        unplug_vf_from_vm($guest, $vfs[0]);
        assert_script_run("virsh nodedev-reattach $vfs[0]->{host_id}", 60);
        record_info("Reattach VF to host", "vm=$guest \nvf=$vfs[0]->{host_id}");
        save_network_device_status_logs($log_dir, $guest, $passthru_vf_count + 3 . "-after_hot_unplug_$vfs[$0]->{host_id}");

        #check host and guest to make sure they work well
        check_host();
        check_guest($guest);

        #check again the remaining vf(s) inside vm
        for (my $i = 1; $i < $passthru_vf_count; $i++) {
            test_network_interface($guest, gate => $gateway, mac => $vfs[$i]->{vm_mac}, net => 'br123');
        }
        set_var("SRIOV_NETWORK_CARD_PCI_PASSSHTROUGH", 0);    #turn off the flag in case of affecting other tests

        #unplug the remaining vf(s) from vm
        for (my $i = 1; $i < $passthru_vf_count; $i++) {
            unplug_vf_from_vm($guest, $vfs[$i]);
            assert_script_run("virsh nodedev-reattach $vfs[$i]->{host_id}", 60);
            record_info("Reattach VF to host", "vm=$guest \nvf=$vfs[$i]->{host_id}");
            save_network_device_status_logs($log_dir, $guest, $passthru_vf_count + 3 + $i . "-after_hot_unplug_$vfs[$i]->{host_id}");
        }
        script_run "lspci | grep Ethernet";
        save_screenshot;

        #check host and guest to make sure they work well
        check_host();
        check_guest($guest);

    }

    #upload network device related logs
    upload_virt_logs($log_dir, "logs.tar.gz");
}


#set up ssh, packages and iommu on host
sub prepare_host {

    #install required packages on host
    zypper_call '-t in pciutils nmap';    #to run 'lspci' and 'nmap' command

    #check IOMMU on XEN is enabled
    if (is_xen_host()) {
        assert_script_run "xl dmesg | grep IOMMU | grep -i enabled";
    }
}


#get the BDF the PF device on host
sub find_sriov_ethernet_devices {

    #get the BDF of the ethernet devices with SR-IOV
    my $nic_devices = script_output "lspci | grep Ethernet | grep -v 'Virtual Function' | cut -d ' ' -f1";
    my @nic_devices = split("\n", $nic_devices);
    my @sriov_devices;
    foreach (@nic_devices) {
        if ((script_run "lspci -v -s $_ | grep -q 'SR-IOV'") == 0) {
            push @sriov_devices, $_;
        }
    }
    return @sriov_devices;
}

#enable 8 virtual functions for the specified physical functions of the SR-IOV network device
sub enable_vf {
    my @pfs = @_;

    # get the network device drivers
    my @drivers = ();
    my $driver  = "";
    foreach my $pf (@pfs) {
        $driver = script_output "lspci -v -s $pf | sed -n '/Kernel modules/p' | sed 's/.*Kernel modules: *//'";
        push @drivers, $driver if (!grep /^$driver$/, @drivers);
    }

    #set max_vfs and reload driver
    #should not enable vf repeatedly, so skip enabling in local test for debugging
    foreach my $driver (@drivers) {
        assert_script_run("[ `lsmod | grep $driver | wc -l` -gt 0 ] && rmmod $driver", 60);
        assert_script_run("modprobe --first-time $driver max_vfs=8",                   60);
    }

    #bring up the SR-IOV device
    foreach my $pf (@pfs) {
        my $nic = script_output "ls -l /sys/class/net |grep $pf | awk '{print \$9}'";
        assert_script_run "echo \"BOOTPROTO='dhcp'\nSTARTMODE='manual'\" > /etc/sysconfig/network/ifcfg-$nic";
        assert_script_run("ifup $nic", 60);    #about 15s
    }

    my $vf_devices = script_output "lspci | grep Ethernet | grep \"Virtual Function\" | cut -d ' ' -f1";
    my @vfs        = split("\n", $vf_devices);

}


#set up guest test environment
sub prepare_guest {
    my $vm = shift;

    assert_script_run "virsh dumpxml $vm > $vm.xml";
    script_run "virsh destroy $vm";
    assert_script_run "virsh undefine $vm";

    #extra process for XEN hypervisor
    if (is_xen_host()) {

        #enable pci-passthrough and set model for pv guest.
        #refer to bug #1167217 for the reason
        my $passthru_xml = "<passthrough state='on'/>";
        my $e820_xml     = "";
        if (is_pv_guest($vm)) {
            $e820_xml = "<e820_host state='on'/>";
        }
        if (script_run("grep '<features>' $vm.xml") == 0) {
            assert_script_run "sed -i \"/<features>/a\\<xen>\\n$passthru_xml\\n$e820_xml\\n</xen>\" $vm.xml";
        }
        else {
            assert_script_run "sed -i \"/<domain /a\\<features>\\n<xen>\\n$passthru_xml\\n$e820_xml\\n</xen>\\n</features>\" $vm.xml";
        }

        #disable memory ballooning for fv guest as it is not supported
        if (is_fv_guest($vm)) {
            assert_script_run "sed -i '/<currentMemory/d' $vm.xml";
        }

    }

    #add pcie controllers to support hotplugging more SR-IOV Ethernet vf devices
    my $controller_xml = "<controller type='pci' model='pcie-root-port'/>";
    assert_script_run "sed -i \"/<devices>/a\\$controller_xml\\n$controller_xml\\n$controller_xml\" $vm.xml";
    assert_script_run "virsh define $vm.xml";
    assert_script_run "virsh start $vm";

    #passwordless access to guest
    save_guest_ip($vm, name => "br123");    #get the guest ip via key words in 'virsh domiflist'

}


#detach a specified vf Ethernet device from host
sub detach_vf_from_host {
    my $device_bdf = shift;

    #change to device id in libvirt
    $device_bdf =~ s/[:\.]/_/g;
    my $device_id = script_output "virsh nodedev-list | grep $device_bdf";

    #detach from host
    assert_script_run "virsh nodedev-detach $device_id";
    record_info("Detach VF from host", "$device_id");

    return $device_id;
}


#plugin a device to vm via libvirt
sub plugin_device {
    my ($vm, $vf) = @_;

    #get neccessary device config from host
    my $host_device_xml = script_output "virsh nodedev-dumpxml $vf->{host_id}";
    $host_device_xml =~ /\<domain\>(\w+)\<\/domain\>.*\<bus\>(\w+)\<\/bus\>.*\<slot\>(\w+)\<\/slot\>.*\<function\>(\w+)\<\/function\>/s;
    my ($dev_domain, $dev_bus, $dev_slot, $dev_func) = ($1, $2, $3, $4);

    #'virsh attach-interface' can plug the network device to guest with the BDF in commandline without a seperate device xml file
    #but the SUSE document use 'virsh attach-device', so the test follows it
    #create the device xml to passthrough to vm
    my $vf_host_addr_xml = "<address type='pci' domain='$dev_domain' bus='$dev_bus' slot='$dev_slot' function='$dev_func'/>";
    assert_script_run("echo \"<interface type='hostdev'>\n  <source>\n    $vf_host_addr_xml\n  </source>\n</interface>\" > $vf->{host_id}.xml", 60);
    upload_logs("$vf->{host_id}.xml");

    #attach device to vm
    assert_script_run "virsh -d 1 attach-device $vm $vf->{host_id}.xml --persistent";

    #get the mac address and bdf by parsing the domain xml
    #tips: there may be multiple interfaces and multiple hostdev devices in the guest
    my $nics_count = script_output "virsh dumpxml $vm | grep -c \"<interface.*type='hostdev'\"";
    my $devs_xml   = script_output "virsh dumpxml $vm | sed -n \"/<interface.*type='hostdev'/,/<\\/devices/p\"";
    $vf->{host_id} =~ /pci_([a-z\d]+)_([a-z\d]+)_([a-z\d]+)_([a-z\d]+)/;
    my ($dom, $bus, $slot, $func) = ($1, $2, $3, $4);    #these are different with those in host_devices.xml
    for (my $i = 0; $i < $nics_count; $i++) {
        $devs_xml =~ /\<interface.*?type='hostdev'.*?\<\/interface\>/s;    #minimal match
        my $nic_xml = $&;
        if ($nic_xml =~ /domain='(0x)?$dom' +bus='(0x)?$bus' +slot='(0x)?$slot' +function='(0x)?$func'/) {

            #get the vf xml in vm config file for later unplugging to use
            $vf->{vm_xml} = $nic_xml;

            #get mac address
            $nic_xml =~ /\<mac.*address='(.*)'/;
            $vf->{vm_mac} = $1;

            #get bdf for guests on KVM
            $nic_xml =~ s/\<source.*\<\/source\>//s;
            if ($nic_xml =~ /bus='(\w+)'.*slot='(\w+)'.*function='(\w+)'/) {
                my ($bus, $slot, $func) = ($1, $2, $3);
                $vf->{vm_bdf} = $bus . ":" . $slot . "." . $func;
            }
            else {

                #have to get bdf by other means for guests on XEN
                $vf->{vm_bdf} = script_output "ssh root\@$vm \"if [ -e /sys/devices/pci-0/pci????:?? ]; then grep -H '$vf->{vm_mac}' /sys/devices/pci-0/*/*/net/*/address | cut -d '/' -f6; else grep -H '$vf->{vm_mac}' /sys/devices/*/*/net/*/address | cut -d '/' -f5; fi\"";
            }
            last;

        }
        else {
            $devs_xml =~ s/\<interface.*?type='hostdev'.*?\<\/interface\>//s;
        }
    }

    #print the vf device
    $vf->{vm_bdf} =~ /[a-z\d]+:[a-z\d]+[.:][a-z\d]+/;    #bdf has different format in guests on KVM and XEN
    assert_script_run "ssh root\@$vm \"lspci -vvv -s $vf->{vm_bdf}\"";
    $vf->{vm_nic} = script_output "ssh root\@$vm \"grep '$vf->{vm_mac}' /sys/class/net/*/address | cut -d'/' -f5 | head -n1\"";
    record_info("VF plugged to vm", "$vf->{host_id} \nGuest: $vm\nbdf='$vf->{vm_bdf}'   mac_addrss='$vf->{vm_mac}'   nic='$vf->{vm_nic}'");

}


#unplug the vf device from guest
sub unplug_vf_from_vm {
    my ($vm, $vf) = @_;

    #bring the nic down
    script_run("ssh root\@$vm 'ifdown $vf->{vm_nic}'", 60);

    #detach vf from guest
    my $vf_xml_file = "vf_in_vm.xml";
    assert_script_run "echo \"$vf->{vm_xml}\" > $vf_xml_file";
    assert_script_run("virsh detach-device $vm $vf_xml_file --persistent", 60);

    #check if the nic is removed from vm
    validate_script_output "ssh root\@$vm \"ip l show $vf->{vm_nic}\"", sub { /does not exist/ };

    record_info("VF unpluged from vm", "$vf->{host_id} \nGuest: $vm \nbdf='$vf->{vm_bdf}'   mac='$vf->{vm_mac}'   nic='$vf->{vm_nic}'");

}

#print logs for debugging
sub save_network_device_status_logs {
    my ($log_dir, $vm, $test_step) = @_;

    #vm configuration file
    script_run "virsh dumpxml $vm > $log_dir/${vm}_${test_step}.xml";

    my $log_file = "log.txt";
    script_run "echo `date` > $log_file";

    #list domain interface
    print_cmd_output_to_file("virsh domiflist $vm", $log_file);

    #save udev rules from guest
    script_run "echo -e \"\n# ssh root\@$vm 'cat /etc/udev/rules.d/'\" >> $log_file";
    if ((script_run "ssh root\@$vm 'ls /etc/udev/rules.d/'") == 0) {
        script_run "[ -d rules.d/ ] && rm -rf rules.d/; scp -r root\@$vm:/etc/udev/rules.d/ .; ls rules.d/ >> $log_file; cat rules.d/* >> $log_file";
    }

    #list pci devices in guest
    print_cmd_output_to_file("lspci",     $log_file, $vm);
    print_cmd_output_to_file("ip l show", $log_file, $vm);

    script_run "mv $log_file $log_dir/${vm}_${test_step}_network_device_status.txt";

}

sub post_fail_hook {
    my $self = shift;

    my $log_dir = "/tmp/sriov_pcipassthru";

    diag("Module sriov_network_card_pci_passthrough post fail hook starts.");
    my $vm_types           = "sles|win";
    my $get_vm_hostnames   = "virsh list  --all | grep -E \"${vm_types}\" | awk \'{print \$2}\'";
    my $vm_hostnames       = script_output($get_vm_hostnames, 30, type_command => 0, proceed_on_failure => 0);
    my @vm_hostnames_array = split(/\n+/, $vm_hostnames);
    foreach (@vm_hostnames_array)
    {
        save_network_device_status_logs($log_dir, $_, "9_post_fail_hook");
    }

    upload_virt_logs($log_dir, "logs.tar.gz");
    $self->SUPER::post_fail_hook;

}

1;
