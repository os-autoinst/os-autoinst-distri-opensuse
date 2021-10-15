# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Push a container image to the public cloud container registry
#
# Maintainer: Ivan Lausuch <ilausuch@suse.com>, qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::k8sbasetest';
use testapi;

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;
    $self->install_kubectl();

    my $provider = $self->provider_factory(service => 'EKS');
    $self->{provider} = $provider;

    my $image_tag = $provider->get_default_tag();
    $self->{image_tag} = $image_tag;

    my $image = $provider->get_container_image_full_name($image_tag);
    my $job_name = $image_tag =~ s/_/-/gr;
    $self->{job_name} = $job_name;

    my $manifest = <<EOT;
apiVersion: batch/v1
kind: Job
metadata:
  name: $job_name
spec:
  template:
    spec:
      containers:
      - name: main
        image: $image
        command: [ "cat", "/etc/os-release" ]
      restartPolicy: Never
  backoffLimit: 4
EOT

    $self->apply_manifest($manifest);
    $self->wait_for_job_complete($job_name);
    my $pod = $self->find_pods("job-name=$job_name");
    $self->validate_log($pod, "SLES");
}

sub cleanup {
    my ($self) = @_;
    assert_script_run("kubectl delete job " . $self->{job_name});
    assert_script_run("aws ecr batch-delete-image --repository-name "
          . $self->{provider}->container_registry
          . " --image-ids imageTag="
          . $self->{image_tag});
}

sub post_fail_hook {
    my ($self) = @_;
    $self->cleanup();
}

sub post_run_hook {
    my ($self) = @_;
    $self->cleanup();
}

1;
