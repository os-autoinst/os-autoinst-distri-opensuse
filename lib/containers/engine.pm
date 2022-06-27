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


=head2 build($dockerfile_path, $image_tag, [%args])

Build a container from a Dockerfil.
C<dockerfile_path> is the directory with the Dockerfile as well as the root of the build context.
C<container_tag> will be the name of the container.
Give C<timeout> if you want to change the timeout passed to C<assert_script_run>. Default for containers is 300.

=cut

sub build {
    my ($self, $dockerfile_path, $image_tag, %args) = @_;
    die 'wrong number of arguments' if @_ < 3;
    # Retry the build several times without giving the image name
    $self->_engine_script_retry("build -f $dockerfile_path/Dockerfile $dockerfile_path", timeout => $args{timeout} // 300, retry => 3, delay => 60);
    # This is a dummy build, as it's been done previously. This command is just to create a new tag $image_tag
    $self->_engine_assert_script_run("build -f $dockerfile_path/Dockerfile -t $image_tag $dockerfile_path", $args{timeout} // 300);
    record_info('Build OK', "Image $image_tag created");
}

=head2 run_container($image_name, [mode, name, remote, keep_container, timeout, retry, delay])

Run a container. The method dies, if the run command fails.
C<image_name> is required and can be the image id, the name or name with tag.
If C<daemon> is enabled then container will run in the detached mode. Otherwise will be in the
interactive mode.
Set C<name> is you want to name the container.
if C<cmd> found then it will execute the given command into the container.
The container is always removed after exit.
if C<keep_container> is 1 the container is not removed after creation. Default to get removed
when it exits or when the daemon exits
if C<retry> is given, the command is being repeated the given amount of times on failure
If C<delay> is given, this defines the number of seconds between retries

=cut

sub run_container {
    my ($self, $image_name, %args) = @_;
    die 'image name or id is required' unless $image_name;
    # Assemble command: $RUNTIME run [-d|-i] [--rm] [--name $NAME] $IMAGE [$CMD]
    my $params = '';    # container runtime parameters
    $params = $args{daemon} ? '-d' : '-i';
    $params .= ' --rm' unless ($args{keep_container});
    $params .= " --name '$args{name}'" if ($args{name});
    my $cmd = "run $params $image_name";
    $cmd .= " $args{cmd}" if ($args{cmd});
    record_info "cmd_info", "Container executes:\n$cmd";

    # Own retry routine so that we can delete the container between retries if $args{keep_container} is set.
    my $retries = $args{retry} // 1;
    while ($retries-- > 0) {
        my $ret = $self->_engine_script_run($cmd, timeout => $args{timeout});
        return 0 if ($ret == 0);
        # Here we only remove the container, if we keep it (otherwise the --rm argument should delete it automatically)
        # Also: don't assert the removal takes place, to not fail in the possible case that no container has been yet created (e.g. network issues)
        $self->remove_container($args{name}, assert => 0) if ($args{keep_container});
        sleep($args{delay}) if ($args{delay});
    }
    die "engine_script_run failed";
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
    my ($self, %args) = shift;
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

=head2 remove_image($image_name)

Remove a image from the pool.

=cut

sub remove_image {
    my ($self, $image_name) = @_;
    $self->_engine_assert_script_run("rmi -f $image_name");
}

=head2 remove_container($container_name, [assert])

Remove a container from the pool.
C<container_name> is the container name to be removed. Required argument.
C<assert> Is an optional boolean for asserting that the call is successful. If false the method returns the return value of the call.

=cut

sub remove_container {
    my ($self, $container_name, %args) = @_;
    my $assert = $args{assert} // 1;
    if ($assert) {
        $self->_engine_assert_script_run("rm -f $container_name");
    } else {
        return $self->_engine_script_run("rm -f $container_name");
    }
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

1;
