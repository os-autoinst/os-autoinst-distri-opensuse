FROM registry.suse.com/bci/python:3.6

RUN [ "cat", "/etc/os-release" ]

ARG WKDIR=/home/venv

# this dir will be a shared volume at runtime
ARG SHARDIR=/home/tmp

# script to install
ARG VENV=./venv_inst.sh

# venv dir and pip modules to install:
# AWS
ARG DIRAWS=aws 
ARG OUTAWS="resources_$DIRAWS.txt" 
ARG PIPAWS="awscli"

# Azure
ARG DIRAZR=azure 
ARG OUTAZR="resources_$DIRAZR.txt" 
ARG PIPAZR="azure-cli appdirs azure-identity importlib-metadata virtualenv"

# EC2
ARG DIREC2=ec2 
ARG OUTEC2="resources_$DIREC2.txt" 
ARG PIPEC2="ec2imgutils"

# Openstack
ARG DIROPS=opstk 
ARG OUTOPS="resources_$DIROPS.txt" 
ARG PIPOPS="openstacksdk python-openstackclient typing-extensions importlib-metadata importlib-resources colorama"


RUN mkdir $WKDIR;

WORKDIR $WKDIR

RUN pip install virtualenv

RUN echo Pre-virtualenv; python3 --version; pip --version

# install the script
COPY $VENV .

# install venv-s:
RUN $VENV $DIRAWS $OUTAWS $PIPAWS
RUN $VENV $DIRAZR $OUTAZR $PIPAZR
RUN $VENV $DIREC2 $OUTEC2 $PIPEC2
RUN $VENV $DIROPS $OUTOPS $PIPOPS

# Default: copy all txt files in shared dir, if no run-shell
CMD sh -c "cp resources_*.txt $SHARDIR"
