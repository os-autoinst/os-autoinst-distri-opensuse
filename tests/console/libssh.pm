# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libssh4 libssh2-1
# Summary: libssh version 1 and version 2 test
#  Libssh4 or libssh2-1 are used by the following software respectively
#  so they are tested with them.
#    libssh: curl, libvirt
#    libssh2: qemu-block-ssh, libvirt
#  Steps:
#  * Set up a docker container as one end of client/server test
#  * Run below commands to connect to sshd daemon.
#      curl -s sftp://
#      curl -s scp://
#      qemu-system-x86_64 -drive file=ssh://
#  * Run below commands to connect to libvirtd daemon.
#      virsh -c "qemu+libssh://"
#      virsh -c "qemu+libssh2://"
#  * It's difficult to clean up libvirt so set test flag to rollback always
#
#  The detailed test cases: https://bugzilla.suse.com/tr_show_case.cgi?case_id=1768668
#
# Maintainer: Tony Yuan <tyuan@suse.com>

package libssh;
use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use Utils::Systemd 'disable_and_stop_service';
use version_utils;
use registration 'add_suseconnect_product';
use containers::common 'install_docker_when_needed';
use registration qw(add_suseconnect_product get_addon_fullname);

# Build a custom container image with openssl, curl and virsh installed.
# The container will be used as client of libssh
# The variable: dev_image_tag can be used to specify a base image. If the base images is stored in internal
# repository i.e. registry.suse.de we assume the host OS is in develping stage. i.e currently sle15sp3:
# registry.suse.de/suse/sle-15-sp3/update/cr/totest/images/suse/sle15:15.3

sub create_image {
    my $tag = get_var("DEV_IMAGE_TAG");
    if ($tag =~ /registry\.suse\.de/) {
        ensure_ca_certificates_suse_installed;
        systemctl("restart docker.service");
    }
    my $dockerfile;
    my $pkgs = "openssh curl libvirt-client";

    if (is_sle) {
        unless ($tag) {
            $tag = "registry.suse.com/suse/";
            my ($v, $sp) = get_os_release;
            $tag .= is_sle('<15') ? "sles${v}sp$sp" : "sle${v}:${v}.$sp";
        }
        record_info($tag);

        #Create Dockerfile for sle and opensuse
        $dockerfile = <<'EOT';
ARG tag
FROM $tag
ARG pkgs
RUN zypper --gpg-auto-import-keys ref -s
RUN zypper install -y $pkgs
RUN echo "root:test" | chpasswd
RUN /usr/sbin/sshd-gen-keys-start
CMD ["/usr/sbin/sshd", "-D"]
EOT
    } else {
        $tag ||= (is_tumbleweed) ? "tumbleweed" : "leap";
        $dockerfile = <<'EOT';
ARG tag
FROM opensuse/$tag
ARG pkgs
RUN zypper install -y $pkgs
RUN echo "root:test" | chpasswd
RUN /usr/sbin/sshd-gen-keys-start
CMD ["/usr/sbin/sshd", "-D"]
EOT
    }
    #Build an custom image with openssh curl libvirt-client sshpass
    assert_script_run("mkdir /tmp/build && cd /tmp/build");
    assert_script_run("cat > /tmp/build/Dockerfile <<'END'\n$dockerfile\nEND\n( exit \$?)");
    assert_script_run(qq(docker build -t libssh_image --build-arg tag="$tag" --build-arg pkgs="$pkgs" .), timeout => 600);
}

