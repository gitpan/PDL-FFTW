# PDL interface to FFTW 2.x

use ExtUtils::MakeMaker;
use Config;
use PDL::Core::Dev;

require './fftw.conf';

$msg = "";

# Setup the FFTW library we will link to: (single/double precision)
#  Default is double precision
$want_float = 0;
$want_double = 1;
if (defined $FFTW_CONFIG{FFTW_TYPE} && $FFTW_CONFIG{FFTW_TYPE} =~ /single/i ) {
   $want_float = 1;
   $want_double = 0;
}

$found_float = $found_double = 'none';

# Look for FFTW includes/libs
# default locations:
@FFTW_inc_locations = ('/usr/include', '/usr/local/include', $Config{usrinc}); 
@FFTW_lib_locations = ('/lib','/usr/lib','/usr/local/lib',split(/ /, $Config{libpth}));

# get locations from perldl.conf, if specified there:
@FFTW_inc_locations = @{$FFTW_CONFIG{FFTW_INC}} if( defined $FFTW_CONFIG{FFTW_INC} );
@FFTW_lib_locations = @{$FFTW_CONFIG{FFTW_LIBS}} if( defined $FFTW_CONFIG{FFTW_LIBS} );

foreach $i (@FFTW_inc_locations) {
   if (-e "$i/dfftw.h") {
      print  "Found FFTW2 double version in $i/dfftw.h !\n";
      $double_rinclude = 'drfftw.h';
      $double_lib = '-ldfftw -ldrfftw';

      # Inc found, now try to find libs:
      if( findLibs($double_lib, @FFTW_lib_locations)){
         print " FFTW Libs also found.\n";
         $found_double = 'dfftw.h';

      }
   }
   if (-e "$i/sfftw.h") {
      print  "Found FFTW2 single version $i/sfftw.h !\n";
      $single_rinclude = 'srfftw.h';
      $single_lib = '-lsfftw -lsrfftw';

      # Inc found, now try to find libs:
      if( findLibs($single_lib, @FFTW_lib_locations)){
         print " FFTW Libs also found.\n";
         $found_float = 'sfftw.h';
      }
   }
   if (-e "$i/fftw.h") {
      open F,"$i/fftw.h";
      $is_float=0;
      while (<F>) {
         if (/define FFTW_ENABLE_FLOAT 1/) {$is_float=1;}
      }
      close F;
      if ($is_float) {
         print "Found FFTW2 single version in $i/fftw.h !\n";
         $single_rinclude = 'rfftw.h';
         $single_lib = '-lfftw -lrfftw';
         # Inc found, now try to find libs:
         if( findLibs($single_lib, @FFTW_lib_locations)){
            print " FFTW Libs also found.\n";
            $found_float = 'fftw.h';
         }
      }
      else {
         print  "Found FFTW2 double version in $i/fftw.h !\n";
         $double_rinclude = 'rfftw.h';
         $double_lib = '-lfftw -lrfftw';
         if( findLibs($double_lib, @FFTW_lib_locations)){
            print " FFTW Libs also found.\n";
            $found_double = 'fftw.h';
         }
      }
   }
}

$donot = 1;
$wanted_not_found = 0;

# want float, found float
if ($found_float ne 'none' && $want_float ) {
   $include = $found_float;
   print "Building single version\n";
   $pdltype = 'PDL_F';
   $lib = $single_lib;
   $rinclude = $single_rinclude;
   $out = '$fftwtype=\'float\'';
   $donot = 0;
}

# want double, found double
elsif ($found_double ne 'none' && $want_double ) {
   $include = $found_double;
   print "Building double version\n";
   $pdltype = 'PDL_D';
   $lib = $double_lib;
   $rinclude = $double_rinclude;
   $out = '$fftwtype=\'double\'';
   $donot = 0;
}


if ( $donot )   {
   $msg .= "\n Skipping build of PDL::FFTW.\n";
   $elaborate = 0;

   # maybe we found something, but it wasn't what was wanted...
   if ( $found_double ne 'none' )
   { $msg .= "Found double version, wanted float!\n"; $elaborate++ }

   if ( $found_float ne 'none' )
   { $msg .= "Found float version, wanted double!\n"; $elaborate++ }

   unless ( $elaborate )
   { $msg .= " In the Makefile.PL try adding the location of the FFTW2 header and\n" .
             " library to \@FFTW_inc_locations and \@FFTW_lib_locations (respectively).\n" }

}

if ($msg ne "") {
   warn $msg . "\n";
   $donot = 1;
} else {
   print "\n   Building PDL::FFTW. Turn off WITH_FFTW if there are any problems\n\n";
}

# Sub to find libs
sub findLibs {
   my ($libstring, @libdirs) = @_;
   # make a list of libs from the libstring
   my @libs = split ' ',$double_lib;
   grep s/\-l//g, @libs;
   grep $_ = "lib$_.a", @libs;
   my %libs;
   my $lib;
   foreach $libdir(@libdirs){
      foreach $lib(@libs){
         if( -e "$libdir/$lib"){
            $libs{$lib} = 1;
         }
      }

   }
   if( scalar(keys %libs) == scalar(@libs) ){
      return 1;	# all libs in the list were found
   }
   print "     Libs: '".join("', '",@libs)."' Not Found\n";
   print "     Looked in: '".join("', '",@libdirs)."'\n";
   return 0; # all libs in the list not found

}

if ($donot) {
   return if (caller); exit 0;
}

open F,'>typespec';
print F $out,";\n";
print F 'pp_addhdr(\'',"\n";
print F '#include "',$include,'"',"\n";
print F '#include "',$rinclude,'"',"\n";
print F '#define PDL_MYTYPE ',$pdltype,"\n";
print F '\');',"\n";
close F;

@pack = (["fftw.pd",FFTW,PDL::FFTW]);
%hash = pdlpp_stdargs(@::pack);
$hash{INC} .= " -I".join(' -I',@FFTW_inc_locations);
$hash{VERSION_FROM} = 'fftw.pd';
$hash{clean}->{FILES} .= ' typespec MANIFEST.bak';
push @{$hash{LIBS}},"-lm -L".join(" -L",@FFTW_lib_locations)." $lib";
$hash{PREREQ_PM} = { 'PDL' => 2.004, };
$hash{CONFIGURE_REQUIRES} = { 'PDL' => 2.004, };
$hash{META_MERGE} = {
   'provides' => {
      'PDL::FFTW' => {
         'file' => 'fftw.pd',
         'version' => '2.019',
      },
   },
   'resources' => {
      'homepage' => 'http://pdl.perl.org/',
      'bugtracker'  => {
         'web' => 'http://sourceforge.net/p/pdl/bugs/',
      },
      'repository'  => {
         'url' => 'git://git.code.sf.net/p/pdl/pdl-fftw',
         'web' => 'http://sourceforge.net/p/pdl/pdl-fftw/ci/master/tree/',
         'type' => 'git',
      },
   },
};

WriteMakefile(%hash);


sub MY::postamble {
   my $pdlpp_post = pdlpp_postamble(@::pack);
   my $text = <<"FOO";
install ::
\t\@echo "Updating PDL documentation database...";
\t\@\$(PERL) -e "use PDL::Doc; eval { PDL::Doc::add_module(q{PDL::FFTW}); }; ";

FOO
   return $pdlpp_post . $text;
}  # Add genpp rule                             
