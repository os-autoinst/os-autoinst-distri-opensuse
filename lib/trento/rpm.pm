# SUSE's openQA tests
#
# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper functions for the Trento RPM tests
# Maintainer: Trento team <trento-developers@suse.com>

package trento::rpm;

use strict;
use warnings;
use base 'Exporter';
use Exporter;
use testapi;
use utils qw(zypper_call file_content_replace random_string);
use version_utils qw(is_sle);
use Carp qw(croak);

=head1 SYNOPSIS

Library with helpers to deploy and validate Trento from RPM packages,
using the repositories of a maintenance incident.

=cut

our @EXPORT = qw(
  trento_rpm_install_ansible_trento
  trento_rpm_setup_tls
  trento_rpm_prepare_ansible
  trento_rpm_run_playbook
);

use constant TLS_DIR => '/root/trento-tls';
use constant INVENTORY => '/root/trento-inventory.yml';
use constant PLAYBOOK_LOG => '/var/log/trento-ansible-playbook.log';

=head2 trento_rpm_install_ansible_trento

    trento_rpm_install_ansible_trento();

Install ansible-trento. The package comes from the incident when the incident
includes it, and from the released repositories otherwise.

=cut

sub trento_rpm_install_ansible_trento {
    zypper_call('in ansible-trento');
    record_info('ansible-trento', script_output('rpm -q ansible-trento'));
}

=head2 trento_rpm_setup_tls

    trento_rpm_setup_tls();

Create a test CA and a server certificate signed by it, valid for
C<localhost> and C<127.0.0.1>, in F</root/trento-tls>. The CA is added to the
system trust store, so clients can verify the certificate without C<-k>.

=cut

sub trento_rpm_setup_tls {
    my $dir = TLS_DIR;

    assert_script_run("mkdir -p $dir");
    assert_script_run(join(' ', 'openssl req -x509 -newkey rsa:2048 -nodes -days 2',
            qq{-subj "/CN=Trento test CA" -keyout $dir/ca.key -out $dir/ca.crt}));
    assert_script_run(join(' ', 'openssl req -newkey rsa:2048 -nodes',
            qq{-subj "/CN=localhost" -keyout $dir/server.key -out $dir/server.csr}));
    assert_script_run(qq{echo "subjectAltName=DNS:localhost,IP:127.0.0.1" > $dir/san.cnf});
    assert_script_run(join(' ', "openssl x509 -req -days 2 -in $dir/server.csr",
            "-CA $dir/ca.crt -CAkey $dir/ca.key -CAcreateserial",
            "-extfile $dir/san.cnf -out $dir/server.crt"));
    assert_script_run("cp $dir/ca.crt /etc/pki/trust/anchors/trento-test-ca.crt");
    assert_script_run('update-ca-certificates');
    assert_script_run("openssl verify -CAfile $dir/ca.crt $dir/server.crt");
}

=head2 trento_rpm_prepare_ansible

    my $env = trento_rpm_prepare_ansible();

Return the shell prefix needed to run C<ansible-playbook> with an Ansible
version that C<ansible-trento> supports.
SLE 15 SP5 ships an older Ansible, so a Python 3.11 virtual environment with
Ansible 9 is created. The returned prefix activates it and points Ansible to
the collections and roles installed by the RPM.
The prefix is empty for the other versions.

=cut

sub trento_rpm_prepare_ansible {
    return '' unless is_sle('=15-SP5');

    my $venv = '/root/ansible-venv';
    zypper_call('in python311');
    assert_script_run("python3.11 -m venv $venv");
    assert_script_run(qq{$venv/bin/pip install "ansible==9.*"}, timeout => 600);
    return join(' ', "source $venv/bin/activate &&",
        'ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections',
        'ANSIBLE_ROLES_PATH=/usr/share/ansible/roles');
}

=head2 trento_rpm_run_playbook

    trento_rpm_run_playbook(admin_password => $password, ansible_env => $env);

Deploy Trento Server and Agent on the SUT with the C<suse.trento.site>
playbook of ansible-trento, using the certificates from
C<trento_rpm_setup_tls>.
The inventory is created from F<data/trento/rpm/inventory.yml>.
C<admin_password> is mandatory and must not contain single quotes.
C<ansible_env> is the prefix returned by C<trento_rpm_prepare_ansible>.
The playbook output is uploaded as a log file.

=cut

sub trento_rpm_run_playbook {
    my (%args) = @_;
    croak 'Missing mandatory admin_password argument' unless $args{admin_password};
    $args{ansible_env} //= '';

    assert_script_run('curl -f -o ' . INVENTORY . ' ' . data_url('trento/rpm/inventory.yml'));
    file_content_replace(INVENTORY,
        '\$\{ADMIN_PASSWORD\}' => $args{admin_password},
        '\$\{SERVICES_PASSWORD\}' => random_string(undef, 16),
        '\$\{TLS_DIR\}' => TLS_DIR,
        '\$\{PYTHON_INTERPRETER\}' => is_sle('=15-SP5') ? '/usr/bin/python3' : 'auto');

    my $cmd = join(' ', $args{ansible_env}, 'ansible-playbook -i', INVENTORY,
        'suse.trento.site >', PLAYBOOK_LOG, '2>&1');
    my $ret = script_run($cmd, timeout => 1800);
    upload_logs(PLAYBOOK_LOG, failok => 1);
    # Show the installed versions and their source repository, to check the incident packages are used
    record_info('Trento packages', script_output('rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE} (%{VENDOR})\n" "trento-*" ansible-trento | sort', proceed_on_failure => 1));
    record_info('Trento repos', script_output('zypper -n search -s -x trento-web trento-wanda trento-agent', proceed_on_failure => 1));
    die 'The suse.trento.site playbook failed' if $ret;
}

1;
