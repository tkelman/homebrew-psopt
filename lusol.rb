require "formula"

class Lusol < Formula
  homepage 'http://www.stanford.edu/group/SOL/software/lusol.html'
  url 'http://sourceforge.net/projects/lpsolve/files/LUSOL/2.2.1.0/LUSOL2.2.1.0.zip/download'
  sha1 '9e12a0c774479a66146cf1de6936732d21c77087'

  def patches
    # fixes undefined symbols for max and _strupr
    DATA
  end

  def install
    # do case-insensitive comparison of file extensions
    inreplace 'lusolmain.c', 'strcmp(fileext', 'strcasecmp(fileext'

    system '$CC -O3 -c lusol.c mmio.c commonlib.c lusolio.c hbio.c myblas.c'
    system 'ar cr liblusol.a lusol.o mmio.o commonlib.o lusolio.o hbio.o myblas.o'
    system 'ranlib liblusol.a'
    system '$CC -O3 lusolmain.c -L. -llusol -o lusol'

    lib.install 'liblusol.a'
    bin.install 'lusol'
    include.install 'commonlib.h', 'myblas.h'
    include.install Dir['lusol*.h']
  end

  test do
    Afile = <<-EOS.undent
      1 1 5.0
      1 2 5.0
      1 4 1.0
      2 1 1.0
      2 2 1.0
      2 4 1.0
    EOS
    (testpath/'Afile.txt').write(Afile)
    bfile = <<-EOS.undent
      15.0
      7.0
    EOS
    (testpath/'bfile.txt').write(bfile)
    system 'lusol Afile.txt bfile.txt'
  end
end

__END__
diff --git a/lusolio.c b/lusolio.c
index eb680bb..ae96073 100644
--- a/lusolio.c
+++ b/lusolio.c
@@ -43,8 +43,8 @@ MYBOOL ctf_read_A(char *filename, int maxm, int maxn, int maxnz,
       jA[k]  = j;
       Aij[k] = Ak;
     }
-    *m      = max( *m, i );
-    *n      = max( *n, j );
+    if (i > *m) *m = i;
+    if (j > *n) *n = j;
   }
   fclose( iofile );
   if(!eof) {
diff --git a/lusolmain.c b/lusolmain.c
index 4c1f10d..2211109 100644
--- a/lusolmain.c
+++ b/lusolmain.c
@@ -27,7 +27,7 @@ MYBOOL isNum(char val)
   return( (MYBOOL) ((ord >= 0) && (ord <= 9)) );
 }
 
-void main( int argc, char *argv[], char *envp[] )
+int main( int argc, char *argv[], char *envp[] )
 {
 /* Output device */
   FILE *outunit = stdout;
@@ -71,7 +71,7 @@ int main( int argc, char *argv[], char *envp[] )
     printf("Formats: Conventional RCV .TXT, MatrixMarket .MTX, or Harwell-Boeing .RUA\n");
     printf("Author:  Michael A. Saunders (original Fortran version)\n");
     printf("         Kjell Eikland       (modified C version)\n");
-    return;
+    return 0;
   }
 
 /* Create the LUSOL object and set user options */
@@ -157,7 +157,6 @@ void main( int argc, char *argv[], char *envp[] )
 
 /* Obtain file extension and see if we must estimate matrix data size */
   strcpy(fileext, strchr(argv[useropt], '.'));
-  _strupr(fileext);
 
   /* Read conventional text file format */
   if(strcmp(fileext, ".TXT") == 0) {
@@ -257,7 +256,6 @@ void main( int argc, char *argv[], char *envp[] )
     if(i != 0)
       useropt++;
     strcpy(fileext, strchr(argv[useropt], '.'));
-    _strupr(fileext);
 
     /* Read conventional text file format */
     if(strcmp(fileext, ".TXT") == 0) {
@@ -463,6 +463,7 @@ x900:
 #endif
 
   LUSOL_free(LUSOL);
+  return success ? 0 : 1;
 
 /*     End of main program for Test of LUSOL */
 }
