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
use utils qw(zypper_call file_content_replace random_string script_retry);
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
  trento_rpm_prepare_e2e
  trento_rpm_setup_cypress
  trento_rpm_run_cypress
);

use constant TLS_DIR => '/root/trento-tls';
use constant INVENTORY => '/root/trento-inventory.yml';
use constant PLAYBOOK_LOG => '/var/log/trento-ansible-playbook.log';
use constant WEB_URL => 'https://localhost';
use constant WEB_DIR => '/root/trento-web';
use constant NODE_DIR => '/opt/node';
use constant PHOTOFINISH_BIN => '/usr/local/bin/photofinish';

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

=head2 trento_rpm_prepare_e2e

    trento_rpm_prepare_e2e(admin_password => $password);

Prepare the SUT for the end-to-end tests: stop the Trento agent, remove its
host from Trento Web, raise the PostgreSQL C<max_connections> to 200 and
restart PostgreSQL, Trento Web and Trento Wanda.
The agent is removed because the tests load their own hosts with photofinish.
C<admin_password> is mandatory and must not contain single quotes.
The host removal is retried until the agent heartbeat expires.

=cut

sub trento_rpm_prepare_e2e {
    my (%args) = @_;
    croak 'Missing mandatory admin_password argument' unless $args{admin_password};
    $args{admin_user} //= 'admin';
    my $url = WEB_URL;

    zypper_call('in jq');
    assert_script_run('systemctl stop trento-agent');

    my $token = script_output(
        qq{curl -sSf -X POST $url/api/session -H 'Content-Type: application/json' }
          . qq{-d '{"username":"$args{admin_user}","password":"$args{admin_password}"}' | jq -r .access_token});
    my $host_id = script_output(
        qq{curl -sSf $url/api/v1/hosts -H 'Authorization: Bearer $token' | jq -r '.[0].id // empty'});
    if ($host_id) {
        # The API answers 422 until the heartbeat of the stopped agent expires
        script_retry(q{test "$(curl -s -o /dev/null -w '%{http_code}' -X DELETE }
              . qq{$url/api/v1/hosts/$host_id -H 'Authorization: Bearer $token')" = 204},
            retry => 15, delay => 10, timeout => 60);
    }

    assert_script_run(q{sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER SYSTEM SET max_connections = 200"});
    assert_script_run('systemctl restart postgresql');
    assert_script_run('systemctl restart trento-web trento-wanda');
    script_retry("curl -fsS $url/api/readyz", retry => 15, delay => 10, timeout => 60);
}

=head2 trento_rpm_setup_cypress

    trento_rpm_setup_cypress();

Install what the Trento Web Cypress tests need: system libraries for the
Electron browser, Node.js, photofinish, and the test sources of
C<trento-project/web>.
The tests come from the Git tag equal to the version of the installed
C<trento-web> package, or from the C<TRENTO_WEB_REF> setting when it is set.
Node.js has the version of F<.tool-versions> in that tag, and photofinish the
version of C<TRENTO_PHOTOFINISH_VERSION> (default C<v1.4.2>).
The test CA is added to the NSS database that the browser uses.

=cut

sub trento_rpm_setup_cypress {
    my $web_ref = get_var('TRENTO_WEB_REF') // script_output(q{rpm -q --qf '%{VERSION}' trento-web | cut -d- -f1});
    my $photofinish_version = get_var('TRENTO_PHOTOFINISH_VERSION', 'v1.4.2');
    my $web_dir = WEB_DIR;
    my $node_dir = NODE_DIR;

    zypper_call('in git-core xz tar xauth xorg-x11-server-Xvfb mozilla-nss-tools libgtk-3-0 libnotify4 libXss1 libXtst6 libgbm1 libasound2');

    assert_script_run(join(' ', 'git clone --depth 1 --filter=blob:none --sparse',
            "--branch $web_ref https://github.com/trento-project/web.git $web_dir"), timeout => 300);
    assert_script_run("git -C $web_dir sparse-checkout set --no-cone /test/e2e/ /test/fixtures/ /.photofinish.toml /.tool-versions");
    record_info('Trento web tests', "Tests taken from the tag $web_ref");

    my $node_version = script_output(qq{awk '/^nodejs/ {print \$2}' $web_dir/.tool-versions});
    assert_script_run(join(' ', "mkdir -p $node_dir &&",
            "curl -fsSL https://nodejs.org/dist/v$node_version/node-v$node_version-linux-x64.tar.xz",
            "| tar -xJ --strip-components=1 -C $node_dir"), timeout => 300);

    assert_script_run(join(' ', "curl -fsSL https://github.com/trento-project/photofinish/releases/download/$photofinish_version/photofinish_linux_x86_64.tar.gz",
            '| tar -xz -C /usr/local/bin'), timeout => 120);
    assert_script_run('photofinish --help > /dev/null');

    assert_script_run('mkdir -p ~/.pki/nssdb');
    assert_script_run('certutil -d sql:$HOME/.pki/nssdb -N --empty-password');
    assert_script_run('certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n trento-test-ca -i ' . TLS_DIR . '/ca.crt');

    assert_script_run("export PATH=$node_dir/bin:\$PATH; cd $web_dir/test/e2e && npm ci", timeout => 900);
}

=head2 trento_rpm_run_cypress

    trento_rpm_run_cypress(admin_password => $password, spec => $spec);

Run the Cypress tests prepared by C<trento_rpm_setup_cypress> against the
Trento Web of the SUT.
C<admin_password> is mandatory and must not contain single quotes.
C<spec> is an optional Cypress spec pattern relative to F<test/e2e>. All the
tests run when it is empty.
C<expose> is an optional string with more comma-separated values for the
Cypress C<--expose> option.
The screenshots of failed tests are uploaded as an archive.

=cut

sub trento_rpm_run_cypress {
    my (%args) = @_;
    croak 'Missing mandatory admin_password argument' unless $args{admin_password};
    $args{spec} //= '';
    $args{expose} //= '';
    $args{admin_user} //= 'admin';
    my $dir = WEB_DIR . '/test/e2e';

    my $expose = join(',', 'wanda_mode=prod', 'web_mode=prod', 'photofinish_binary=' . PHOTOFINISH_BIN, $args{expose} || ());
    my $cmd = join(' ', 'export PATH=' . NODE_DIR . '/bin:$PATH;',
        "cd $dir &&",
        'NODE_EXTRA_CA_CERTS=' . TLS_DIR . '/ca.crt',
        'cypress_video=false',
        "CYPRESS_login_user=$args{admin_user}",
        "CYPRESS_login_password='$args{admin_password}'",
        'npx cypress run',
        '--config baseUrl=' . WEB_URL . ',retries=1',
        "--expose $expose",
        ($args{spec} ? "--spec '$args{spec}'" : ()),
        '> /var/log/trento-cypress.log 2>&1');
    my $ret = script_run($cmd, timeout => 3600);
    upload_logs('/var/log/trento-cypress.log', failok => 1);
    if (script_run("test -d $dir/cypress/screenshots") == 0) {
        assert_script_run("tar -czf /tmp/cypress-screenshots.tar.gz -C $dir/cypress screenshots");
        upload_logs('/tmp/cypress-screenshots.tar.gz', failok => 1);
    }
    die 'The Cypress tests failed' if $ret;
}

1;
