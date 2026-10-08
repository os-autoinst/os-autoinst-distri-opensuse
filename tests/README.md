# Testing Kubic

This page will outline how to ensure that a Kubic-deployed Kubernetes cluster
has stood up correctly and is ready to accept workloads.

## Before you begin

This page assumes you have a working openQA deployed instance.

## Single-Node testing

Single-node tests for Kubic provide a mechanism to test the behavior of the
underlying operating-system, and is the last signal to ensure end-user
operations match Kubernetes specifications. Although unit and integrations
tests provide a good signal, it is not uncommon that a minor change
may pass all unit and integration tests, but cause unforeseen changes at
the final state of the product release.

The primary objectives of single-node tests in openQA are to ensure a
consistent and reliable behavior of Kubic code base, and catch hard-to-test
bugs before users do, when unit and integration tests are insufficient.

Single-Node tests will pass on properly running on KVM virtual-machines.

#### Testsuites

* kubeadm@64bit-4G-HD40G
* microos@64bit-4G-HD40G
* microos@uefi-4G-HD40G
* microos_10G-disk
* rcshell

## Cluster testing

*In progress...*
