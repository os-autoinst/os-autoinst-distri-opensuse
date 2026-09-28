# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Smoke test Tumbleweed KubeVirt containerdisk image
# - install KubeVirt
# - deploy a VirtualMachineInstance using a containerDisk image
# - inject cloud-init user data and SSH public key
# - verify the guest reaches Ready and AgentConnected states
# - verify guest information can be retrieved through virtctl
# - verify SSH access using a cloud-init provisioned key
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call script_retry script_output_retry file_content_replace);
use mmapi 'get_current_job_id';
use power_action_utils;
use version_utils;
use containers::k8s;

my $vmi_user = 'test';
my $vmi_pubkey;
my $home;
my $vmi_ssh_key_path;
my $vmi_name;
my $vmi_image = get_var('CONTAINER_IMAGE_TO_TEST', 'registry.opensuse.org/opensuse/factory/totest/containers/opensuse/tumbleweed-kubevirt-minimal');

sub install_kubevirt {
    zypper_call('in kubevirt-manifests kubevirt-virtctl', timeout => 300);

    my $manifest_dir = script_output(
        q{find /usr/share -type f -path '*/manifests/release/kubevirt-operator.yaml' -printf '%h\n' -quit}
    );

    die 'KubeVirt manifest directory not found' unless $manifest_dir;

    record_info('KubeVirt manifests', $manifest_dir);

    assert_script_run("kubectl apply -f $manifest_dir/kubevirt-operator.yaml", 180);
    assert_script_run("kubectl apply -f $manifest_dir/kubevirt-cr.yaml", 180);

    assert_script_run('kubectl -n kubevirt wait kv kubevirt --for condition=Available --timeout=600s', 620);
    assert_script_run('kubectl get all -n kubevirt');
}

sub setup_ssh_files {
    $home = script_output('echo "$HOME"');
    $vmi_ssh_key_path = "$home/kubevirt-test-key";

    assert_script_run("rm -f $vmi_ssh_key_path $vmi_ssh_key_path.pub");
    assert_script_run("ssh-keygen -q -t ed25519 -N \"\" -f $vmi_ssh_key_path");
    $vmi_pubkey = script_output("cat $vmi_ssh_key_path.pub");
}

sub create_vmi_manifest {
    my ($job_id) = @_;

    $vmi_name = "tw-containerdisk-$job_id";

    setup_ssh_files();

    assert_script_run 'curl -o /tmp/containerdisk-vmi.yaml ' . data_url('containers/containerdisk-vmi.yaml');

    file_content_replace(
        '/tmp/containerdisk-vmi.yaml',
        '\$vmi_name' => $vmi_name,
        '\$image' => $vmi_image,
        '\$user' => $vmi_user,
        '\$pubkey' => $vmi_pubkey,
    );
}

sub wait_for_vmi {
    assert_script_run('kubectl apply -f /tmp/containerdisk-vmi.yaml', 180);

    assert_script_run("kubectl wait vmi/$vmi_name --for=condition=Ready --timeout=600s", 620);
    assert_script_run("kubectl wait vmi/$vmi_name --for=condition=AgentConnected --timeout=600s", 620);
    assert_script_run('kubectl get vmi,pods -o wide');

    my $launcher = script_output_retry(
        "kubectl get pods --no-headers -o custom-columns=':metadata.name' | grep '^virt-launcher-$vmi_name'",
        retry => 12,
        delay => 10
    );

    script_retry("kubectl logs $launcher --tail=100 | grep -E 'Started|Domain|VirtualMachineInstance|qemu|libvirt'", retry => 12, delay => 10);
}

sub guest_cmd {
    my ($cmd) = @_;

    return "virtctl ssh vmi/$vmi_name " .
      "--username $vmi_user " .
      "--identity-file $vmi_ssh_key_path " .
      "--local-ssh-opts='-o StrictHostKeyChecking=no' " .
      "--command \"$cmd\"";
}

sub wait_for_ip_and_ssh {
    my $vmi_ip = script_output_retry(
        "kubectl get vmi $vmi_name -o jsonpath='{.status.interfaces[0].ipAddress}'",
        retry => 30,
        delay => 10
    );

    script_retry(
        "nc -vz $vmi_ip 22",
        retry => 30,
        delay => 10
    );
}

sub verify_guest {
    script_retry(
        "kubectl get vmi $vmi_name -o jsonpath='{.status.phase}' | grep Running",
        retry => 30,
        delay => 10
    );

    assert_script_run("kubectl wait vmi/$vmi_name --for=condition=AgentConnected --timeout=600s", 620);
    assert_script_run("virtctl guestosinfo $vmi_name", 120);

    wait_for_ip_and_ssh();

    assert_script_run(guest_cmd('true'));
    validate_script_output(guest_cmd('cat /var/tmp/cloud-init-ok'), qr/OK/);
}

sub cleanup_vmi {
    script_run('kubectl delete -f /tmp/containerdisk-vmi.yaml --ignore-not-found=true');
    script_run("kubectl delete vmi $vmi_name --ignore-not-found=true") if $vmi_name;
    script_run("rm -f $vmi_ssh_key_path $vmi_ssh_key_path.pub") if $vmi_ssh_key_path;
}

# Gets the currently used kernel flavor, e.g. `kernel-default`
sub current_kernel_flavor {
    return script_output(q{
        rpm -qf /boot/config-$(uname -r) \
        | sed -r 's/-[0-9].*$//'
    });
}

sub install_kernel_with_kvm_support {
    my ($self) = @_;

    return if current_kernel_flavor eq 'kernel-default';

    record_info("Installing kernel-default instead of " . current_kernel_flavor);

    # exactly in this order otherwise
    # the installed kernel-default-base-XXX conflicts with 'kernel-default = XXX' provided by the to be installed kernel-default-XXX
    zypper_call('in kernel-default -' . current_kernel_flavor, timeout => 300);

    power_action('reboot', textmode => 1);
    $self->wait_boot(bootloader_time => 300);
    select_serial_terminal;
}

sub install_deps {
    my @deps = (
        "netcat-openbsd",
    );

    zypper_call("in @deps");
}

sub run {
    my ($self, $run_args) = @_;
    my $job_id = get_current_job_id();

    select_serial_terminal;

    install_deps;

    $self->install_kernel_with_kvm_support if is_jeos;

    record_info('ContainerDisk', $vmi_image);

    install_kubevirt();

    create_vmi_manifest($job_id);
    wait_for_vmi();
    verify_guest();

    cleanup_vmi();
}

sub post_fail_hook {
    if ($vmi_name) {
        script_run("kubectl describe vmi $vmi_name");
        script_run('kubectl get pods -o wide');
        script_run("kubectl logs --tail=200 \$(kubectl get pods --no-headers -o custom-columns=':metadata.name' | grep '^virt-launcher-$vmi_name' | head -n1)");
        script_run("virtctl guestosinfo $vmi_name");
        cleanup_vmi();
    } else {
        record_info('No VMI', 'Skipping detailed debug output since VMI name is not set');
    }

    script_run('kubectl -n kubevirt get pods -o wide');
    script_run('kubectl -n kubevirt describe kv kubevirt');
    script_run('kubectl -n kubevirt get events --sort-by=.lastTimestamp');
}

1;
