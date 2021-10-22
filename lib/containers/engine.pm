# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Abstraction layer to operate docker and podman containers through same interfaces
# Maintainer: qac team <qa-c@suse.de>

package containers::engine;
use Mojo::Base -base;
use testapi;
use Carp 'croak';
use Test::Assert 'assert_equals';
use containers::utils qw(registry_url);
use utils qw(systemctl file_content_replace script_retry);
use overload
  '""' => sub { return shift->runtime },
  bool => sub { return 1 },
  fallback => sub { return 1 };


has runtime => undef;

sub _engine_assert_script_run {
    my ($self, $cmd, @args) = @_;
    assert_script_run($self->runtime . " " . $cmd, @args);
}

sub _engine_script_run {
    my ($self, $cmd, %args) = @_;
    my $timeout = $args{timeout};
    $cmd = $self->runtime . " " . $cmd;
    my $ret = script_run($cmd, %args);
    # Don't swallow timeouts
    if (!defined($ret) && (defined($timeout) && $timeout > 0)) {
        croak("Timeout on _engine_script_run(" . join(', ', $cmd, map { $_ . '=>' . $args{$_} } keys %args) . ')');
    }
    return $ret;
}

sub _engine_script_output {
    my ($self, $cmd, @args) = @_;
    return script_output($self->runtime . " " . $cmd, @args);
}

sub _engine_script_retry {
    my ($self, $cmd, %args) = @_;
    $cmd = $self->runtime . " " . $cmd;
    # script_retry by default dies on timeouts, so the timeout check is not required here
    return script_retry($cmd, %args);
}

=head2 create_container($image, $name, [$cmd])

Creates a container.
C<image> the name of the image we create the container from.
C<name> is the given name of the created container.
C<cmd> can be anything you want to run in the container, similar to C<run>. for
instance: C<docker create -it tumbleweed bash>

=cut
sub create_container {
    my ($self) = shift;
    my %args = (
        image => '',
        name => '',
        cmd => '',
        @_
    );
    die('Must provide an image') unless ($args{image});
    die('Must provide an name') unless ($args{name});
    $self->_engine_assert_script_run("container create --name $args{name} $args{image} $args{cmd}", 300);
}

=head2 start_container($image_name)

Starts container named C<image_name>.

=cut
sub start_container {
    my ($self, $image_name) = @_;
    $self->_engine_assert_script_run("container start $image_name");
    record_info "$image_name container started", "";
}

=head2 halt_container($container_name)

Blocks a container until exits.
C<container_name> which runs.
https://docs.docker.com/engine/reference/commandline/wait/

=cut
sub halt_container {
    my ($self, $container_name) = @_;
    $self->_engine_assert_script_run("wait $container_name");
    record_info "$container_name container is blocked.", "";
}


=head2 build($dockerfile_path, $container_tag, [%args])

Build a container from a Dockerfil.
C<dockerfile_path> is the directory with the Dockerfile as well as the root of the build context.
C<container_tag> will be the name of the container.
Give C<timeout> if you want to change the timeout passed to C<assert_script_run>. Default for containers is 300.

