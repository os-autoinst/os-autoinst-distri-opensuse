# SUSE's openQA tests

# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: xen domU irqbalance test
# Maintainer: Julie CAO <JCao@suse.com>

use base "virt_feature_test_base";
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle);
use set_config_as_glue;
use virt_autotest::common;
use virt_autotest::utils qw(is_kvm_host guest_is_sle wait_guest_online print_cmd_output_to_file);
use virt_utils qw(upload_virt_logs remove_vm restore_downloaded_guests);

our $vm_xml_save_dir = "/tmp/download_vm_xml";

sub run_test {
    my $self = shift;

    return if is_kvm_host;

    save_original_guests();

    foreach my $guest (keys %virt_autotest::common::guests) {

        #irqbalance test run on sle12sp3+ guest
        next if guest_is_sle($guest, '<=12-sp2');

        record_info("Test $guest");
        prepare_guest_for_irqbalance($guest);

        # with irqbalance.service is enabled, SMP affinity will be distributed among CPUs automatically even if IRQs are bound to specified CPUs in SLE15SP4
        assert_script_run "ssh root\@$guest \"systemctl stop irqbalance.service\"" if script_run("ssh root\@$guest \"systemctl status irqbalance\"") eq 0;

        my $nproc = script_output("ssh root\@$guest 'nproc'");

        # Bind all NIC IRQs to cpu0 in guest
        my @nic_irqs_id = split('\n', script_output("ssh root\@$guest \"grep vif /proc/interrupts | cut -d ':' -f1 | sed 's/^ *//'\""));
        foreach my $irq_id (@nic_irqs_id) {
            assert_script_run("ssh root\@$guest \"echo 1 > /proc/irq/$irq_id/smp_affinity\"");
        }
        my @affinities_with_binding_cpu0 = get_irq_affinities_from_guest($guest, @nic_irqs_id);
        foreach (@affinities_with_binding_cpu0) {
            die "Failed to bind NIC IRQs to CPU0" if $_ ne 1;
        }

        # Start the irqbalance.service again
        assert_script_run("ssh root\@$guest \"systemctl start irqbalance\"");

        # Check if the SMP affinities are distributed among CPUs
        my @affinities_with_irqbalance = get_irq_affinities_from_guest($guest, @nic_irqs_id);
        # for SLE15SP3 and prior, IRQs are distributed on one cpu core ramdomly.
        # So it is correct if some of them may happen to run on cpu0
        # but it would not be correct if all IRQs were bound to cpu0.
        if (guest_is_sle($guest, '<=15-sp3')) {
            my $multiply = 1;
            $multiply *= $_ foreach (@affinities_with_irqbalance);
            die "SMP affinities were all bound to CPU0 with irqbalance.service enabled" if $multiply == 1;
        }
        # for SLE15SP4 (or newer release), IRQs are specified on all CPU cores
        # fg. affinity value is '0xf' for machine with 4 CPU cores
        else {
            my $default_affinity = script_output("ssh root\@$guest \"cat /proc/irq/default_smp_affinity\"");
            foreach (@affinities_with_irqbalance) {
                die "The NIC IRQs did not follow the default_smp_affinity with irqbalance enabled." if $_ ne $default_affinity;
            }
        }

        # Get the network interrupts distribution over CPUs in guest prior to network loads
        my @initial_total_irqs_on_cpu = get_nic_irqs_distribution_from_guest($guest, $nproc);

        # Generate network load in guest
        my $ping_url = "download.opensuse.org";
        assert_script_run("ssh root\@$guest \"ping -f -c 500 $ping_url\"");

        # re-caculate the network interrupts distribution
        # the increased NIC IRQs should be distributed in CPU cores in balance
        my @total_irqs_on_cpu_after_network_download = get_nic_irqs_distribution_from_guest($guest, $nproc);
        my @increased_irqs_on_cpu;
        for (my $cpu_id = 0; $cpu_id < $nproc; $cpu_id++) {
            $increased_irqs_on_cpu[$cpu_id] = $total_irqs_on_cpu_after_network_download[$cpu_id] - $initial_total_irqs_on_cpu[$cpu_id];
            die("The value of network interrupts from download for CPU" . $cpu_id . " is 0") if $increased_irqs_on_cpu[$cpu_id] == 0;
        }
        record_info("NIC IRQs distribution of 'ping $ping_url'", "@increased_irqs_on_cpu");
    }

    restore_xml_changed_guests();

}

#save the guest configuration files into a folder
sub save_original_guests {
    assert_script_run "mkdir -p $vm_xml_save_dir" unless script_run("ls $vm_xml_save_dir") == 0;
    my $changed_xml_dir = "$vm_xml_save_dir/changed_xml";
    script_run("[ -d $changed_xml_dir ] && rm -rf $changed_xml_dir/*");
    script_run("mkdir -p $changed_xml_dir");
    foreach my $guest (keys %virt_autotest::common::guests) {
        unless (script_run("ls $vm_xml_save_dir/$guest.xml") == 0) {
            assert_script_run "virsh dumpxml --inactive $guest > $vm_xml_save_dir/$guest.xml";
        }
    }
}