sub run {
    select_console 'root-console';

    # contm is not supported on LTSS products bsc#1181835
    if (get_var('SCC_REGCODE_LTSS')) {
        add_suseconnect_product(get_addon_fullname('contm'));
    }

    # Host is used as server of libssh test
    my ($running_version, $sp, $host_distri) = get_os_release;
    install_docker_when_needed($host_distri);
    # zypper_call("--gpg-auto-import-keys in docker libvirt-daemon-qemu qemu-kvm qemu-block-ssh");
    zypper_call("in libvirt-daemon-qemu qemu-kvm qemu-block-ssh");
    #  systemctl("start docker.service libvirtd.service sshd.service");
    systemctl("start libvirtd.service sshd.service");
    create_image if (script_output('docker images') !~ m/libssh_image/);    #Skip building If image is already available. This is for Fips test
    assert_script_run("iptables -I INPUT -p tcp --dport 22 -j ACCEPT");
    assert_script_run("mkdir /tmp/test; echo -n libssh_testcase001 > /tmp/test/libssh_testfile");
    assert_script_run("qemu-img create -f raw /tmp/test/libssh_block.raw 20m");    #file to be uploaded to container for qemu block test
    assert_script_run('docker run -itd --name libssh_container --hostname container01 --add-host susetest:$(ip -4 addr show docker0 | grep -Po "inet \K[\d.]+") --privileged libssh_image');

    #Create key pair on host and container,  import sshd host key from container, copy pub key to each other
    my $container_ip = script_output("docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' libssh_container");
    assert_script_run("ssh-keygen -t rsa -N '' -m pem -f /root/.ssh/id_rsa <<< y");    #Current libssh2 only support pem file format
    assert_script_run("ssh-keyscan $container_ip >> /root/.ssh/known_hosts");

    assert_script_run("docker exec libssh_container ssh-keygen -t rsa -N '' -m pem -f /root/.ssh/id_rsa <<< y");
    assert_script_run("docker cp /root/.ssh/id_rsa.pub libssh_container:/root/.ssh/authorized_keys");
    assert_script_run("docker cp libssh_container:/root/.ssh/id_rsa.pub /root/.ssh/authorized_keys");

    #Switch into container as client
    enter_cmd("docker exec -it libssh_container bash", wait_still_screen => 3);
    assert_script_run("test -f /.dockerenv");    #verify inside container
    assert_script_run("ssh-keyscan susetest >> /root/.ssh/known_hosts");
    validate_script_output("curl -s sftp://susetest/tmp/test/ -u root:nots3cr3t", sub { m/libssh_testfile/ });
    validate_script_output("curl -s sftp://susetest/tmp/test/libssh_testfile -u root:nots3cr3t", sub { m/libssh_testcase001/ });
    assert_script_run("curl -s sftp://susetest/tmp/test/libssh_block.raw -u root:nots3cr3t -o /tmp/libssh_block.raw");
    validate_script_output("curl -s scp://susetest/tmp/test/libssh_testfile -u root:nots3cr3t", sub { m/libssh_testcase001/ });
    validate_script_output('curl -s sftp://root@susetest/tmp/test/libssh_testfile --key /root/.ssh/id_rsa', sub { m/libssh_testcase001/ });
    validate_script_output('curl -s scp://root@susetest/tmp/test/libssh_testfile --key /root/.ssh/id_rsa', sub { m/libssh_testcase001/ });
    validate_script_output('virsh -c "qemu+libssh://root@susetest/system?sshauth=privkey&keyfile=/root/.ssh/id_rsa&known_hosts=/root/.ssh/known_hosts" hostname', sub { m/susetest/ }) if is_sle('>=15-sp1'); #libssh is not supported by libvirt for sle12 and sle15sp1
    validate_script_output('virsh -c "qemu+libssh2://root@susetest/system?sshauth=privkey&keyfile=/root/.ssh/id_rsa&known_hosts=/root/.ssh/known_hosts" hostname', sub { m/susetest/ });
    #Switch back to host
    enter_cmd("exit", wait_still_screen => 3);
    #libssh2 test with qemu-block-ssh
    assert_script_run("eval `ssh-agent` && ssh-add /root/.ssh/id_rsa");
    assert_script_run("qemu-system-x86_64 -daemonize -display none -drive format=raw,if=virtio,index=1,file=ssh://root\@$container_ip/tmp/libssh_block.raw -monitor unix:/tmp/socket01,server,nowait");
    sleep 30;
    validate_script_output('nc -U /tmp/socket01 <<EOF
info block virtio1
quit
EOF
', sub { m/libssh_block\.raw/ });

    assert_script_run("docker stop libssh_container");
}

sub test_flags {
    return {always_rollback => 1};
}

1;

