use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use containers::common;
use version_utils qw(is_sle is_leap get_os_release);
use containers::utils;

sub wait_for {
    my ($container) = @_;
    my $count = 30;
    while (system("docker logs $container 2>&1 | grep Listening >/dev/null") != 0) {
        sleep 1;
        $count = $count - 1;
        last if ($count == 0);
    }

    system("docker logs $container 2>&1 | grep Listening >/dev/null");
}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my ($running_version, $sp, $host_distri) = get_os_release;
    my $runtime = "docker";
    my $image   = "registry.opensuse.org/devel/openqa/containers15.2/openqa_webui";

    install_docker_when_needed($host_distri);
    test_seccomp();
    allow_selected_insecure_registries(runtime => $runtime);

    my $volumes = "-v \"/root/data/factory:/data/factory\" -v \"/root/data/tests:/data/tests\" -v \"/root/openQA/container/webui/conf:/data/conf:ro\"";

    assert_script_run("docker network create testing");
    assert_script_run("git clone https://github.com/os-autoinst/openQA.git");
    assert_script_run("mkdir -p /root/data/factory/{iso,hdd} /root/data/tests");

    assert_script_run("docker pull $image", timeout => 600);

    #RUN postgresql
    assert_script_run("docker run -d --network testing -e POSTGRES_PASSWORD=openqa -e POSTGRES_USER=openqa -e POSTGRES_DB=openqa --net-alias db --name db postgres", timeout => 600);

    my $count = 30;
    while (system("docker logs db 2>&1 | grep \"database system is ready to accept connections\" >/dev/null") != 0) {
        sleep 1;
        $count = $count - 1;
        last if ($count == 0);
    }

    assert_script_run("docker logs db 2>&1 | grep \"database system is ready to accept connections\" >/dev/null");
    assert_script_run("docker pull registry.opensuse.org/devel/openqa/containers15.2/openqa_webui", timeout => 300);
    record_info("DB inizializated");

    #RUN webui
    assert_script_run("docker run -d --network testing -e MODE=webui -e MOJO_LISTEN=http://0.0.0.0:9526 $volumes -p 9526:9526 --name webui $image");
    wait_for("webui");
    assert_script_run("docker exec webui curl localhost:9526 >/dev/null");
    record_info("webui working");

    #RUN websockets
    assert_script_run("docker run -d --network testing -e MODE=websockets -e MOJO_LISTEN=http://0.0.0.0:9527 $volumes -p 9527:9527 --name websockets $image");
    wait_for("websockets");
    assert_script_run("docker exec websockets curl localhost:9527 >/dev/null");
    record_info("websockets working");

    #RUN livehandler
    assert_script_run("docker run -d --network testing -e MODE=livehandler -e MOJO_LISTEN=http://0.0.0.0:9528 $volumes -p 9528:9528 --name livehandler $image");
    wait_for("livehandler");
    assert_script_run("docker exec livehandler curl localhost:9528 >/dev/null");
    record_info("livehandler working");

    #RUN scherduler
    assert_script_run("docker run -d --network testing -e MODE=scheduler -e MOJO_LISTEN=http://0.0.0.0:9529 $volumes -p 9529:9529 --name scheduler $image");
    wait_for("scheduler");
    assert_script_run("docker exec scheduler curl localhost:9529 >/dev/null");
    record_info("scheduler working");

    #RUN gru
    assert_script_run("docker run -d --network testing -e MODE=gru $volumes --name gru $image");

    my $gru_test = "docker logs gru 2>&1 | grep started >/dev/null";
    $count = 30;
    while (system($gru_test) != 0) {
        sleep 1;
        $count = $count - 1;
        last if ($count == 0);
    }

    assert_script_run($gru_test);
}

1;
