# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Mitigation testcase library provides a class to execute
# common test steps. Specifically checkpoint could be done in individual
# test module via override functions in this class, or extend the test.
#
# Usage, when you need to testing a mitigation function.
# you need to initialize a hash struct seems like:
#
#my %mitigations_list =
#  (
#    name                   => "l1tf",
#    CPUID                  => hex '10000000',
#    IA32_ARCH_CAPABILITIES => 8,                #bit3 --SKIP_L1TF_VMENTRY
#    parameter              => 'l1tf',
#    cpuflags               => ['flush_l1d'],
#    sysfs_name             => "l1tf",
#    sysfs                  => {
#        "full"         => "Mitigation: PTE Inversion; VMX: cache flushes, SMT disabled",
#        "full,force"   => "Mitigation: PTE Inversion; VMX: cache flushes, SMT disabled",
#        "flush"        => "Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT vulnerable",
#        "flush,nosmt"  => "Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT disabled",
#        "flush,nowarn" => "Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT vulnerable",
#        "off"          => "Mitigation: PTE Inversion; VMX: vulnerable",
#        "default"      => "Mitigation: PTE Inversion; VMX: conditional cache flushes, SMT vulnerable",
#    },
#    cmdline => [
#        "full",
#        "full,force",
#        "flush",
#        "flush,nosmt",
#        "flush,nowarn",
#        "off",
#    ],
#  );
#
#  "name", the name of test module or mitigations name.
#  "CPUID", the bit that should be check via cpuid instruction. follow Intel manual.
#  "IA32_ARCH_CAPABILITIES", the bit that means this mitigations might be fixed by Hardware.
#  "parameter", the name of parameter on kernel cmdline, as switch to enable or disable this mitigation in system.
#  "cpuflags", the flag[s] name should be appear at /proc/cpuinfo or lscpu.
#  "sysfs_name", the name of entry in sysfs: /sys/devices/system/cpu/vulnerabilities/*,
#  "sysfs", a hash with  {"name" => "string"}
#  	Means, when "name" be used as a kernel parameter to value, the "string" should be the context of "sysfs_name".
#  "cmdline", an array that store what kernel parameter will be tested.
#
## Maintainer: James Wang <jnwang@suse.com>
#
package Mitigation;
use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;
use Utils::Backends;
use bootloader_setup qw(grub_mkconfig change_grub_config add_grub_cmdline_settings remove_grub_cmdline_settings grep_grub_settings set_framebuffer_resolution set_extrabootparams_grub_conf);
use ipmi_backend_utils;
use power_action_utils 'power_action';
use constant {
    CPUID_EAX => 1,
    CPUID_EBX => 2,
    CPUID_ECX => 3,
    CPUID_EDX => 4,
};

my $vm_ip_addr;
my $qa_password;

our $DEBUG_MODE = get_var("XEN_DEBUG", 0);
=head2 reboot_and_wait

	reboot_and_wait([timeout => $timeout]);

To reboot and waiting system back and login it.
This could support IPMI and QEMU backend.
C<$timeout> in seconds.
=cut

sub reboot_and_wait {
    my ($self, $timeout) = @_;
    if (is_ipmi) {
        power_action('reboot', textmode => 1, keepconsole => 1);
        switch_from_ssh_to_sol_console(reset_console_flag => 'on');
        if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
            assert_screen([qw(pxe-qa-net-mitigation qa-net-selection)], 90);
            send_key 'ret';
            assert_screen([qw(grub2 grub1)], 60);
            #send key 'up' to stop grub timer counting down, to be more robust to select xen
            send_key 'up';
            save_screenshot;

            for (1 .. 20) {
                if ($_ == 10) {
                    reset_consoles;
                    select_console 'sol', await_console => 0;
                }
                send_key 'down';
                last if check_screen 'virttest-bootmenu-xen-kernel', 5;
            }
            save_screenshot;
            send_key 'ret';
        }
        sleep 30;    # Wait for the GRUB to disappear (there's no chance for the system to boot faster
        save_screenshot;

        for (my $i = 0; $i <= 4; $i++) {
            last if (check_screen([qw(linux-login virttest-displaymanager)], 60));
            save_screenshot;
            send_key 'ret';
        }
        use_ssh_serial_console;
    }
    else {
        power_action('reboot', textmode => 1);
        $self->wait_boot(textmode => 1, ready_time => 300, in_grub => 1);
        select_console 'root-console';
    }
}

our $syspath = '/sys/devices/system/cpu/vulnerabilities/';

