D Front End for GCC - Release 0.30

Last update: Saturday, 23 June, 2012

Authors:
---------------------
The GNU D Compiler (GDC) project was originally started by David Friedman in
2004 until early 2007 when he disappeared from the D scene, and was no longer
able to maintain GDC.  Following a revival attempt in 2008, GDC is now under
the lead of Iain Buclaw who has been steering the project since 2009 with the
assistance of its contributors, without them the project would not have been
nearly as successful as it has been.


Contributors:
---------------------
David Friedman for starting the GDC project.
Vincenzo Ampolo for his reviving development efforts.
Michael Parrott for adding initial support for the D2 frontend.
Iain Buclaw for completing the port of GDC to GCC 4.2.x and later.
Anders F Bjorklund for assistance in porting to OSX.
Daniel Green for porting GDC to MinGW platform.
Johannes Pfau for assistance in porting to Android and ARM.
alexrp for standardising the platform identifiers in D.


History:
---------------------
Release Notes

0.30:

  * Support for GCC, 4.5.x and 4.6.x added
  * Removed support for GCC 3.4.x, 4.0.x, 4.1.x
  * Updated D1 to 1.069
  * Updated D2 to 2.054
  * Better D2 support for MinGW
  * Added 'optlink' calling convention for D
  * Added 64bit support for IASM (Work in Progress)
  * Moved correct implementation of delegates from GCC backend to GDC frontend glue code
  * Fixed Bugzilla 670, 4494, 4543, 5086, 5090, 5148, 5182, 5191, 5439, 5735, 5812
  * Many other Bitbucket issues.

0.25:

  * Support for GCC, 4.2.x, 4.3.x, and 4.4.x added
  * Updated D1 to 1.063
  * Updated D2 to 2.020
  * Added druntime support
  * Fixed Bugzilla 1041, 1044, 1136, 1145, 1296, 1669, 1689,
    1751, 1813, 1822, 1921, 1930, 2079, 2102, 2291, 2421
  * Fixed Bitbucket issues too numerous to mention. :-)

0.24:

  * Removed support for GCC 3.3.x
  * Updated to DMD 1.020
  * Fixed Bugzilla 1037, 1038 (gdc specific), 1043, 1045, 1046,
    1031, 1032, 1034, 1065, 1109, 1191, 1137, 1152, 1208, 1325,
    1329, 1898, 1400
  * Fixed SourceForge issues 1689634, 1749622, 1721496, 1721435

0.23:

  * Added support for 64-bit targets
  * Added multilib support
  * Updated to DMD 1.007
  * Fixed Bugzilla 984, 1013

0.22:

  * Added support for GCC 4.1.x
  * Support for GCC 3.3.x is deprecated
  * Updated to DMD 1.004
  * Fixed Bugzilla 836, 837, 838, 839, 841, 843, 844, 889, 896
  * Fixed problems with missing debug information
  * Added Rick Mann's -framework patch for gdmd

0.21:

  * Updated to DMD 1.00
  * Fixed Bugzilla 695, 696, 737, 738, 739, 742, 743, 745
  * Implemented GCC extended assembler
  * Implemented basic support for GCC attributes

0.20:

  * Updated to DMD 0.177
  * Fixes for synchronized code generation
  * Better support for cross-hosted builds
  * Fixed Bugzilla 307, 375, 403, 575, 578
  * Applied Anders Bjorklund's MacOS X build patches

0.19:

  * Fixed D Bugzilla bugs 141(gdc), 157, 162, 164, 171, 174, 175, 192, 229
  * Applied Dave Fladebo's suggestion for -O3 in gdmd
  * Updated to DMD 0.162
  * The version symbol for FreeBSD is now "freebsd"
  * Enabled std.loader for FreeBSD
  * Implement offsetof in assembler
  * Support building with Apple's GCC (4.0 only)
  * Fix parallel builds

0.18:

  *  Fixes
    o ICE on assignment arithmetic
    o Problems mixing D and assembler floating point operations
    o Mac OS X 10.2 build problems
    o The gdc driver no longer compiles C source as C++
    o Many others...
  * Improvements
    o Updated to DMD 0.157
    o Support for PowerPC Linux
    o Partial support for SkyOS
    o Compiler can be relocated to another directory.

0.17:

  *  Fixes
    o Mixed complex/float operations on GCC 4.0 (D.gnu/1485)
    o Applied Thomas Kuhne's HTML line number fix
    o Foreach/nested functions in templates (D.gnu/1514)
    o Use correct default initializer when allocating arrays of typedef'd types
    o Recursive calls to nested functions (D.gnu/1525)
  * Improvements
    o Updated to DMD 0.140

