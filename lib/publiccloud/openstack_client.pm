# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for OpenStack connection and authentication
#
# Maintainer: qa-c team <qa-c@suse.de>

package publiccloud::openstack_client;
use Mojo::Base -base;
use testapi;
use utils qw(file_content_replace);

use constant {
    OS_CONFIG_FILE => '/root/.config/openstack/clouds.yaml',
    CLOUD_INIT_FILE => '/root/mn_jeos.cloud-init'
};

has auth_uri => sub { get_required_var('OPENSTACK_AUTH_URI') };
has project_name => sub { get_required_var('OPENSTACK_PROJECT_NAME') };
has project_id => sub { get_required_var('OPENSTACK_PROJECT_ID') };
has region => sub { get_var('OPENSTACK_REGION', 'CustomRegion') };
has username => sub { get_var('OPENSTACK_USER', 'sles') };

sub _check_credentials {
    my ($self) = @_;
    my $max_tries = 6;

    for my $i (1 .. $max_tries) {
        my $out = script_output('openstack image list', 300, proceed_on_failure => 1);
        record_info('cli check', $out);
        # There are multiple possible error messages, e.g.:
        #   The request you have made requires authentication
        #   Failed to discover available identity versions
        #   Missing value auth-url required for auth plugin password
        #   Cloud mycloud was not found
        #   Could not find a suitable TLS CA certificate bundle, invalid path
        # But if the command succeeds, it will return an ASCII table with 3 columns: ID, Name, Status
        return 1 if ($out =~ /\| ID.*| Name.*| Status.*|/m);
        sleep 30;
    }
    return;
}

sub init {
    my ($self, %params) = @_;

    assert_script_run('mkdir -p /root/.config/openstack');
    assert_script_run('curl ' . data_url("jeos/clouds.yaml") . ' -o ' . OS_CONFIG_FILE);
    my $ci_data = get_var('CI_DATA_FILE', 'jeos/mn_jeos.cloud-init');
    assert_script_run('curl ' . data_url("$ci_data") . ' -o ' . CLOUD_INIT_FILE);

    # terraform complains if the certificate is in /usr/share/pki/trust/anchors/
    #    "Error: Error parsing CA Cert from /usr/share/pki/trust/anchors/SUSE_Trust_Root.crt.pem"
    # but it works if it's in root directory
    assert_script_run('cp /usr/share/pki/trust/anchors/SUSE_Trust_Root.crt.pem /root/SUSE_Trust_Root.crt.pem');

    my $user = get_required_var('_SECRET_OPENSTACK_CLOUD_USER');
    my $password = get_required_var('_SECRET_OPENSTACK_CLOUD_PASSWORD');

    file_content_replace(OS_CONFIG_FILE,
        q(%OPENSTACK_USER%) => $user,
        q(%OPENSTACK_PASSWORD%) => $password,
        q(%OPENSTACK_AUTH_URI%) => $self->auth_uri,
        q(%OPENSTACK_PROJECT_NAME%) => $self->project_name,
        q(%OPENSTACK_PROJECT_ID%) => $self->project_id);

    file_content_replace(CLOUD_INIT_FILE, q(%PASSWORD%) => $testapi::password);

    if (get_var('CI_VERIFICATION')) {
        file_content_replace(CLOUD_INIT_FILE, q(%SCC_REGCODE%) => get_var('SCC_REGCODE'));
        file_content_replace(CLOUD_INIT_FILE, q(%SCC_URL%) => sprintf(' --url=%s', get_var('SCC_URL', '')));

        my %pkeys = (rsa => 2048, ecdsa => 521);
        while (my ($t, $bits) = each(%pkeys)) {
            assert_script_run(qq[ssh-keygen -t $t -b $bits -N '' -f ~/.ssh/test_ci_$t -C "Tester key $t"]);
            my @pubkey = script_output("cat ~/.ssh/test_ci_$t.pub");
            file_content_replace(CLOUD_INIT_FILE, uc("%SSH_PUBK_$t%") => join(' ', @pubkey));
        }
    }

    record_info("cloud-init", script_output('cat ' . CLOUD_INIT_FILE));

    assert_script_run('chmod 644 ' . OS_CONFIG_FILE);
    assert_script_run('export OS_CLOUD=mycloud');
    assert_script_run('cat ' . OS_CONFIG_FILE);
    assert_script_run('cat ' . CLOUD_INIT_FILE);

    die('Credentials are invalid') unless ($self->_check_credentials());
}

sub cleanup {
    my ($self) = @_;
}

1;