#If you base on this Class, you have to override new function,
#so that it could be loaded by openQA.
#
sub new {
    my ($class, $args) = @_;
    if (ref($args)) {
        return bless $args, $class;
    }
    else {
        my $self = $class->SUPER::new($args);
        return bless $self, $class;
    }
}

sub Parameter {
    my ($self, $value) = @_;
    if (@_ == 2) {
        $self->{parameter} = $value;
    }
    return $self->{Parameter};
}
sub sysfs_name {
    my ($self, $value) = @_;
    if (@_ == 2) {
        $self->{sysfs_name} = $value;

    }
    return $self->{sysfs_name};
}
sub CPUID {
    my $self = shift;
    return $self->{CPUID};
}

sub MSR {
    my $self = shift;
    return $self->{IA32_ARCH_CAPABILITIES};
}

sub read_cpuid_base {
    my ($self, $value) = @_;
    #Reimplement: "cpuid -1 -l 7 -s 0 -r | awk \'{print \$6}\' | awk -F \"=\" \'{print \$2}\' | tail -n1"
    #Refer to data/virtualization/spectre-meltdown-checker.sh
    #$value: 1=EAX,2=EBX,3=ECX,4=EDX
    script_output('modprobe cpuid');
    my $_leaf = 7;    #leaf=7
    my $_ddskip = int($_leaf / 16);
    my $_odskip = int($_leaf - $_ddskip * 16);
    my $_odskip_plus = int($_odskip + 1);
    my $_skip_byte = int($_odskip * 16);
    my $ret = 0;
    $ret = hex script_output(
        "dd if=/dev/cpu/0/cpuid bs=16 skip=$_ddskip count=$_odskip_plus 2>/dev/null | od -j $_skip_byte -A n -t x4 | awk \'{print \$$value}\'"
    );
    print sprintf("read_cpuid_base reg#$value: 0x%X\n", $ret);
    return $ret;
}

sub read_cpuid_edx {
    my $self = shift;
    return $self->read_cpuid_base(CPUID_EDX);
}

sub read_cpuid_ebx {
    my $self = shift;
    return $self->read_cpuid_base(CPUID_EBX);
}

sub read_msr {
    my $self = shift;
    script_output('modprobe msr');
    my $edx = script_output(
        "perl -e \'open(M,\"<\",\"/dev/cpu/0/msr\") and seek(M,0x10a,0) and read(M,\$_,8) and print\' | od -t u8 -A n"
    );
    return $edx;
}

sub vulnerabilities {
    my $self = shift;
    if ($self->read_cpuid_edx() & $self->CPUID()) {
        if ($self->read_msr() & $self->MSR()) {
            record_info("$self->{'name'} Not Affected", "This machine needn't be tested.");
            return 0;    #Not Affected
        }
    }
    record_info("$self->{'name'} vulnerable", "Testing will continue.");
    return 1;    #Affected
}

sub sysfs {
    my ($self, $value) = @_;
    $value =~ s/,/_/g;
    if (@_ == 2) {
        return $self->{sysfs}->{$value};
    }
    return $self->{sysfs};

}

sub dmesg {
    my $self = shift;
    for my $p (keys %{$self->{dmesg}}) {
        print "dmesg " . $self->Name . "\n";
        print $self->{dmesg}->{$p} . "\n";
    }
}

sub cmdline {
    my $self = shift;
    return $self->{cmdline};
}

sub lscpu {
    my $self = shift;
    for my $p (keys %{$self->{lscpu}}) {
        print $p. "\n";
    }
}



#This function will finish testing in default status.
#As out of box testing. and clean up all mitigations parameters.
sub check_default_status {
    my $self = shift;
    assert_script_run('cat /proc/cmdline');
    if (ref($self->{parameter}) ne 'ARRAY') {
        $self->{parameter} = [$self->{parameter}];
    }
    foreach my $parameter_item (@{$self->{parameter}}) {
        my $ret = script_run('grep "' . $parameter_item . '=[a-z,]*" /proc/cmdline');
        if ($ret eq 0) {
            remove_grub_cmdline_settings($parameter_item . "=[a-z,]*");
        }
    }
    my $ret = script_run('grep "' . "mitigations" . '=[a-z,]*" /proc/cmdline');
    if ($ret eq 0) {
        remove_grub_cmdline_settings("mitigations=[a-z,]*");
    }
    reboot_and_wait($self, 150);
    foreach my $parameter_item (@{$self->{parameter}}) {
        my $ret = script_run('grep "' . $parameter_item . '=off" /proc/cmdline');
        if ($ret eq 0) {
            die "there are still have parameter will impacted our test";
        }
    }

}