0.16:

  * Fixes
    o Concatenating a array and single element
    o "__arrayArg already defined"
    o ICE on nested foreach statements (D.gnu/1393)
    o Inline assembler
      * Functions returning floating point types
      * Spurious error on scaled register without a base register
      * Access to locals by var+ofs[EBP] now works with optimization.
      * Can now guess operand size from referenced variables.
    o Thunks errors with reimplemented interfaces (e.g., Mango)
  * Improvements
    o Support GCC 4.0.x
    o Updated to DMD 0.132
    o Support DW_LANG_D for DWARF debugging
    o Support compiling multiple sources to a single object with GCC 3.4.x

0.15:

  * Updated to DMD 0.128

0.14:

  * Fixes
    o Classes nested in functions actually work now.
    o Fix for newest versions of the GNU assembler.
  * Improvements
    o Updated to DMD 0.127

0.13:

  * Fixes
    o Cygwin/MinGW assembler problem
  * Improvements
    o Updated to DMD 0.126.
    o Calling nested functions with delegates is faster.
    o The "check-target-libphobos" builds a separate library to
      enable runtime checks and unit tests.

0.12.1:

  *  Fixes
    o Compilation errors and crashes with -fpic
    o Crashes with interfaces on Cygwin/MinGW
    o Support the -mno-cygwin option

0.12:

  * Fixes
    o Various problems building MinGW in MSYS
    o Mango "endless output"
    o Build problems with gcc 3.4.1
    o Various problems revealed by dmdscript
    o Error message now go to standard error
    o DStress catch_01, catch_02, new_04, switch_19, throw_02, and others.
  * Improvements
    o Updated to DMD 0.125
    o New target: AIX
    o GDC and DMD versions are reported with "gcc --version"
    o Take advantage of DMD template improvements on
  * Changes
    o std.c.unix is now std.c.unix.unix
    o The runtime library is now "libgphobos" to avoid conflicts with DMD.
    o The dmd wrapper script...
      + Is now named "gdmd".
      + Looks for gdc in its own directory instead of searching the path
      + Requires a comma after the "-q" option.

0.11:

  * Fixes
    o Reversed structure compare
    o Correct meaning of '-L' option in wrapper script
    o Static data GC bug on Linux
  * Improvements
    o Updated to DMD 0.121
    o New target: MingGW
    o Included Anders F Bjorklund's man pages.
    o It is now possible to build a cross-compiler.  Only MingGW
      is supported out-of-the-box, however.

0.11pre1:

  * Fixes
    o Incorrect/missing thunks
    o Problems when the C char type is unsigned
    o Side effects in void type return expressions
    o Calling a particular static ancestor method.
    o Install of /etc/c/zlib.d
    o Support for built-in function security patch.
    o More...
  * Improvements
    o Updated to DMD 0.113
    o Phobos is now built as target library (i.e., no need for a
      separate build step)
    o Boehm-gc is no longer used and the Java package is no
      longer required.
    o Inline assembler for x86 (there are some limitations --
      these need to be documented)
    o Included Anders Bjorklund's patches to enable the use of
      frameworks on Darwin.
    o On Darwin, D object code can be linked with the system
      gcc.  Likewise, gdc can link C++ object code built by the
      system g++.
    o Improved support for alternate C main functions (see
      d/phobos/internal/{cmain.d,rundmain.d})
  * Notes
    o The gdc driver no longer accepts D source files without
      the ".d" extension.  The dmd wrapper script still supports
      this.

0.10:

  * Fixes
    o Complex number comparisons with NAN operands
    o Cleaned up Phobos installation.
    o Non-virtual method calls
    o Code generation with -mpowerpc64
    o Break in labeled switch statement
  * Improvements
    o Updated to DMD 0.110
    o Applied Thomas Kohne's and Anders Bjorklund's HTML patches.
    o Added Thomas Kohne's "dump source" code
    o Phobos Makefile now supports the DESTDIR variable

0.9:

  * Fixes
    o Detect use of non-static methods in a static context
    o Enumerated types are signed by default
    o Anders Bjorklund's patch for HTML infinite looping
    o va_start is now a template.
    o Delegate expressions for struct methods now work
    o bswap uses unsigned right shift
    o Fixed several problems with the dmd script
    o Fixed crash when compiling with debug information
    o Handle referenes to instance variables without "this"
    o Fixed ICE for interfaces with multiple inheritence
    o Fix id.h dependcy so concurrent make will work
  * Improvements
    o Updated to DMD 0.109
  *  Notes
    o The (undocumented) BitsPer{Pointer,Word} version
      identifiers are now prefixed with "GNU_"
    o Private declarations are now exported from object files

