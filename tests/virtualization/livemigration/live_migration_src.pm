# Copyright © 2021 SUSE LLC
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
# Summary: Live migration test for source host
# The live_migration_src.pm module works together with prepare_profile, boot_from_pxe, installation and login_console
# to fulfill live migration test. The latter 4 modules are meant for src/dst host insatllation and configurationsrc.
#
# live_migration_src.pm features:
# - Create VMs from config xml if reusable or insatll via autoyast which is created from template.
# - Check if VMs are created or insatlled, ready for migration test
# - Set up passwordless ssh authentication login dst host
# - Execute live migration test (xen/kvm)
# - clean up
#
# note:
#  1. A external nfs shared storage can be specified by NFS_PATH. If not specified, /tmp/vm_images on src host will be exported.
#  2. VMs are installed concurrently. Migration test and VM insatllation occur concurrently too.
#  3. This test job can be scheduled without hosts installation by appending "IPMI_DO_NOT_RESTART_HOST=1 HOST_INSTALL=0".
#  4. If CREATE_PARTITIONS=1 is specified /tmp/vm_images on hosts will be deleted before host installation.
#  5. Vars like: REPO_SLES15SP3FV, REPO_SLES15SP3KVM can be specified to add repos into respective VMs during installation.
#
# Maintainer: Tony Yuan <tyuan@suse.com>

package live_migration_src;
use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use version_utils 'is_sle';
use Utils::Systemd 'systemctl';
use utils qw(zypper_call zypper_ar);
use File::Copy 'copy';
use File::Path 'make_path';
use lockapi;
use mmapi;
use scheduler 'get_test_suite_data';
use virt_autotest::utils 'collect_virt_system_logs';

my $vms = {};    #the totel number of vm to be tested.
my $images_path = "/var/lib/libvirt/images";
my $sut_ip = get_var('SUT_IP');
my $inst_src = get_test_suite_data()->{location};
my $dst_ip;