#restore guest from the configuration files in a folder
sub restore_original_guests {
    foreach my $guest (keys %virt_autotest::common::guests) {
        remove_vm($guest);
        if (script_run("ls $vm_xml_save_dir/$guest.xml") == 0) {
            restore_downloaded_guests($guest, $vm_xml_save_dir);
        }
        else {
            record_soft_failure "Fail to restore $guest!";
        }
    }
}

#restore guest which xml configuration files were changed in prepare_guest_for_irqbalance()
sub restore_xml_changed_guests {
    my $changed_xml_dir = "$vm_xml_save_dir/changed_xml";
    my @changed_guests = split('\n', script_output("ls -1 $changed_xml_dir | cut -d '.' -f1"));
    foreach my $guest (@changed_guests) {
        remove_vm($guest);
        restore_downloaded_guests($guest, $changed_xml_dir);
    }
}

#set up guest test environment to run irqbalance test
sub prepare_guest_for_irqbalance {
    my $vm_name = shift;

    #4 or more vcpu is needed
    my $nproc = script_output "virsh vcpucount --config --current $vm_name";
    if ($nproc < 4) {
        my $changed_xml_dir = "$vm_xml_save_dir/changed_xml";
        assert_script_run "virsh dumpxml --inactive $vm_name > $vm_name.xml";
        #save for restore the changed guests after test
        assert_script_run "cp $vm_name.xml $changed_xml_dir/$vm_name.xml";
        script_run "virsh destroy $vm_name";
        assert_script_run "xmlstarlet edit -L -d /domain/vcpu $vm_name.xml";
        assert_script_run "xmlstarlet edit -L \\
                               -s /domain -t elem -n vcpu -v 4 \\
			       -s /domain/vcpu -t attr -n placement -v static \\
			       $vm_name.xml";
        script_run "virsh undefine $vm_name" unless (script_run "virsh undefine --nvram $vm_name") == 0;
        assert_script_run " ! virsh list --all | grep $vm_name";
        assert_script_run "virsh define $vm_name.xml";
        assert_script_run "virsh start $vm_name";
    }

    wait_guest_online($vm_name);
    assert_script_run "ssh root\@$vm_name \"zypper in -y irqbalance\"" unless script_run("ssh root\@$vm_name \"rpm -q irqbalance\"") eq 0;

}

# return the total NIC IRQs on each CPU core from guest
sub get_nic_irqs_distribution_from_guest {
    my ($vm_name, $cpu_account) = @_;

    my @total_irqs_on_cpu = ();
    my $irq_output = script_output("ssh root\@$vm_name \"grep vif0 /proc/interrupts\"");
    record_info("NIC IRQs distribution", $irq_output);
    for (my $cpu_id = 0; $cpu_id < $cpu_account; $cpu_id++) {
        my @irqs_on_one_cpu = split('\n', script_output("ssh root\@$vm_name \"awk '/vif0/{ print \\\$(($cpu_id+2)) }' /proc/interrupts\""));
        # sum of IRQs on one cpu core
        for (my $i = 0; $i <= $#irqs_on_one_cpu; $i++) {
            $total_irqs_on_cpu[$cpu_id] += $irqs_on_one_cpu[$i];
        }
    }

    return @total_irqs_on_cpu;
}

# it is more stable to get the affinities after a little time than just after it is written
# especially with irqbalance is enabled, so a function is wrapped
sub get_irq_affinities_from_guest {
    my ($vm_name, @irqs) = @_;

    my $cat_affinity_files_cmdline = "ssh root\@$vm_name \"cd /proc/irq && cat";
    foreach my $irq_id (@irqs) {
        $cat_affinity_files_cmdline .= " $irq_id/smp_affinity";
    }
    $cat_affinity_files_cmdline .= "\"";
    return split('\n', script_output($cat_affinity_files_cmdline, 60));
}

sub post_fail_hook {
    my $self = shift;

    diag("Module xen_guest_irqbalance post fail hook starts.");
    my $log_dir = "/tmp/irqbalance";
    foreach my $guest (keys %virt_autotest::common::guests) {
        my $log_file = $log_dir . "/$guest" . "_irqbalance_debug";
        script_run("[ -d $log_dir ] && rm -rf $log_dir/*");
        script_run("mkdir -p $log_dir && touch $log_file");
        print_cmd_output_to_file("rpm -q irqbalance", $log_file, $guest);
        print_cmd_output_to_file("systemctl status irqbalance", $log_file, $guest);
        print_cmd_output_to_file("grep vif0 /proc/interrupts", $log_file, $guest);
        print_cmd_output_to_file("cat /proc/irq/default_smp_affinity", $log_file, $guest);
        print_cmd_output_to_file("cat /proc/irq/*/smp_affinity", $log_file, $guest);
        #skip post the output of 'irqbalance --debug' because it takes too long(more than 15 minutes)
    }
    upload_virt_logs($log_dir, "irqbalance_debug");
    $self->SUPER::post_fail_hook;
    restore_original_guests();

}

sub test_flags {
    #continue subsequent test in the case test restored
    return {fatal => 0};
}

1;