0.8:

  *  Fixes
    o std.loader module is now enabled
    o Proper casting from complex and imaginary types
    o Diagnostics are now GCC-style
    o Exceptions don't leak memory anymore
    o The gdc command processes ".html" as D source files.
    o ICE for classes declared in a function
    o ICE on empty "if" statement
    o Test for existence of "execvpe", "fwide", and "fputwc" before
      using them
    o Corrected floating point "min_10_exp" properties
    o std.date.getLocalTZA returns a correct values
    o Using gdc to link with C++ should now just need "-lstdc++"
  * Improvements
    o Debugging information is vastly improved
    o DLLs can be built on Cygwin
  * Notes
    o "DigitalMars" is not longer defined as a version symbol


Supported Systems:
---------------------
  * GCC 4.8.x
  * Linux (tested on Debian and Ubuntu x86, x86_64)
  * Mac OS X 10.3.9 and 10.4.x
  * FreeBSD 6.x, 7.x
  * Cygwin
  * MinGW
  * AIX (tested on 5.1)

Similar versions of the above systems should work and other Unix
platforms may work.  Although the compiler will probably work on most
architectures, the D runtime library will still need to be
updated to support them.


Requirements
---------------------
  * The base developer package for your system.  Generally, this
    means binutils and a C runtime library.
  * The gdmd wrapper script requires Perl.


Links
---------------------
  * This Project -- https://github.com/D-Programming-GDC/GDC/
  * Previous home -- http://dgcc.sourceforge.net/
  * The D Programming Language -- http://www.digitalmars.com/d/
  * D Links Page -- http://digitalmars.com/d/dlinks.html
  * The D.gnu newsgroup -- news://news.digitalmars.com/D.gnu
  * For general D discussion, the digitalmars.D and
    digitalmars.D.bugs newsgroups
  * The GNU Compiler Collection -- http://gcc.gnu.org/
  * Mac OS X binary distribution -- http://gdcmac.sourceforge.net/


Contact
---------------------
Iain Buclaw
e-mail: ibuclaw@gdcproject.org


Status
---------------------

Known Issues

  * See the DStress (http://svn.kuehne.cn/dstress/www/dstress.html)
    page for known failing cases.
  * Debugging information may have a few problems if you are using
    a version of gdb that is not 7.2 or later.  To enable D name
    mangling in gdb, apply this patch.
    (http://dsource.org/projects/gdb-patches/)
  * Some targets do not support once-only linking which is needed
    for templates to work smoothly. A workaround is to manually
    control template emission.  See the -femit-templates option
    below.  For Darwin, Apple's GCC 3.x compiler supports one-only
    linking, but GDC does not build with those sources.  There are
    no problems with the stock GCC 4.x on Darwin.
  * Complex floating point operations may not work the same as DMD.
  * Some math functions behave differently due to different
    implementations of the extended floating-point type.
  * Volatile statements may not always do the right thing.
  * Because of a problem on AIX, the linker will pull in more
    modules than needed.
    See: http://groups-beta.google.com/groups?hl=en&q=%22large+executables+on+AIX%22&qt_s=Search
  * Some C libraries (Cygwin, MinGW, AIX) don't handle
    floating-point formatting and parsing in a standard way.

Known Differences from DMD

  * The type of _argptr in variadic functions is the target-specific
    va_list type.  The only portable way to use _argptr is the
    std.stdarg.va_arg template.  In particular, you cannot construct
    a va_list from a pointer to data and expect it to work.
  * The D Inline assembler is not supported by GDC.
  * Similarly, naked functions are not supported by GDC either.
  * Currently, GDC uses the C calling convention for all functions
    except those declared extern (Windows).
  * GDC allows catch statements in finally blocks.
  * pragma(lib) is not supported.
  * Some targets do not have a distinct extended floating-point
    type.  On these targets, real and double are the same size.
  * On Win32 targets, GDC allocates 12 bytes for the real type, while
    DMD allocates 10 bytes. This also applies to the components of
    the creal type.


License
---------------------
  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3, or (at your option)
  any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with GCC; see the file COPYING3.  If not see
  <http://www.gnu.org/licenses/>.

