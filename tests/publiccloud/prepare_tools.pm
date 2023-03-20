# SUSE's openQA tests
#
# Copyright 2018-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: python3-pip python3-virtualenv python3-ec2imgutils aws-cli
# python3-img-proof azure-cli
# Summary: Install IPA tool
#
# Maintainer: qa-c team <qa-c@suse.de>, QE-SAP <qe-sap@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_opensuse);
use repo_tools 'generate_version';

sub create_script_file {
    my ($filename, $fullpath, $content) = @_;
    save_tmp_file($filename, $content);
    assert_script_run(sprintf('curl -o "%s" "%s/files/%s"', $fullpath, autoinst_url, $filename));
    assert_script_run(sprintf('chmod +x %s', $fullpath));
}

sub install_in_venv {
    my ($binary, %args) = @_;
    die("Need to define path to requirements.txt or list of packages") unless $args{pip_packages} || $args{requirements};
    die("Missing binary name") unless ($binary);
    my $install_timeout = 15 * 60;
    assert_script_run(sprintf('curl -f -v %s/data/publiccloud/venv/%s.txt > /tmp/%s.txt', autoinst_url(), $binary, $binary)) if defined($args{requirements});

    my $venv = '/root/.venv_' . $binary;
    assert_script_run("python3 -m venv $venv");
    assert_script_run("source '$venv/bin/activate'");
    my $what_to_install = defined($args{requirements}) ? sprintf('-r /tmp/%s.txt', $binary) : $args{pip_packages};
    assert_script_run('pip install --force-reinstall ' . $what_to_install, timeout => $install_timeout);
    assert_script_run('deactivate');
    my $script = <<EOT;
#!/bin/sh
. "$venv/bin/activate"
if [ ! -e "$venv/bin/$binary" ]; then
   echo "Missing $binary in virtualenv $venv"
   deactivate
   exit 2
fi
$binary "\$@"
exit_code=\$?
deactivate
exit \$exit_code
EOT

    my $fullpath = "$venv/bin/$binary-run-in-venv";
    create_script_file($binary, $fullpath, $script);
    assert_script_run(sprintf('ln -s %s /usr/bin/%s', $fullpath, $binary));
}

