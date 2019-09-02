#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=1MB
#SBATCH --time=0-00:01:00     # 1 minute
#SBATCH --output=/tmp/sbatch1
#SBATCH --job-name=test1

# Put commands for executing job below this line
echo "hello from test1";