#Check cpu flags exist or not.
#when $cmd is off, the match is inverted.
sub check_cpu_flags {
    my ($self) = @_;
    assert_script_run('cat /proc/cpuinfo');
    foreach my $flag (@{$self->{cpuflags}}) {
        my $ret = script_run('cat /proc/cpuinfo | grep "^flags.*' . $flag . '.*"');
        if (get_var('MACHINE', '') =~ /NO-IBRS$/ && is_qemu) {
            if ($ret ne 0) {
                record_info("NOT PASSTHROUGH", "Host didn't pass flags into this VM.");
                return;
            } else {
                die "VM didn't bring CPU flags";
            }
        }
    }
}

sub check_sysfs {
    my ($self, $value) = @_;
    record_info("sysfs:$value", "checking sysfs: $value");
    if (ref($self->{sysfs_name}) eq 'ARRAY') {
        foreach my $sysfs_name_item (@{$self->{sysfs_name}}) {
            assert_script_run('cat ' . $syspath . $sysfs_name_item);
            if (@_ == 2) {
                assert_script_run(
                    'cat ' . $syspath . $sysfs_name_item . '| grep ' . '"' . $self->{sysfs}->{$value}->{$sysfs_name_item} . '"');
            }
        }
    } else {
        assert_script_run('cat ' . $syspath . $self->sysfs_name());
        if (@_ == 2) {
            assert_script_run(
                'cat ' . $syspath . $self->sysfs_name() . '| grep ' . '"' . $self->sysfs($value) . '"');
        }
    }
}

sub check_dmesg {
    my ($self, $value) = @_;    #the value of kernel parameter
    $value =~ s/,/_/g;
    foreach my $string ($self->{dmesg}->{$value}) {
        assert_script_run(
            'dmesg | grep "' . $string . '"');
    }
}

sub check_cmdline {
    my $self = shift;
    assert_script_run(
        'cat /proc/cmdline'
    );

}

#check only one cmdline item.
sub check_one_parameter_value {
    #testing one parameter.
    my ($self, $cmd) = @_;
    if ($cmd) {
        $self->add_parameter($cmd);
        $self->check_cpu_flags($cmd);
        $self->check_sysfs($cmd);
        $self->remove_parameter($cmd);
    }
}


#check all cmdline items.
sub check_each_parameter_value {
    #testing each parameter.
    my $self = shift;
    foreach my $cmd (@{$self->cmdline()}) {
        record_info("$self->{name}=$cmd", "Mitigation $self->{name}=$cmd testing start.");
        $self->add_parameter($cmd);
        $self->check_cmdline();
        $self->check_cpu_flags($cmd);
        $self->check_cmdline();
        $self->check_sysfs($cmd);
        $self->remove_parameter($cmd);
    }
}


sub add_parameter {
    my ($self, $value) = @_;
    if (ref($self->{parameter}) eq 'ARRAY') {
        foreach my $para (@{$self->{parameter}}) {
            add_grub_cmdline_settings($para . '=' . $value);
        }
    } else {
        add_grub_cmdline_settings($self->{parameter} . '=' . $value);
    }
    grub_mkconfig();
    reboot_and_wait($self, 150);
}

sub remove_parameter {
    my ($self, $value) = @_;
    if (ref($self->{parameter}) eq 'ARRAY') {
        foreach my $para (@{$self->{parameter}}) {
            remove_grub_cmdline_settings($para . '=' . $value);
        }
    } else {
        remove_grub_cmdline_settings($self->{parameter} . '=' . $value);
    }
}

sub ssh_vm_cmd {
    my ($cmd, $qa_password, $vm_ip_addr) = @_;
    my $ret = script_run("sshpass -p ${qa_password} ssh -o StrictHostKeyChecking=no -qy root\@${vm_ip_addr} \"$cmd\"");
    return $ret;
}


# Execute $cmd in vm and get output
sub script_output_from_vm {
    my ($cmd, $qa_password, $vm_ip_addr) = @_;
    my $output = script_output("sshpass -p ${qa_password} ssh -o StrictHostKeyChecking=no -qy root\@${vm_ip_addr} \"$cmd\"", proceed_on_failure => 1);
    for (1 .. 3) {
        if ($output) {
            return $output;
        } else {
            sleep 2;
            $output = script_output("sshpass -p ${qa_password} ssh -o StrictHostKeyChecking=no -qy root\@${vm_ip_addr} \"$cmd\"", proceed_on_failure => 1);
        }
    }
    record_info('ERROR', "Failed to get output from guest.");
    return $output;
}

