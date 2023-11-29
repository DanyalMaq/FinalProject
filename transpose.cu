// TODOS:
// 1. Consider the case where n is not divisible by num_gpus
// 2. Compare time for async and non-async
// 3. Incorporate streams within each GPU computation
// 4. Change the initial kernel to handle n x m matrix
// 5. Make it take a matrix of n x m 
#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include "matmul.cuh"
#include "utils.cuh"
#include <string>
using namespace std;

const unsigned int TILE_SIZE = 32;
const unsigned int BLOCK_ROWS = 8;

__global__ void transpose(const float *input, float *output, int rows, int columns) {
    __shared__ float tile[TILE_SIZE][TILE_SIZE + 1];  // +1 to avoid bank conflicts

    int x = blockIdx.x * TILE_SIZE + threadIdx.x;
    int y = blockIdx.y * TILE_SIZE + threadIdx.y;

    if (x < columns && y < rows) {
        tile[threadIdx.y][threadIdx.x] = input[y * columns + x];
    }

    __syncthreads();

    x = blockIdx.y * TILE_SIZE + threadIdx.x;
    y = blockIdx.x * TILE_SIZE + threadIdx.y;

    if (x < rows && y < columns) {
        output[y * rows + x] = tile[threadIdx.x][threadIdx.y];
    }
}

__host__ void transpose_host(float *input, const float *output, int rows, int columns)
{
    dim3 blockSize(TILE_SIZE, TILE_SIZE);
    dim3 gridSize((columns + TILE_SIZE - 1) / TILE_SIZE, (rows + TILE_SIZE - 1) / TILE_SIZE);

    transposeKernel<<<gridSize, blockSize>>>(input, output, rows, columns);
    cudaDeviceSynchronize();
}

__host__ int main(int argc, char** argv)
{
    printf("Distributed matmul with managed memory\n");
    if (argc != 3){
        printf("Usage: ./t <matrix size> <num_gpus>\n");
        return 0;    
    }

    int n = std::stoi(argv[1]);
    // int threads_per_block = stoi(argv[2]);
    int threads_per_block = 1024;
    int num_gpus = stoi(argv[2]);
    
    // check n is divisible by num_gpus
    if (! (n % num_gpus == 0) ){
        printf("For now, only supports n divisible by num_gpus");
        return 0;    
    }
    /////////////////// hardcode params for testing ///////////////////
    printf("Hardcoding params for testing\n");
    printf("n=%d, num_gpus=%d\n", n, num_gpus);
    num_gpus = 2;
    int nRowsA = n, nColsA = n, nColsB = n; // test square matrices for now
    int matrix_size = num_gpus * nRowsA * nColsA; // Total size of matrix
    int chunk_size = matrix_size / num_gpus; // Chunk going on each GPU

    // grid and block sizes
    dim3 threadsPerBlock(threads_per_block);
    int blocks_per_dim = (chunk_size + threadsPerBlock.x - 1) / threadsPerBlock.x;
    dim3 blocksPerGrid(blocks_per_dim);
    /////////////////// hardcode params for testing ///////////////////
    
    // Set up operands and result on device 0 
    float* defaultArrA;
    float* defaultArrB;
    float* defaultArrC;
    float* hostArrayD;
    // Use managed for async memcpy
    CHECK_CUDA_ERROR(cudaMallocManaged((void**)&defaultArrA, matrix_size  * sizeof(float))); 
    CHECK_CUDA_ERROR(cudaMallocManaged((void**)&defaultArrB, matrix_size  * sizeof(float))); 
    CHECK_CUDA_ERROR(cudaMallocManaged((void**)&defaultArrC, matrix_size  * sizeof(float))); 
    CHECK_CUDA_ERROR(cudaMallocManaged((void**)&hostArrayD, matrix_size  * sizeof(float))); 

    // randomly init and rescale the array on GPU. Make a separate dim for memory allocation
    dim3 threadsPerBlockAlloc(threads_per_block);
    int blocks_per_dim_alloc = (matrix_size + threadsPerBlockAlloc.x - 1) / threadsPerBlockAlloc.x;
    dim3 blocksPerGridAlloc(blocks_per_dim_alloc);
    GPU_fill_rand_int<<<blocksPerGridAlloc, threadsPerBlockAlloc>>>(defaultArrA, matrix_size, 1.0f, 2.0f);
    GPU_fill_rand_int<<<blocksPerGridAlloc, threadsPerBlockAlloc>>>(defaultArrB, matrix_size, 0.0f, 0.0f);
    kernel_err_check();
    cudaDeviceSynchronize();
    printMatrix(defaultArrA, num_gpus * nRowsA, nColsA);
    transpose_host(defaultArrB, defaultArrA, num_gpus * nRowsA, nColsA);
    printMatrix(defaultArrB, nColsA, num_gpus * nRowsA);
}