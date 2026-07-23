# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Upgrade K8s manifest (OS and K8s images)
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use Mojo::Base 'opensusebasetest';
use testapi;
use elemental3;
use serial_terminal qw(select_serial_terminal);
use utils qw(file_content_replace);

sub run {
    my ($self) = @_;
    my $arch = get_required_var('ARCH');
    my $k8s = get_required_var('K8S');
    my $k8s_version_prefix = get_required_var('K8S_VERSION_PREFIX');
    my $totest_path = get_required_var('TOTEST_PATH');

    # Add static hosts if needed
    # TODO: use a support-server to add a DNS server with internal LAN access?
    my $static_hosts = script_output('sed -n \'/^# BEGIN_STATIC_HOSTS$/,/^# END_STATIC_HOSTS$/p\' /etc/hosts | grep -v ^#');
    if ($static_hosts ne '' && $k8s eq 'rke2') {
        my $ns = '-n kube-system';
        my $configmap = 'rke2-coredns-rke2-coredns';
        my $yaml_file = 'coredns-configmap.yaml';
        my $s = ' ' x 4;

        # Remove the last newline and replace the other ones with '@', otherwise sed will fail
        chomp($static_hosts);
        $static_hosts =~ s/\R/@/g;
        $static_hosts = '@' . ${static_hosts};

        # Get the configmap to patch
        kubectl_cmd(cmd => "${ns} get configmap ${configmap} -o yaml >${yaml_file}");
        assert_script_run(
            "sed -i -e 's/\\(\\.:53.*\\)/\\1\\n${s}${s}hosts {${static_hosts}\\n${s}${s}${s}fallthrough\\n${s}${s}}/' -e 's/@/\\n${s}${s}${s}/g' ${yaml_file}"
        );

        # Apply the patch
        # NOTE: kubectl_cmd cannot be used for the 'rollout status' command!
        kubectl_cmd(cmd => "${ns} apply -f ${yaml_file}");
        kubectl_cmd(cmd => "${ns} rollout restart deployment -l k8s-app=kube-dns");
        assert_script_run("kubectl ${ns} rollout status deployment -l k8s-app=kube-dns", timeout => bmwqemu::scale_timeout('300'));
    }

    my $uri = get_container_uri(
        url => $totest_path,
        arch => $arch,
        regex =>
          ".*${k8s}-manifest-\(${k8s_version_prefix}\\.[0-9]*\)-\(.*\)"
    );
    my ($url, $version) = split(/:/, $uri);
    record_info('Upgrade URI', "url: ${url} / version: ${version}");

    # Add an upgrade plan
    my $upgrade_file = 'upgrade-manifest.yaml';
    assert_script_run(
        "curl -sf -o ${upgrade_file} "
          . data_url("elemental3/${upgrade_file}")
    );
    file_content_replace(
        $upgrade_file,
        '%MANIFEST_URL%' => "$url",
        '%MANIFEST_VERSION%' => "$version"
    );
    record_info('Upgrade Plan', script_output("cat ${upgrade_file}"));

    # Apply upgrade plan
    kubectl_cmd(cmd => "apply -f ${upgrade_file}");
    record_info('Upgrade Plan status', script_output('kubectl get release upgrade-manifest -o yaml 2>&1'));

    # Select SUT for bootloader
    select_console('sut');

    # OS upgrade is done automatically as well as the reboot after upgrade
    # We just have to wait for the VM to reboot
    $self->wait_boot(bootloader_time => bmwqemu::scale_timeout(900), textmode => 1, nologin => 1);

    # Set default root password
    $testapi::password = get_required_var('TEST_PASSWORD');

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # Check K8s status
    wait_k8s_state(regex => 'status.*restarts|(1/1|2/2|3/3|4.4).*running|0/1.*completed', timeout => bmwqemu::scale_timeout('1200'));

    # Check upgrade status after reboot
    my $upgrade_version = wait_script_output(cmd => 'kubectl get release upgrade-manifest -o jsonpath={.spec.version}', timeout => 300);

    # Record upgrade status
    record_info('Upgrade done', "Upgrade to version '${upgrade_version}' done successfully!");
    record_info('Upgrade status', script_output('kubectl get release upgrade-manifest -o yaml 2>&1'));
}

sub post_fail_hook {
    my ($self) = @_;

    record_info(__PACKAGE__ . ':' . 'post_fail_hook');

    # Check upgrade status
    record_info('Post Fail Upgrade', script_output('kubectl get release upgrade-manifest -o yaml 2>&1'));

    # Useful to debug K8s starting issues
    foreach my $svc ('k8s-resource-installer', 'k3s', 'rke2-server') {
        script_run("journalctl -xeu $svc.service > /tmp/${svc}_journal.log");
        upload_logs("/tmp/${svc}_journal.log", failok => 1);
    }

    # Execute the common part
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
