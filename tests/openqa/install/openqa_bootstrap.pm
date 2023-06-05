# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install openQA using openqa-bootstrap
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product);


sub run {
    select_console 'root-console';

    if (script_run('stat /dev/kvm') != 0) {
        record_info('No nested virt', 'No /dev/kvm found');
    }

    if (is_sle) {
        add_suseconnect_product('PackageHub');

        if (get_var('USE_DEVEL_OPENQA', 1)) {

            # Download latest install scripts
            assert_script_run('cd /tmp');
            assert_script_run('wget https://raw.githubusercontent.com/os-autoinst/openQA/master/script/openqa-bootstrap');
            assert_script_run('wget https://raw.githubusercontent.com/os-autoinst/openQA/master/script/fetchneedles');
            assert_script_run('chmod +x openqa-bootstrap fetchneedles');

            # Patch them (will be upstreamed)
            zypper_call('in patch');
            assert_script_run('wget ' . autoinst_url('/data/openqa-bootstrap.patch'));
            assert_script_run('patch < openqa-bootstrap.patch');

            # Install openQA and fetch needles
            assert_script_run('skip_suse_tests=1 skip_suse_specifics=1 ./openqa-bootstrap', timeout => 600);
            assert_script_run('./fetchneedles', timeout => 2400);
        }
        else {
            my $configure = <<'EOC';
            dbname="${dbname:="openqa"}"
            dbuser="${dbuser:="geekotest"}"
            zypper -n install --no-recommends openQA-single-instance qemu-x86 qemu-tools sudo iputils os-autoinst-distri-opensuse-deps
            [ "$(uname -m)" = "aarch64" ] && zypper -n install --no-recommends qemu-uefi-aarch64 ||:
            zypper -n search -x qemu-hw-display-virtio-gpu-pci && zypper -n install --no-recommends qemu-hw-display-virtio-gpu qemu-hw-display-virtio-gpu-pci ||:
            systemctl enable --now postgresql
            su postgres -c "/usr/share/openqa/script/setup-db" $dbuser $dbname
            setup=/usr/share/openqa/script/configure-web-proxy
            (command -v $setup && sh -ex $setup) || (curl -s https://raw.githubusercontent.com/os-autoinst/openQA/master/script/configure-web-proxy | bash -ex)
            sed -i -e 's/#*.*method.*=.*$/method = Fake/' /etc/openqa/openqa.ini
            sed -i -e 's/git:\/\//https:\/\//' /usr/share/openqa/script/fetchneedles
            /usr/share/openqa/script/fetchneedles
            [ ! -e /var/lib/openqa/tests/sle ] && ln -s opensuse /var/lib/openqa/tests/sle ||:
            grep -q "$(hostname)" /etc/hosts || echo "127.0.0.1 $(hostname)" >> /etc/hosts
            systemctl enable --now apache2
            systemctl enable --now openqa-webui
            systemctl enable --now openqa-scheduler
            while ! curl -sI http://localhost/ | grep 200 ; do sleep 3 ; done
            curl http://localhost/login
            API_KEY=$(hexdump -n 8 -e '2/4 "%08X" 1 "\n"' /dev/random)
            API_SECRET=$(hexdump -n 8 -e '2/4 "%08X" 1 "\n"' /dev/random)
            echo "INSERT INTO api_keys (key, secret, user_id, t_created, t_updated) VALUES ('${API_KEY}', '${API_SECRET}', 2, NOW(), NOW());" | su postgres -c "psql $dbname"
EOC
            assert_script_run($_, timeout => 600) foreach (split /\n/, $configure);
            assert_script_run('cat >> /etc/openqa/client.conf <<EOF
[localhost]
key = ${API_KEY}
secret = ${API_SECRET}
EOF
true');
            assert_script_run('systemctl enable --now openqa-worker@1');
        }
    }
    else {
        zypper_call('in openQA-bootstrap');
        assert_script_run('/usr/share/openqa/script/openqa-bootstrap', 4000);
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
