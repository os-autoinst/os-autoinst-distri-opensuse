FROM registry.suse.com/bci/python:3.6

ENV WKDIR=/home/venv

# this dir will be a shared volume at runtime
ENV SHARDIR=/home/tmp

# script to install
ARG VENV=./venv_inst.sh

# venv dir and pip modules to install:
# AWS
ARG ENVAWS=aws 
ARG PIPAWS="awscli"

# Azure
ARG ENVAZR=azure 
ARG PIPAZR="azure-cli appdirs azure-identity importlib-metadata virtualenv"

# EC2
ARG ENVEC2=ec2 
ARG PIPEC2="ec2imgutils"

# Openstack
ARG ENVOPS=opstk 
ARG PIPOPS="openstacksdk python-openstackclient typing-extensions importlib-metadata importlib-resources colorama"

# create the internal container's environment
RUN cat /etc/os-release; mkdir $WKDIR; pip install virtualenv; echo Pre-virtualenv; python3 --version; pip --version

WORKDIR $WKDIR

# install the script
COPY $VENV .

# install venv-s:
RUN $VENV $ENVAWS $PIPAWS
RUN $VENV $ENVAZR $PIPAZR
RUN $VENV $ENVEC2 $PIPEC2
RUN $VENV $ENVOPS $PIPOPS

# Default: copy all expected txt files in shared dir, if no run-shell
CMD sh -c "echo 'Container files:' ; ls -l resources_*.txt; cp resources_*.txt $SHARDIR; echo 'Shared files:'; ls -l $SHARDIR/resources_*.txt"
