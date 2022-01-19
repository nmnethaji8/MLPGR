#include <iostream> // std::cout

#include <thrust/sort.h>
#include <thrust/execution_policy.h>

using namespace std;

extern "C"
{
   __device__ void SORTBYKEY_(int *A, double *B, int N)
   {
      /*printf("A values are\n");
      for(int i=0;i<N;i++)
      {
         printf("%d\t",A[i]);
      }
      printf("\nB values are\n");
      for(int i=0;i<N;i++)
      {
         printf("%f\t",B[i]);
      }
      printf("\nN=\t%d\n",N);*/
      thrust::stable_sort_by_key(thrust::seq,   B, B + N , A);


      /*printf("\nAfter sorting\nA values are\n");
      for(int i=0;i<N;i++)
      {
         printf("%d\t",A[i]);
      }
      printf("\nB values are\n");
      for(int i=0;i<N;i++)
      {
         printf("%f\t",B[i]);
      }
      printf("\n");*/
   }
}