# Parallel matrix multiplication for memory efficiency and performance in ML
CS 759 Final Project--Fall 2023 Group Members: Danyal Maqbool & Wenxuan Tan

Benchmarks parallel matrix multiplication on NVLink clusters.
Implements a 3-layer Tensor Parallel MLP in pure CUDA.
# To run the code:
If you are using one machine with multiple GPUs, use docker.
Otherwise just run make but ensure you have the cuda dependencies.
```
docker compose build; docker compose up -d; docker attach 759;
make
```
