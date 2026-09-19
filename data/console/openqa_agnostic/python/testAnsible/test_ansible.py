# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
"""Functional tests for ansible.

Ported from tests/console/ansible.pm. Exercises ansible basics, galaxy,
playbook testing and execution and vault. The wrapper provides the collection
under ~/ansible_collections/openqa/ansible and installs the packages.
"""

import os
import re
import shutil
import subprocess

import pytest

COLLECTION = os.path.expanduser('~/ansible_collections/openqa/ansible')
ARCH = os.uname().machine


def sh(cmd, timeout=900, cwd=COLLECTION):
    return subprocess.run(['bash', '-c', cmd], cwd=cwd, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, universal_newlines=True, timeout=timeout)


def out(cmd, **kwargs):
    result = sh(cmd, **kwargs)
    assert result.returncode == 0, f'{cmd} failed: {result.stdout.strip()[:800]}'
    return result.stdout


def ansible_user():
    text = open(os.path.join(COLLECTION, 'hosts')).read()
    match = re.search(r'ansible_user=(\S+)', text)
    assert match, 'ansible_user is not set in hosts'
    return match.group(1)


@pytest.fixture(scope='session', autouse=True)
def environment():
    user = ansible_user()
    if sh(f'id -u {user}').returncode != 0:
        out(f'useradd -m {user}')
    out(f"echo '{user} ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/ansible")
    out('systemctl start sshd')
    out('test -f ~/.ssh/ansible_rsa || ssh-keygen -b 2048 -t rsa -N "" -f ~/.ssh/ansible_rsa')
    out(f'install -o {user} -g users -m 0700 -dD /home/{user}/.ssh')
    out(f'install -o {user} -g users -m 0644 ~/.ssh/ansible_rsa.pub /home/{user}/.ssh/authorized_keys')
    out('ssh-keyscan localhost >> ~/.ssh/known_hosts')

    # Tumbleweed needs the fully qualified community.general.zypper module
    release = open('/etc/os-release').read()
    community = 'community.general.' if re.search(r'ID="?opensuse-tumbleweed', release) else ''
    task = os.path.join(COLLECTION, 'roles/test/tasks/main.yaml')
    text = open(task).read().replace('COMMUNITYGENERAL', community)
    open(task, 'w').write(text)

    yield

    sh('rm -rf ~/ansible_collections /tmp/ansible /etc/sudoers.d/ansible ~/.ssh/ansible_rsa*', cwd='/')
    sh('userdel -rf johnd', cwd='/')


@pytest.fixture(scope='session')
def facts(environment):
    return out('ansible -m setup localhost')


def test_collection_is_present():
    assert os.path.isdir(COLLECTION), f'{COLLECTION} is missing'


def test_ansible_version():
    assert 'ansible' in out('ansible --version').lower()


def test_setup_hostname(facts):
    hostname = out('hostnamectl --static').strip()
    assert re.search(r'"ansible_hostname"\s*:\s*"' + re.escape(hostname) + r'"', facts)


def test_setup_architecture(facts):
    assert re.search(r'"ansible_architecture"\s*:\s*"' + re.escape(ARCH) + r'"', facts)


def test_galaxy_role():
    out('ansible-galaxy install ansible-network.config_manager', timeout=700)
    listing = out('ansible-galaxy list')
    assert 'ansible-network.config_manager' in listing
    assert 'ansible-network.network-engine' in listing


def test_general_collection_has_zypper():
    assert 'zypper' in out('ansible-doc -l community.general | grep zypper')


def test_ansible_community():
    if shutil.which('ansible-community'):
        out('ansible-community --version')


def test_playbook_check():
    if sh('ansible-playbook -i hosts main.yaml --check', timeout=300).returncode != 0:
        # bsc#1210875: ansible-test requires Python 2.7
        out('printf "[defaults]\\ninterpreter_python = /usr/bin/python3\\n" > ansible.cfg')
        out('ansible-playbook -i hosts main.yaml --check', timeout=300)


def test_ansible_test_sanity():
    if shutil.which('ansible-test'):
        out('ansible-test sanity')


def test_inventory():
    assert 'localhost' in out('ansible -i hosts all --list-hosts')


def test_playbook_run():
    playbook = out('ansible-playbook -i hosts main.yaml', timeout=600)
    uname = out('uname -r').strip()
    result = sh('cat /tmp/ansible/uname.txt')
    assert result.returncode == 0 and re.search(re.escape(uname), result.stdout), (
        f'cat rc={result.returncode} out={result.stdout!r}\n'
        f'/tmp/ansible: {out("ls -la /tmp/ansible 2>&1 || true")}\n'
        f'playbook tail:\n{playbook[-3000:]}')
    assert 'stay the same' in out('cat /tmp/ansible/static.txt')
    assert out('readlink /tmp/ansible/os-release').strip() == '/etc/os-release'
    assert re.search(r'my ' + re.escape(ARCH) + r' dynamic kingdom', out('sudo -u johnd cat /home/johnd/README.txt'))
    assert shutil.which('ed')


def test_vault_roundtrip():
    password = 'vaultpassword123'
    content = 'secretcontent1234567890'
    open(os.path.join(COLLECTION, 'ranom_password.txt'), 'w').write(password + '\n')
    open(os.path.join(COLLECTION, 'ranom_content.txt'), 'w').write(content + '\n')
    out('echo "---" > ./encrypted_content.yaml')
    out('cat ./ranom_content.txt | ansible-vault encrypt_string --vault-password-file ./ranom_password.txt --stdin-name random_content | tee -a ./encrypted_content.yaml')
    decrypted = out('ansible localhost --vault-password-file ./ranom_password.txt -e "@./encrypted_content.yaml" -m debug -a var=random_content')
    assert content in decrypted
