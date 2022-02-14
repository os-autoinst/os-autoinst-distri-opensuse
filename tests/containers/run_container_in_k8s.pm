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
    $self->SUPER::init();

    my $cmd = '"cat", "/etc/os-release"';

    my $image_tag = $self->{provider}->get_default_tag();
    $self->{image_tag} = $image_tag;

    my $image = $self->{provider}->get_container_image_full_name($image_tag);
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
        command: [ $cmd ]
      restartPolicy: Never
  backoffLimit: 4
EOT

    record_info('Manifest', "Applying manifest:\n$manifest");
    $self->apply_manifest($manifest);
    $self->wait_for_job_complete($job_name);
    my $pod = $self->find_pods("job-name=$job_name");
    record_info('Pod', "Container (POD) successfully created.\n$pod");
    $self->validate_log($pod, "SUSE Linux Enterprise Server");
    record_info('cmd', "Command `$cmd` successfully executed in the image.");
}

sub cleanup {
    my ($self) = @_;
    record_info('Cleanup', 'Deleting kubectl job and image.');
    assert_script_run("kubectl delete job " . $self->{job_name});
    $self->{provider}->delete_container_image($self->{image_tag});
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
