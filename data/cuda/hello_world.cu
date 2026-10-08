// From: https://docs.nvidia.com/cuda/cuda-c-programming-guide/#basics
#include <stdio.h>

__global__ void childKernel()
{
	printf("Hello ");
}

__global__ void tailKernel()
{
	printf("World!\n");
}

__global__ void parentKernel()
{
	// launch child
	childKernel<<<1, 1>>>();
	if (cudaSuccess != cudaGetLastError()) {
		return;
	}

	// launch tail into cudaStreamTailLaunch stream
	// implicitly synchronizes: waits for child to complete
	tailKernel<<<1, 1, 0, cudaStreamTailLaunch>>>();
}

int main(int argc, char *argv[])
{
	// launch parent
	parentKernel<<<1, 1>>>();
	if (cudaSuccess != cudaGetLastError()) {
		return 1;
	}

	// wait for parent to complete
	if (cudaSuccess != cudaDeviceSynchronize()) {
		return 2;
	}

	return 0;
}