sub config_and_reboot {
    my ($qa_password, $vm_domain_name, $vm_ip_addr) = @_;
    my $config_ret = ssh_vm_cmd("grub2-mkconfig -o /boot/grub2/grub.cfg", $qa_password, $vm_ip_addr);
    if ($config_ret ne 0) {
        ssh_vm_cmd("grub2-mkconfig -o /boot/grub2/grub.cfg", $qa_password, $vm_ip_addr);
    }
    record_info('INFO', "Generate domu kernel parameters.");
    #ssh_vm_cmd("poweroff", $qa_password, $vm_ip_addr);
    ssh_vm_cmd("sync", $qa_password, $vm_ip_addr);

    script_run("virsh destroy \"${vm_domain_name}\"");
    sleep 2;
    script_run('virsh list --all');
    script_run("virsh start \"${vm_domain_name}\"");

    record_info('INFO', "Waiting for the vm to reboot");
    sleep 60;
    if ($DEBUG_MODE) {
        record_info("Debug",
            "DomU kernel parameter: "
              . script_output_from_vm("cat /proc/cmdline",
                $qa_password,
                $vm_ip_addr),
            result => 'ok');
    }

}

sub do_check {
    my ($secnario, $qa_password, $dc_domain_name, $vm_ip_addr) = @_;
    my $foo = $secnario->{default};
    if ($foo->{expected}) {
        while (my ($cmd, $lines) = each %{$foo->{expected}}) {
            my $vm_output = script_output_from_vm("$cmd", $qa_password, $vm_ip_addr);
            foreach my $expected_string (@{$lines}) {
                if ($vm_output !~ /$expected_string/i) {
                    record_info("ERROR", "Actual output: " . $vm_output . "\nExpected string: " . $expected_string, result => 'fail');
                    return (1, "Expected", $expected_string, $vm_output);
                }
            }
        }
    }
    if ($foo->{unexpected}) {
        while (my ($cmd, $lines) = each %{$foo->{unexpected}}) {
            my $vm_output = script_output_from_vm("$cmd", $qa_password, $vm_ip_addr);
            foreach my $unexpected_string (@{$lines}) {
                if ($vm_output =~ /$unexpected_string/ix) {
                    record_info("ERROR", "Actual output: " . $vm_output . "\nUnexpected string: " . $unexpected_string, result => 'fail');
                    return (1, "Unexpected", $unexpected_string, $vm_output);
                }
            }
        }
    }
    return (0, undef, undef, undef);
}

sub cycle_workflow {
    my ($self, $carg, $ckey, $cvalue, $qa_password, $cvm_domain_name, $vm_ip_addr, $hyper_param) = @_;
    my $parameter = $ckey;
    ssh_vm_cmd("sed -i -e '/GRUB_CMDLINE_LINUX=/s/\\\"\$/ $parameter\\\"/' /etc/default/grub", $qa_password, $vm_ip_addr);
    my $cmd_output = script_output_from_vm("grep GRUB_CMDLINE_LINUX= /etc/default/grub", $qa_password, $vm_ip_addr);
    if ($cmd_output !~ /$parameter/i) {
        ssh_vm_cmd("sed -i -e '/GRUB_CMDLINE_LINUX=/s/\\\"\$/ $parameter\\\"/' /etc/default/grub", $qa_password, $vm_ip_addr);
    }
    config_and_reboot($qa_password, $cvm_domain_name, $vm_ip_addr);
    if ($DEBUG_MODE) {
        my $vm_vulnerability_output = script_output_from_vm("grep -H . " . $syspath . "*", $qa_password, $vm_ip_addr);
        my $vm_cmdline_output = script_output_from_vm("cat /proc/cmdline", $qa_password, $vm_ip_addr);
        record_info("Debug", "Test Parameter:" . $parameter
              . "\nDomu kernel parameters:" . $vm_cmdline_output
              . "\nVulnerabilities value: " . $vm_vulnerability_output, result => 'ok');
    }
    my ($ret, $match_type, $match_value, $actual_output) = do_check($cvalue, $qa_password, $cvm_domain_name, $vm_ip_addr);
    if ($ret ne 0) {
        record_info('ERROR', "$parameter test is failed.", result => 'fail');
    }
    record_info('INFO', "$parameter test is finished.");
    ssh_vm_cmd("sed -i -e '/GRUB_CMDLINE_LINUX=/s/ $parameter//g' /etc/default/grub", $qa_password, $vm_ip_addr);
    config_and_reboot($qa_password, $cvm_domain_name, $vm_ip_addr);
    return ($ret, $match_type, $match_value, $actual_output);
}