=cut
sub build {
    my ($self, $dockerfile_path, $container_tag, %args) = @_;
    die 'wrong number of arguments' if @_ < 3;

    #TODO add build with URL https://docs.docker.com/engine/reference/commandline/build/
    $self->_engine_assert_script_run("build -f $dockerfile_path/Dockerfile -t $container_tag $dockerfile_path", $args{timeout} // 300);
    record_info "$container_tag created", "";
}

=head2 run_container($image_name, [mode, name, remote, keep_container, timeout])

Run a container.
C<image_name> is required and can be the image id, the name or name with tag.
If C<daemon> is enabled then container will run in the detached mode. Otherwise will be in the
interactive mode.
Set C<name> is you want to name the container.
if C<cmd> found then it will execute the given command into the container.
The container is always removed after exit.
if C<keep_container> is 1 the container is not removed after creation. Default to get removed
when it exits or when the daemon exits

=cut
sub run_container {
    my ($self, $image_name, %args) = @_;
    die 'image name or id is required' unless $image_name;
    my $mode = $args{daemon} ? '-d' : '-i';
    my $remote = $args{cmd} ? "$args{cmd}" : '';
    my $name = $args{name} ? "--name $args{name}" : '';
    my $keep_container = $args{keep_container} ? '' : '--rm';
    my $params = sprintf qq(%s %s %s), $keep_container, $mode, $name;
    my $cmd = sprintf qq(run %s %s %s), $params, $image_name, $remote;
    record_info "cmd_info", "Container executes:\noptions $params $image_name $remote";
    $self->_engine_assert_script_run($cmd, timeout => $args{timeout});
}

=head2 pull($image_name, [%args])

Pull a container with the given C<image_name>
where C<image_name> can be the name or id of the image.
C<args> passes parameters to C<script_run>

=cut
sub pull {
    my ($self, $image_name, %args) = @_;
    if (my $rc = $self->_engine_script_run("image inspect --format='{{.RepoTags}}' $image_name | grep '$image_name'") == 0) {
        return;
    }
    my $die = $args{die} // 1;
    # At least on publiccloud, this image pull can take long and occasinally fails due to network issues
    return $self->_engine_script_retry("pull $image_name", timeout => $args{timeout} // 300, retry => 3, delay => 30, die => $die);
}

=head2 commit

Save a existing container as a new image in the local registry

=cut
sub commit {
    my ($self, $mycontainer, $new_image_name, %args) = @_;
    $self->_engine_assert_script_run("commit $mycontainer $new_image_name", timeout => $args{timeout});
}

=head2 enum_images

Return an array ref of the images

=cut
sub enum_images {
    my ($self) = shift;
    my $images_s = $self->_engine_script_output("images -q");
    record_info "Images", $images_s;
    my @images = split /[\n\t]/, $images_s;
    return \@images;
}

=head2 enum_images

Return an array ref of the containers

=cut
sub enum_containers {
    my ($self) = shift;
    my $containers_s = $self->_engine_script_output("container ls -q");
    record_info "Containers", $containers_s;
    my @containers = split /[\n\t]/, $containers_s;
    return \@containers;
}

=head2 get_images_by_repo_name

Returns an array ref with the names of the images.

=cut
sub get_images_by_repo_name {
    my ($self) = @_;
    my $repo_images = $self->_engine_script_output("images --format '{{.Repository}}'", timeout => 120);
    my @images = split /[\n\t ]/, $repo_images;
    return \@images;
}

=head2 info

Assert a C<property> against given expected C<value> if C<value> is given.
Otherwise it prints the output of info.

=cut
sub info {
    my ($self, %args) = @_;
    my $property = $args{property} ? qq(--format '{{.$args{property}}}') : '';
    my $expected = $args{value} ? qq( | grep $args{value}) : '';
    $self->_engine_assert_script_run(sprintf("info %s %s", $property, $expected));
}

=head2 get_container_logs($container, $filename)

Request container's logs.
C<container> the running container.
C<filename> file the logs are written to.

=cut
sub get_container_logs {
    my ($self, $container, $filename) = @_;
    $self->_engine_assert_script_run("container logs $container | tee $filename");
}

=head2 read_tty

Assert a C<property> against given expected C<value> if C<value> is given.
Otherwise it prints the output of info.

=cut
sub read_tty {
    my ($self) = shift;
    my %args = (image => '', params => '', pipe => '', cmd => '', @_);
    my $pipe_cmd = $args{pipe} ? '|' . $args{pipe} : $args{pipe};
    return $self->_engine_script_output(sprintf("run --entrypoint /bin/bash %s %s -c '%s' %s", $args{params}, $args{image}, $args{cmd}, $pipe_cmd));
}

=head2 remove_image($image_name)

Remove a image from the pool.

=cut
sub remove_image {
    my ($self, $image_name) = @_;
    $self->_engine_assert_script_run("rmi -f $image_name");
}

=head2 remove_container

Remove a container from the pool.

=cut
sub remove_container {
    my ($self, $container_name) = @_;
    $self->_engine_assert_script_run("rm -f $container_name");
}

=head2 check_image_in_host

Returns true if host contains C<img> or false.

=cut
sub check_image_in_host {
    my ($self, $img) = @_;
    grep { $img eq $_ } @{$self->enum_images()};
}

=head2 configure_insecure_registries

Updates the registry files for the running container runtime to allow access to
insecure registries.

Implementation is subject to the subclass.

=cut
sub configure_insecure_registries {
    return;
}

=head2 cleanup_system_host

Remove containers and then all the images respectively.
Asserts that everything was cleaned up unless c<assert> is set to 0.

=cut
sub cleanup_system_host {
    my ($self, $assert) = @_;
    $assert //= 1;
    $self->_engine_assert_script_run("ps -q | xargs -r " . $self->runtime . " stop", 180);
    $self->_engine_assert_script_run("system prune -a -f", 300);

    if ($assert) {
        assert_equals(0, scalar @{$self->enum_containers()}, "containers have not been removed");
        assert_equals(0, scalar @{$self->enum_images()}, "images have not been removed");
    }
}

# Container engine subclasses here
package containers::engine::docker;
use Mojo::Base 'containers::engine';
use testapi;
use containers::utils qw(registry_url);
use utils qw(systemctl file_content_replace);
has runtime => 'docker';

sub configure_insecure_registries {
    my ($self) = shift;
    my $registry = registry_url();
    # Allow our internal 'insecure' registry
    assert_script_run(
        'echo "{ \"debug\": true, \"insecure-registries\" : [\"localhost:5000\", \"registry.suse.de\", \"' . $registry . '\"] }" > /etc/docker/daemon.json');
    assert_script_run('cat /etc/docker/daemon.json');
    systemctl('restart docker');
    record_info "setup $self->runtime", "deamon.json ready";
}

package containers::engine::podman;
use Mojo::Base 'containers::engine';
use testapi;
use containers::utils qw(registry_url);
use utils qw(systemctl file_content_replace);
has runtime => "podman";

sub configure_insecure_registries {
    my ($self) = shift;
    my $registry = registry_url();

    assert_script_run "curl " . data_url('containers/registries.conf') . " -o /etc/containers/registries.conf";
    assert_script_run "chmod 644 /etc/containers/registries.conf";
    file_content_replace("/etc/containers/registries.conf", REGISTRY => $registry);
}

1;
