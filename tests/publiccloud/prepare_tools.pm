# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: python3-pip python3-virtualenv python3-ec2imgutils aws-cli
# python3-img-proof azure-cli
# Summary: Install IPA tool
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>, qa-c team <qa-c@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use registration 'add_suseconnect_product';
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
    assert_script_run("virtualenv '$venv'");
    assert_script_run(". '$venv/bin/activate'");
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
    my ($self) = @_;

    $self->select_serial_terminal;

    if (my $tools_repo = get_var('PUBLIC_CLOUD_TOOLS_REPO')) {
        for my $repo (split(/\s+/, $tools_repo)) {
            zypper_call('ar ' . $repo);
        }
    }

    ensure_ca_certificates_suse_installed();

    # Install prerequesite packages test
    zypper_call('-q in python3-pip python3-devel python3-virtualenv python3-img-proof python3-img-proof-tests podman docker jq rsync');
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

    my $terraform_version = '1.1.7';
    # Terraform in a container
    my $terraform_wrapper = <<EOT;
#!/bin/sh
podman run -v /root/:/root/ --rm --env-host=true -w=\$PWD docker.io/hashicorp/terraform:$terraform_version \$@
EOT

    create_script_file('terraform', '/usr/bin/terraform', $terraform_wrapper);
    record_info('Terraform', script_output('terraform -version'));

    # Kubectl in a container
    my $kubectl_version = '1.22';
    my $kubectl_wrapper = <<EOT;
#!/bin/sh
podman run -v /root/:/root/ --rm docker.io/bitnami/kubectl:$kubectl_version \$@
EOT

    create_script_file('kubectl', '/usr/bin/kubectl', $kubectl_wrapper);
    record_info('kubectl', script_output('kubectl version --client=true'));

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

=cut
