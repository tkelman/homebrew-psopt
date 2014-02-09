require 'formula'

class Psopt302Patch < Formula
  homepage 'https://code.google.com/p/psopt/'
  url 'http://psopt.googlecode.com/files/patch_3.02.zip'
  sha1 'fd04038126dcfe4e1e9d95a26c7795423ac73276'

  def patches
    # include assert, resolve ambiguous reference to rank, and fix dimension
    # errors in copy_decision_variables and lagrange_interpolation in psopt.cxx
    { :p3 => DATA }
  end
end

class Psopt < Formula
  homepage 'https://code.google.com/p/psopt/'
  url 'http://psopt.googlecode.com/files/Psopt3.tgz'
  sha1 '3cdcb7eb82bb3862376488026bd47413ec31161c'

  depends_on 'gnuplot' => :optional
  depends_on 'openblas' => :optional
  depends_on 'ipopt' => (build.with? 'openblas') ? ['with-openblas'] : :build
  depends_on 'suite-sparse' => (build.with? 'openblas') ? ['with-openblas'] : :build
  depends_on 'adol-c' => :build
  depends_on 'lusol' => :build

  def install
    # Download and apply Psopt 3.02 patch
    Psopt302Patch.new.brew do
      (buildpath/'PSOPT/src').install 'psopt.cxx'
    end

    # Don't need to build CXSparse or LUSOL here
    inreplace 'Makefile',
              'all: $(CXSPARSE_LIBS) $(DMATRIX_LIBS) $(LUSOL_LIBS)',
              'all: $(DMATRIX_LIBS)'

    # Correct paths to dependencies
    ipopt_prefix = Formula.factory('ipopt').prefix
    adolc_prefix = Formula.factory('adol-c').prefix
    suite_sparse_prefix = Formula.factory('suite-sparse').prefix
    lusol_prefix = Formula.factory('lusol').prefix

    inreplace ['PSOPT/lib/Makefile', 'PSOPT/examples/Makefile_linux.inc'] do |s|
      s.change_make_var! 'prefix', ipopt_prefix
    end

    inreplace ['dmatrix/examples/Makefile', 'PSOPT/examples/Makefile_linux.inc'] do |s|
      s.change_make_var! 'CXSPARSE', suite_sparse_prefix
      s.change_make_var! 'LUSOL', lusol_prefix
      s.change_make_var! 'SPARSE_LIBS', '$(LUSOL)/lib/liblusol.a $(CXSPARSE)/lib/libcxsparse.a'
      if build.with? 'openblas'
        s.change_make_var! 'FLIBS', "-L#{Formula.factory('openblas').lib} -lopenblas"
      else
        s.change_make_var! 'FLIBS', '-llapack -lblas'
      end
      # Remove unnecessary linker flags
      s.gsub! '-lgcc_s', ''
      s.remove_make_var! 'LDFLAGS'
    end

    inreplace 'PSOPT/examples/Makefile_linux.inc' do |s|
      s.change_make_var! 'IPOPT_LIBS', "`cat #{ipopt_prefix}/share/coin/doc/Ipopt/ipopt_addlibs_cpp.txt`"
      s.change_make_var! 'ADOLC_LIBS', "-L#{adolc_prefix}/lib -ladolc"
    end

    inreplace ['dmatrix/lib/Makefile',
               'dmatrix/examples/Makefile',
               'PSOPT/lib/Makefile',
               'PSOPT/examples/Makefile_linux.inc'] do |s|
      s.remove_make_var! 'CXX'
    end

    inreplace 'dmatrix/src/dmatrixv.cxx' do |s|
      # Remove extern "C" around standard includes in dmatrixv.cxx
      s.sub! 'extern "C" {', ''
      s.sub! '}', ''
    end

    system 'make', 'all'

    lib.install 'dmatrix/lib/libdmatrix.a'
    lib.install 'PSOPT/lib/libpsopt.a'
    include.install 'dmatrix/include/dmatrixv.h'
    include.install Dir['PSOPT/src/*.h']
    bin.install 'PSOPT/examples/obstacle/obstacle'
    bin.install 'PSOPT/examples/bioreactor/bioreactor'
    bin.install 'PSOPT/examples/brymr/brymr'
  end
end

__END__
diff --git a/PSOPT/src/psopt.cxx b/PSOPT/src/psopt.cxx
index 18dc314..c9fd80d 100644
--- a/PSOPT/src/psopt.cxx
+++ b/PSOPT/src/psopt.cxx
@@ -92,6 +92,7 @@ _CRTIMP  int * __cdecl errno(void) { static int i=0; return &i; };
 #include <math.h>
 #include <string.h>
 #include <time.h>
+#include <assert.h>
 
 
 
@@ -2653,6 +2653,7 @@ void copy_decision_variables(Sol& solution, DMatrix& x, Prob& problem, Alg& algo
 		(solution.nodes[i])(1,k)          =  convert_to_original_time( (aux_local_pr->snodes[i])(k), t0, tf );
 	}
 
+        if (nparam > 0)
         solution.parameters[i] = elemDivision( x(colon(iphase_offset+offset2+1, iphase_offset+offset2+nparam)), param_scaling);
 
         iphase_offset += nvars_phase_i;
@@ -4457,7 +4458,7 @@ void lagrange_interpolation(DMatrix& y, DMatrix& x, DMatrix& pointx, DMatrix& po
    for (i=1;i<=n;i++) {
       for (j=1;j<=n;j++) {
            if (i != j) {
-                L(i,colon()) = ( L(i,colon())&(  x-pointx(j)*ones(1,length(x)) )  )/(pointx(i)-pointx(j));
+                L(i,colon()) = elemProduct( L(i,colon()),(  x-pointx(j)*ones(1,length(x)) )  )/(pointx(i)-pointx(j));
            }
       }
    }
@@ -9883,7 +9884,7 @@ void print_solution_summary(Prob& problem, Alg& algorithm, Sol& solution)
         }
       }
 
-      fprintf(outfile,"\n\n>>>>> Rank of parameter covariance matrix: %i ", rank(Cp));
+      fprintf(outfile,"\n\n>>>>> Rank of parameter covariance matrix: %i ", ::rank(Cp));
 
       fprintf(outfile,"\n\n>>> 95 percent statistical confidence limits on estimated parameters ");
       fprintf(outfile,"\nPhase\tParameter\t(Low Confidence Limit) \t(Value) \t\t(High Confidence Limit)");