sub run {
    my $PUBLISH_HDD_1 = get_required_var("PUBLISH_HDD_1");

    select_serial_terminal;

    if (my $tools_repo = get_var('PUBLIC_CLOUD_TOOLS_REPO')) {
        for my $repo (split(/\s+/, $tools_repo)) {
            zypper_call('ar ' . $repo);
        }
    }

    ensure_ca_certificates_suse_installed();

    # Install prerequisite packages test
    zypper_call('-q in python3-pip python3-devel python3-img-proof python3-img-proof-tests podman docker jq rsync');
    record_info('python', script_output('python --version'));
    systemctl('enable --now docker');
    assert_script_run('podman ps');
    assert_script_run('docker ps');

    # Install AWS cli
    install_in_venv('aws', requirements => 1);
    record_info('EC2', script_output('aws --version'));

    # Install ec2imgutils
    install_in_venv('ec2uploadimg', requirements => 1);
    record_info('ec2imgutils', 'ec2uploadimg:' . script_output('ec2uploadimg --version'));

    # Install Azure cli
    install_in_venv('az', requirements => 1);
    my $azure_error = '/tmp/azure_error';
    record_info('Azure', script_output('az -v 2>' . $azure_error));
    assert_script_run('cat ' . $azure_error);
    if (script_run('test -s ' . $azure_error)) {
        die("Unexpected error in azure-cli") unless validate_script_output("cat $azure_error", m/Please let us know how we are doing .* and let us know if you're interested in trying out our newest features .*/);
    }

    # Install OpenStack cli
    install_in_venv('openstack', requirements => 1);
    record_info('OpenStack', script_output('openstack --version'));

    # Install Google Cloud SDK
    assert_script_run("export CLOUDSDK_CORE_DISABLE_PROMPTS=1");
    assert_script_run("curl sdk.cloud.google.com | bash");
    assert_script_run("echo . /root/google-cloud-sdk/completion.bash.inc >> ~/.bashrc");
    assert_script_run("echo . /root/google-cloud-sdk/path.bash.inc >> ~/.bashrc");
    record_info('GCE', script_output('source ~/.bashrc && gcloud version'));

    # Create some directories, ipa will need them
    assert_script_run("img-proof list");
    my $img_proof_ver = script_output('img-proof --version');
    record_info('img-proof', $img_proof_ver);
    set_var('PUBLIC_CLOUD_IMG_PROOF_VER', $img_proof_ver =~ /img-proof, version ([\d\.]+)/);

    my $terraform_version = get_var('TERRAFORM_VERSION', '1.3.6');
    # Terraform in a container
    my $terraform_wrapper = <<EOT;
#!/bin/bash -e
podman run --rm -w=\$PWD -v /root/:/root/ --env-host=true docker.io/hashicorp/terraform:$terraform_version \$@
EOT

    create_script_file('terraform', '/usr/local/bin/terraform', $terraform_wrapper);
    validate_script_output("terraform -version", qr/$terraform_version/);
    record_info('Terraform', script_output('terraform -version'));

    # Ansible install with pip
    # Default version is chosen as low as possible so it run also on SLE12's
    # ANSIBLE_CORE_VERSION should be set only if the different then default one need to be used
    my $ansible_version = get_var('ANSIBLE_VERSION', '4.10.0');
    my $ansible_core_version = get_var('ANSIBLE_CORE_VERSION');
    my $ansible_install_log = '/tmp/ansible_install.log';

    assert_script_run("python3 -m pip install --no-input -q --no-color --log $ansible_install_log ansible==$ansible_version", timeout => 240);
    upload_logs("$ansible_install_log", failok => 1);

    if (length $ansible_core_version) {
        my $ansible_core_install_log = "/tmp/ansible_core_install.log";
        assert_script_run("python3 -m pip install --no-input -q --no-color --log $ansible_core_install_log ansible-core==$ansible_core_version", timeout => 240);
        upload_logs("$ansible_core_install_log", failok => 1);
    }
    record_info('Ansible', script_output('ansible --version'));

    # Kubectl in a container
    my $kubectl_version = get_var('KUBECTL_VERSION', 'v1.22.12');
    assert_script_run("curl -Lo /usr/bin/kubectl https://dl.k8s.io/release/$kubectl_version/bin/linux/amd64/kubectl");
    assert_script_run("curl -Lo /usr/bin/kubectl.sha256 https://dl.k8s.io/$kubectl_version/bin/linux/amd64/kubectl.sha256");
    assert_script_run('echo "$(cat /usr/bin/kubectl.sha256)  /usr/bin/kubectl" | sha256sum --check');
    assert_script_run('chmod +x /usr/bin/kubectl');
    record_info('kubectl', script_output('kubectl version --client=true'));

    # Remove persistent net rules, necessary to boot the x86_64 image in the aarch64 test runs
    assert_script_run('rm /etc/udev/rules.d/70-persistent-net.rules');

    # Add marker file for PC tools image
    assert_script_run("echo -e 'PC tools image\\nHDD: $PUBLISH_HDD_1' > /root/pc_tools_image.txt");

    select_console 'root-console';
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

=head1 Discussion

Install public cloud tools in SLE image. This image gets published and can be used
for specific tests for azure, amazon and google CSPs.

=head1 Configuration

=head2 PUBLIC_CLOUD_PREPARE_TOOLS

Activate this test module by setting this variable.

=head2 PUBLIC_CLOUD_TOOLS_REPO

The URL to the cloud:tools repo (optional).
(e.g. http://download.opensuse.org/repositories/Cloud:/Tools/openSUSE_Tumbleweed/Cloud:Tools.repo)

=head2 README

For more information see the README.md file in /var/lib/openqa/share/tests/opensuse/tools/pctools

=cut