#Generate a autoyast profile for a vm to be insatlled.
sub create_profile {
    my ($guest, $vm_name, $version, $arch, $vdisk_type, $ltss_code) = @_;
    #    my ($guest, $vm_name, $version, $arch, $vdisk_type) = @_;
    my $nfs_path = get_var("NFS_PATH") ? get_var("NFS_PATH") : get_var('SUT_IP') . ":/tmp/vm_images";
    my $path = $version >= 15 ? "virtualization/livemigration/guest_15.xml.ep" : "virtualization/livemigration/guest_12.xml.ep";
    my $scc_code = get_required_var("SCC_REGCODE");
    my $profile = get_test_data($path);
    $profile =~ s/\{\{SCC_REGCODE\}\}/$scc_code/g;
    $profile =~ s/\{\{ARCH\}\}/$arch/g;
    $profile =~ s/\{\{VERSION\}\}/$version/g;
    $profile =~ s/\{\{SUT_IP\}\}/$sut_ip/g;
    $profile =~ s/\{\{GUEST\}\}/$vm_name/g;
    $profile =~ s/\{\{DISK_TYPE\}\}/$vdisk_type/g;
    $profile =~ s/\{\{IP_PATH\}\}/$nfs_path\/guestip/g;
    my $vars = {
        vm_name => $vm_name,
        ltss_code => $ltss_code,
        repos => [split(/,/, get_var("REPO_" . uc($vm_name =~ s/-//gr), ''))]
    };
    my $output = Mojo::Template->new(vars => 1)->render($profile, $vars);
    save_tmp_file("$vm_name.xml", $output);
    # Copy profile to ulogs directory, so profile is available in job logs
    make_path('ulogs');
    copy(hashed_string("$vm_name.xml"), "ulogs/$vm_name.xml");
    return autoinst_url . "/files/$vm_name.xml";
}

#start a vm fresh install if its config xml isn't avaible in $images_path/vm-configs/ for reuse.
sub create_vm {
    my ($vms, $guest, $vm_type, $arch) = @_;
    my $version = $guest =~ /-sp/ ? $guest =~ s/.*-(\d+)-sp(\d)/$1.$2/r : $guest =~ s/.*-(\d+)/$1/r;
    my $virt_insatll = "/usr/bin/virt-install --noautoconsole --network bridge=br0 --vcpus 2,maxvcpus=4 --memory 2048,maxmemory=4096 --events on_reboot=destroy --video=vga --serial pty";
    my $migrate_opts = "--live --p2p --change-protection --unsafe --compressed --abort-on-error";
    my $vtype = $vm_type eq "fv" ? "-v" : "";    #empty string stands for virt-install default;
    my $disk_type = $vm_type eq "kvm" ? "vda" : "xvda";
    my $machine = $vm_type eq "kvm" ? "q35" : "xen$vm_type";
    my $vm_name = "$guest-$vm_type";
    if (script_run("[[ -f $images_path/vm-configs/$vm_name.xml ]]") == 0) {
        is_sle('>15') ? assert_script_run("sed -i '/<kernel>.*lib/s/lib/share/' $images_path/vm-configs/$vm_name.xml") : assert_script_run("sed -i '/<kernel>.*share/s/share/lib/' $images_path/vm-configs/$vm_name.xml") if $vm_name =~ /pv/;
        assert_script_run("virsh define --file $images_path/vm-configs/$vm_name.xml");
        assert_script_run("virsh start $vm_name");
        $vms->{$vm_name} = {reuse => 1};
    } else {
        my %ltss_products = @{get_var_array("LTSS_PRODUCTS")};
        my $ay_url = create_profile($guest, $vm_name, $version, $arch, $disk_type, $ltss_products{$version});
        my $os_variant = $version >= 15 ? $guest =~ s/(s-|-)//gr : $guest =~ s/-//gr;
        if (script_run("osinfo-query os short-id=$os_variant") != 0) {
            $os_variant = $version >= 15 ? "sle15-unknown" : "sles12-unknown";
        }
        $vms->{$vm_name}->{install_cmd} = "$virt_insatll --machine $machine --os-variant=$os_variant --name $vm_name $vtype --disk path=$images_path/$vm_name.qcow2,size=20 --location $inst_src->{$guest} -x autoyast=$ay_url --graphics vnc,listen=0.0.0.0";
        record_info($vms->{$vm_name}->{install_cmd});
        assert_script_run($vms->{$vm_name}->{install_cmd});
    }
    if ($vm_type eq "kvm") {
        $vms->{$vm_name}->{dsturi} = "qemu+ssh://$dst_ip/system";
        $vms->{$vm_name}->{virsh_cmds} = ["virsh migrate $migrate_opts", "virsh migrate $migrate_opts --tunnelled"];
    } else {
        $vms->{$vm_name}->{dsturi} = "xen+ssh://$dst_ip/";
        $vms->{$vm_name}->{virsh_cmds} = ["virsh migrate --live", "xl migrate"];
    }
}

#start a guest, a guest represents a vm for kvm test, two vms for xen test (a fv and a pv)
sub start_guest {
    my ($guest, $vms) = @_;
    if (check_var('SYSTEM_ROLE', 'kvm')) {
        create_vm($vms, $guest, "kvm", "x86_64");
    } elsif (check_var('SYSTEM_ROLE', 'xen')) {
        create_vm($vms, $guest, "fv", "x86_64");
        create_vm($vms, $guest, "pv", "x86_64");
    }
}

# perform live migration test and clean vm up after.
sub migrate_test {
    my ($vm_name, $vm_info) = @_;
    for my $cmd (@{$vm_info->{virsh_cmds}}) {
        #check if ip file is created. timeouts after 2 mins
        assert_script_run("check_ip_file(){ for i in \$(seq 1 18);do if [ -f $images_path/guestip/$vm_name ]; then sleep 10; return; else sleep 10; fi; done; false; }; check_ip_file");
        $vm_info->{ip} = script_output("cat $images_path/guestip/$vm_name");

        if ("$cmd" eq "xl migrate") {
            record_info("$cmd $vm_name $dst_ip");
            assert_script_run("$cmd $vm_name $dst_ip");
        } else {
            record_info("$cmd $vm_name $vm_info->{dsturi}");
            assert_script_run("$cmd $vm_name $vm_info->{dsturi}");
        }
        #soft_failure bsc#1190309
        if ($vm_name =~ /fv/ && script_run("ssh root\@$dst_ip ip link show type bridge_slave | grep 'vif.*state DOWN'") == 0) {
            record_soft_failure("bsc#1190309");
            assert_script_run("ssh root\@$dst_ip xl list $vm_name");
        }
        #visit web server running in vm check it's content
        validate_script_output("curl -s http://$vm_info->{ip}/guest", sub { m/This is guest $vm_name/ });
        #test vm disk write and read
        assert_script_run("echo $vm_name > /tmp/test_vm_write");
        assert_script_run("curl -s -k -T /tmp/test_vm_write -u bernhard:$testapi::password scp://$vm_info->{ip}/~/test_vm_write");
        validate_script_output("curl -s -k -u bernhard:$testapi::password scp://$vm_info->{ip}/~/test_vm_write", sub { m/$vm_name/ });
        assert_script_run("rm $images_path/guestip/$vm_name");
        #shutdown migrated vm
        if ($cmd eq "xl migrate") {
            assert_script_run("ssh root\@$dst_ip xl shutdown $vm_name");
        } else {
            assert_script_run("ssh root\@$dst_ip virsh shutdown $vm_name");
        }
        #wait for shutdown complete
        sleep 25;
        #start again for next migration test
        assert_script_run("virsh start $vm_name") if ($cmd ne $vm_info->{virsh_cmds}->[-1]);
    }
}

#clean up VMs on a host before migration test rerun
sub cleanup_for_rerun {
    systemctl("restart libvirtd");
    if (check_var('SYSTEM_ROLE', 'xen')) {
        assert_script_run('for i in $(xl list |cut -d " " -f1|grep sles);do xl shutdown $i;done');
        sleep 30;
        assert_script_run('for i in $(xl list |cut -d " " -f1|grep sles);do xl destroy $i;done');
    } else {
        assert_script_run('for i in $(virsh list --name|grep sles);do virsh shutdown $i;done');
        sleep 30;
        assert_script_run('for i in $(virsh list --name|grep sles);do virsh destroy $i;done');
    }
    assert_script_run('for i in $(virsh list --name --inactive); do virsh undefine $i;done');
    assert_script_run("if mountpoint $images_path; then umount $images_path; fi") unless get_var("NFS_PATH");
}

sub cleanup {
    my ($vm_name, $vm_info) = @_;
    unless ($vm_info->{reuse}) {
        assert_script_run("virsh dumpxml $vm_name > $images_path/vm-configs/$vm_name.xml");
        #vm created on later version hypervisors can be reused on earlier verions hypervisors
        assert_script_run(qq(sed -i "s/machine='.*q35.*'/machine='q35'/" $images_path/vm-configs/$vm_name.xml)) if ($vm_name =~ /kvm/);
    }
    assert_script_run("virsh undefine $vm_name");
}

sub run {
    select_console 'root-ssh';
    #    cleanup_for_rerun if (check_var('HOST_INSTALL', 0));
    if (check_var('HOST_INSTALL', 0)) {
        cleanup_for_rerun;
    } else {
        upload_logs('/var/log/zypp/history');
    }
    $dst_ip = get_job_autoinst_vars(get_parents->[0])->{SUT_IP};
    record_info("SRC: $sut_ip");
    record_info("DST: $dst_ip");
    #Mount with sync to make sure any write be flushed to the server before the system call returns control
    assert_script_run("mount -o sync $sut_ip:/tmp/vm_images $images_path") unless get_var("NFS_PATH");
    assert_script_run("rm -rf $images_path/guestip; mkdir $images_path/guestip");
    assert_script_run("mkdir -p $images_path/vm-configs");
    assert_script_run("mkdir -p $images_path/test_state");
    if (is_sle('<12-sp4')) {
        zypper_ar($inst_src->{"sles-12-sp4"}, name => "curl_12sp4");
        zypper_call("up libcurl4");
    }
    my $guests = get_var_array('GUESTS');
    #start all guests
    for my $guest (@{$guests}) { start_guest($guest, $vms); }

    assert_script_run('if [ -d /root/.ssh ]; then rm -rf /root/.ssh; fi');
    assert_script_run('ssh-keygen -t rsa -q -f "/root/.ssh/id_rsa" -N ""');

    mutex_wait 'dst_ready';

    assert_script_run("ssh-keyscan $dst_ip > /root/.ssh/known_hosts");
    assert_script_run("curl -s -k --user root:$testapi::password -T .ssh/id_rsa.pub sftp://$dst_ip/root/.ssh/authorized_keys  --ftp-create-dirs");
    assert_script_run("ssh root\@$dst_ip mount -o sync $sut_ip:/tmp/vm_images $images_path") unless get_var("NFS_PATH");
    #clear ring buffer on src and dst hosts
    assert_script_run("dmesg -C");
    assert_script_run("ssh root\@$dst_ip dmesg -C");

    my $n = keys %$vms;
    my $time_cont = 0;
    #Check each vm if their have got IP address. If they have, their install or stratup are supposed to complete and ready for migration test.
    until ($n == 0) {
        while (my ($vm_name, $vm_info) = each %$vms) {
            next if ($vm_info->{finish} == 1);
            #check if vm write its IP address in $images_path/guestip/$vm_name on src host.
            if (script_run("[[ -f $images_path/guestip/$vm_name ]]") == 0) {
                record_info("$vm_name: ready");
                migrate_test($vm_name, $vm_info);
                cleanup($vm_name, $vm_info);
                $vm_info->{finish} = 1;
                $n--;
            } else {
                die("$vm_name startup time out after " . $time_cont * 2 . " minutes") if ($time_cont == 40);
                my $vm_state = script_output("virsh domstate --domain $vm_name");
                if ($vm_state eq "shut off") {
                    assert_script_run("virsh start $vm_name");
                    record_info("Reboot: $vm_name install");
                }
            }
        }
        sleep 120 if ($n != 0);
        $time_cont++;
        # record_info("$time_cont");
    }
}

sub post_run_hook {
    my $self = shift;
    #collect ring buffer log and upload
    assert_script_run("dmesg --level=emerg,crit,alert,err > /tmp/dmesg_err.txt");
    upload_logs('/tmp/dmesg_err.txt') if (script_run("[[ -s  /tmp/dmesg_err.txt ]]") == 0);
    #create a state file on shared storage to inform dst test not to collect logs if src test are done and passed
    assert_script_run("touch $images_path/test_state/test_done");
    barrier_wait 'let_dst_upload_logs';
}

sub post_fail_hook {
    my $self = shift;
    barrier_wait 'let_dst_upload_logs';    #Inform dst host to collect logs
    diag("live migration failed");
    collect_virt_system_logs;
    $self->SUPER::post_fail_hook;
}

1;
