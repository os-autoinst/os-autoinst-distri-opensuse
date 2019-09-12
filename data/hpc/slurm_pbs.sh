#!/bin/bash
#PBS -N Job_PBS
#PBS -l nodes=1,walltime=00:01:00
#PBS -o /tmp/Job_PBS_o
#PBS -e /tmp/Job_PBS_e

# Put commands for executing job below this line
echo "hello from PBS test";

#print the time and date
date

#wait 10 seconds
sleep 10

#print the time and date again
date
