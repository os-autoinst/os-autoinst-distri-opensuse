# Elemental3 Tests

This test suite validates the functionality of `elemental3`, a tool for managing Elemental-based Linux distributions. The tests cover various `elemental3` operations, including command execution within containers, interaction with Kubernetes clusters, and management of system extensions (sysext).

## Shared Library (`lib/elemental3.pm`)

The tests rely on a set of shared helper functions defined in `lib/elemental3.pm`. These functions provide a common interface for interacting with the system under test and its components.

*   `elemental3_cmd`: Executes an `elemental3` command from within a specified container image. It handles mounting necessary volumes like configuration directories and CA certificates.
*   `get_container_uri`: Fetches a specific container image URI from a web-based registry by parsing the page content.
*   `get_sysext`: Downloads and prepares systemd system extensions (`sysext`) from a list of images, making them available for `elemental3`.
*   `get_values`: A generic function to scrape information (like file names and version numbers) from a web page based on a regex.
*   `kubectl_cmd`: A wrapper to execute a `kubectl` command, retrying until it succeeds or a timeout is reached.
*   `wait_k8s_state`: Waits for the Kubernetes cluster to reach a desired state by polling pod statuses against a given regex.
*   `wait_kubectl_cmd`: Waits for the `kubectl` command-line tool to become available on the system.
*   `wait_nodes_ready`: Waits until all nodes in the Kubernetes cluster report a `Ready` status.
*   `wait_on_cmd`: A generic polling function that repeatedly runs a command until it succeeds.
*   `wait_script_output`: Waits for a command to produce non-empty output and returns that output.

## Test Scenarios

The test modules in this directory likely cover scenarios such as:

*   Installing or upgrading an Elemental system using `elemental3`.
*   Deploying and managing system extensions.
*   Verifying the state of a Kubernetes cluster managed by or related to Elemental.
*   Testing specific `elemental3` sub-commands.

## Prerequisites

*   A system with a configured container runtime (e.g., Docker, Podman) as specified by the `CONTAINER_RUNTIMES` openQA variable.
*   Access to the container registries and web repositories containing the Elemental images and metadata.

## Configuration

The tests are configured through various openQA variables, including:

*   `CONTAINER_RUNTIMES`: Specifies the container runtime to use.
*   `SYSEXT_IMAGES_TO_TEST`: A comma-separated list of system extension images to download and test.
*   `TOTEST_PATH`: Used to determine if internal SUSE CAs need to be mounted in the container.

## Running the tests

These tests are designed to be executed by the openQA framework. Select the relevant test modules from the `elemental3` group in an appropriate test suite.

## License

The files in this directory are licensed under the "FSF All Permissive License" except if indicated otherwise in the file.