sub guest_cycle {
    my ($self, $hash, $single, $mode, $qa_password, $gcvm_domain_name, $vm_ip_addr, $hyper_param) = @_;

    # Initialize variable for generating junit file
    my $testsuites_name = $gcvm_domain_name . '_mitigation_test';
    my $testsuite_name = '';
    my $testcase_name = '';
    my $total_failure_tc_count = 0;
    my $failure_tc_count_in_ts = 0;
    my $total_tc_count = 0;
    my $total_tc_count_in_ts = 0;
    my $junit_file = "/tmp/" . $gcvm_domain_name . "_mitigation_test_junit.xml";

    # Initialize junit structure for hypervisor mitigation test
    init_xml(file_name => "$junit_file", testsuites_name => "$testsuites_name");

    while (my ($arg, $dict) = each %$hash) {
        if ($mode eq 'all' or $mode eq 'single') {
            $failure_tc_count_in_ts = 0;
            $total_tc_count_in_ts = 0;
            if ($DEBUG_MODE) {
                record_info("Debug", "Hypervisor params: " . $arg . "\nTest mode: " . $mode . "\nTestCase:" . $single . "\n", result => 'ok');
            }
            # check user specified test cases and support multiple test cases to run, use "," as delimiter
            if ($mode eq 'single') {
                if (!grep { $_ =~ /$arg/i } split(/,+/, $single)) {
                    next;
                }
            }
            # Add a group case name as testsuite to junit file
            append_ts2_xml(file_name => "$junit_file", testsuite_name => "$arg on " . "$hyper_param");
            while (my ($key, $value) = each %$dict) {
                if ($DEBUG_MODE) {
                    record_info("Debug", "DomU kernel params for test: " . $key . "\n", result => 'ok');
                }
                # Calculate test case count
                $total_tc_count += 1;
                $total_tc_count_in_ts += 1;
                my $testcase_status = "pass";

                # go through each case
                my ($ret, $match_type, $match_value, $actual_output) = cycle_workflow($self, $arg, $key, $value, $qa_password, $gcvm_domain_name, $vm_ip_addr);
                if ($ret ne 0) {
                    $testcase_status = "fail";
                    $failure_tc_count_in_ts += 1;
                    $total_failure_tc_count += 1;
                    insert_tc2_xml(file_name => "$junit_file",
                        class_name => "$key",
                        case_status => "$testcase_status",
                        sys_output => "$match_type:" . "$match_value",
                        sys_err => "Actual:" . "$actual_output");
                } else {
                    insert_tc2_xml(file_name => "$junit_file",
                        class_name => "$key",
                        case_status => "$testcase_status");
                }
                update_ts_attr(file_name => "$junit_file", attr => 'failures', value => $failure_tc_count_in_ts);
                update_ts_attr(file_name => "$junit_file", attr => 'tests', value => $total_tc_count_in_ts);
                # update testsuites info
                update_tss_attr(file_name => "$junit_file", attr => 'failures', value => $total_failure_tc_count);
                update_tss_attr(file_name => "$junit_file", attr => 'tests', value => $total_tc_count);
                # upload junit file for each case to avoid missing all result once test causes host hang.
                parse_junit_log("$junit_file");
            }
        } else {
            last;
        }

    }
    parse_junit_log("$junit_file");
}
#This is entry for testing.
#The instances call this function to finish all 'basic' testing.
#This function will check if current machine has a hardware fix.
#If the current machine is not affected, test over.
sub do_test {
    my $self = shift;
    select_console 'root-console';

    if (!check_var('TEST', 'MITIGATIONS') && !check_var('TEST', 'KVM_GUEST_MITIGATIONS')) {
        #If it is qemu vm and didn't passthrough cpu flags
        #Meltdown doesn't matter CPU flags
        if (get_var('MACHINE') =~ /^qemu-.*-NO-IBRS$/ && is_qemu && !(get_var('TEST') =~ /MELTDOWN/)) {
            record_info('NO-IBRS machine', "This is a QEMU VM and didn't passthrough CPU flags.");
            record_info('INFO', "Check status of mitigations as like OFF.");
            $self->check_sysfs("off");
            return;
        }

        record_info("vulnerabilities?", "checking vulnerabilities for $self->{name}");
        my $ret = $self->vulnerabilities();
        if ($ret == 0) {
            record_info('INFO', "This CPU is not affected by $self->{name}.");
            return 2;
        } else {
            record_info('INFO', "Mitigation $self->{name} testing start.");
        }
    }
    #check system default status
    #and prepare the command line parameter for next testings
    $self->check_default_status();
    $self->check_cpu_flags();
    $self->check_sysfs("default");
    $self->check_each_parameter_value();

    remove_grub_cmdline_settings($self->{parameter} . '=' . '[a-z,]*');
}

