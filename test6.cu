#include <iostream> // std::cout
#include <fstream>
#include <vector>

#include <cusp/csr_matrix.h>
#include <cusp/precond/diagonal.h>
#include <cusp/krylov/bicgstab.h>
#include <cusp/krylov/gmres.h>
#include <cusp/print.h>
#include <typeinfo>

// where to perform the computation
typedef cusp::device_memory MemorySpace;

// which floating point type to use
typedef double ValueType;

using namespace std;

extern "C"
{
   void fortran_solve_csr_(int n, int m, int nnz, int *rowoffset, int *col, double *val, double *rhs, double *x)
   {
      // create an empty sparse matrix structure (CSR format)
      cusp::csr_matrix<int, ValueType, MemorySpace> A(n, m, nnz);
      
      vector<int>ro(rowoffset, rowoffset + n + 1);

      vector<int>co(col, col + nnz);

      vector<double>va(val, val + nnz);

      vector<double>rh(rhs, rhs + n);

      A.row_offsets=ro;
      A.column_indices=co;
      A.values=va;

      // allocate storage for solution (x) and right hand side (b)
      cusp::array1d<ValueType, MemorySpace> X(A.num_rows, 0);
      cusp::array1d<ValueType, cusp::host_memory> X_h(A.num_rows, 0);
      cusp::array1d<ValueType, MemorySpace> B(rh);
      
      // set stopping criteria:
      //  iteration_limit    = 20000
      //  relative_tolerance = 1e-15
      //  absolute_tolerance = 1e-10
      cusp::monitor<ValueType> monitor(B, 600, 1e-15, 1e-10, false);

      // setup preconditioner
      cusp::precond::diagonal<ValueType, MemorySpace> M(A);
      //cusp::identity_operator<ValueType, MemorySpace> M(A.num_rows, A.num_rows);

      // solve the linear system A * x = b with the BiConjugate Gradient Stabilized method
      cusp::krylov::bicgstab(A, X, B, monitor, M);

      //cusp::identity_operator<ValueType, MemorySpace> M(A.num_rows, A.num_rows);

      // report solver results
      ofstream mlpgTerOut;
      mlpgTerOut.open("mlpgTerOut.txt", ofstream::app);
      if (!bool(monitor.converged()))
      {
         mlpgTerOut << " Solver reached iteration limit " << monitor.iteration_limit() << " before converging";
         mlpgTerOut << " to " << monitor.relative_tolerance() << " relative tolerance\n";
         mlpgTerOut << " [ERR] BiCGStab Failed. Shifting to GMRES\n";

         X=X_h;
         monitor.reset (B);
         cusp::krylov::gmres(A, X, B, 50, monitor, M);

      }

      mlpgTerOut << " [PARACSR]\t1\t" << monitor.iteration_count() << "\t" << endl;
      
      mlpgTerOut.close();
      
      X_h=X;
      #pragma omp parallel for
      for (int i = 0; i < n; i++)
      {
         x[i] = X_h[i];
      }

      ro.clear(),co.clear(),va.clear(),rh.clear();
   }
}