# Initialize junit xml file structure.
sub init_xml {
    my %args = (
        testsuites_name => 'ts',
        file_name => '/tmp/junit.xml'
    );
    %args = @_;
    my $xml_content = << "EOF";
<testsuites error='0' failures='0' name=\\"$args{testsuites_name}\\" skipped='0' tests='0' time=''>
</testsuites>
EOF
    assert_script_run("echo \"$xml_content\" > $args{file_name}", 200);

}

sub append_ts2_xml {
    my %args = (
        testsuite_name => 'ts',
        file_name => '/tmp/junit.xml'
    );
    %args = @_;
    my $cmd_append_ts2_xml = << "EOF";
xmlstarlet ed  -P -L -s /testsuites -t elem -n testsuite -v '' \\
-i "/testsuites/testsuite[last()]" -t attr -n error -v 0 \\
-i "/testsuites/testsuite[last()]" -t attr -n failures -v 0 \\
-i "/testsuites/testsuite[last()]" -t attr -n hostname -v "`hostname`" \\
-i "/testsuites/testsuite[last()]" -t attr -n id -v '' \\
-i "/testsuites/testsuite[last()]" -t attr -n name -v \"$args{testsuite_name}\" \\
-i "/testsuites/testsuite[last()]" -t attr -n package -v \"$args{testsuite_name}\" \\
-i "/testsuites/testsuite[last()]" -t attr -n  skipped -v 0 \\
-i "/testsuites/testsuite[last()]" -t attr -n tests -v 0 \\
-i "/testsuites/testsuite[last()]" -t attr -n time -v '' \\
-i "/testsuites/testsuite[last()]" -t attr -n timestamp -v "`date +%Y-%m-%dT%X`" $args{file_name} \\
EOF
    assert_script_run($cmd_append_ts2_xml, 200);
}

# Update testsuites atturate value
sub update_tss_attr {
    my %args = (
        file_name => "/tmp/junit.xml",
        attr => 0,
        value => 0
    );
    %args = @_;
    my $cmd_update_tss_attr = << "EOF";
xmlstarlet ed -L -u /testsuites/\@$args{attr} -v $args{value}  $args{file_name} \\
EOF
    assert_script_run($cmd_update_tss_attr, 200);
}

# update testsuite atturate
sub update_ts_attr {
    my %args = (
        file_name => "/tmp/junit.xml",
        ts_position => -1,
        attr => 0,
        value => 0
    );
    %args = @_;
    my $cmd_update_ts_attr = << "EOF";
xmlstarlet ed -L -u "/testsuites/testsuite[last()]/\@$args{attr}" -v $args{value}  $args{file_name} \\
EOF
    assert_script_run($cmd_update_ts_attr, 200);
}

# Insert one test case to existing junit file
sub insert_tc2_xml {
    my %args = (
        file_name => "/tmp/junit.xml",
        class_name => '',
        case_status => 'pass',
        sys_output => '',
        sys_err => ''
    );
    %args = @_;
    my $cmd_insert_tc2_xml = << "EOF";
xmlstarlet ed  -L -s "/testsuites/testsuite[last()]" -t elem -n testcase -v "" \\
-s "/testsuites/testsuite[last()]/testcase[last()]" -t elem -n system-err -v "$args{sys_err}" \\
-s "/testsuites/testsuite[last()]/testcase[last()]" -t elem -n system-out -v "$args{sys_output}" \\
-i "/testsuites/testsuite[last()]/testcase[last()]" -t attr -n classname -v "$args{class_name}" \\
-i "/testsuites/testsuite[last()]/testcase[last()]" -t attr -n name -v "$args{class_name}" \\
-i "/testsuites/testsuite[last()]/testcase[last()]" -t attr -n status  -v "$args{case_status}" \\
-i "/testsuites/testsuite[last()]/testcase[last()]" -t attr -n time  -v "none" $args{file_name} \\
EOF

    assert_script_run($cmd_insert_tc2_xml, 200);
}

1;
