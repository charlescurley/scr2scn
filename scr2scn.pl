#! /usr/bin/perl

# Translate between Forth screens files (*.scr) and text files with
# Forth source code in them (*.scn).

# The program takes an input file, with an extension of .scr or
# .scn. It creates the output file with the same base name and the
# other extension. It then processes the input file, using the process
# indicated by the input extension. For example,

# scr2scn foo.scr

# will produce the text file foo.scn from the forth screens in
# foo.scr. To go the other way,

# scr2scn foo.scn

use strict;
use 5.010;
use warnings;
use Getopt::Long qw(:config pass_through);
use File::Basename;

my $iNeedHelp;
my $script = basename ($0);
my $verbose = 0;
my $srcFile = '';

sub help () {
  print qq~
Usage:
   $script [OPTIONS] sourceFile
   Valid extensions are .scr and .scn

Options:
   --help           Show this screen
   --verbose        Be verbose
~;
}


GetOptions("help"      => \$iNeedHelp,
           "verbose"   => \$verbose,
          )
  or die("Error in command line arguments\n");

$srcFile = $ARGV[0];

if ($srcFile eq "") {
  print "ERROR: The source file is missing!\n";
  help ();
  exit;
}

if ($iNeedHelp) {
  help;
  exit;
}

# regex from https://perldoc.perl.org/File/Basename.html
my ($base, $dir, $ext) = fileparse ($srcFile, qr/\.[^.]*/);

my $destFile = ${dir} . ${base};

if ($ext eq '.scr') {
  $destFile .= '.scn';
} elsif ($ext eq '.scn') {
  $destFile .= '.scr';
} else {
  help ();
  die ("$ext is not a valid extension.\n")
}


if ($verbose) {
  print ("\$base is |$base| \$ext is |$ext|. \$dir is |$dir|\n");
  print ("Source file name is |${dir}${base}${ext}|\n");
  print ("Destination file is |$destFile|\n");
}

# open DEST read and write, create & truncate.
open (DEST, "+> $destFile") or die ("Can't open destination file $destFile.\n");
open (SRC,  "< $srcFile")  or die ("Can't open source file $srcFile.\n");

my $buf;
my @array;
my $i;

if ($ext eq ".scr") {
  # screens file to test file.
  while (read (SRC, $buf, 64)) {
    @array = unpack ("C*", $buf);
    if ($array[0] == 0 and $array[1] == 0) {
      # Non-printable screen
      print "Non-printable screen.\n" if ($verbose);
      print DEST "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n";
      my $results = read (SRC, $buf, 1024-64);
      if ($results != 1024-64) {
        die ("Read error in non-printable screen.\n");
      }
    } else {
      # Printable screen

      # first line.....
      $buf =~ s/\s+$//;         # trim trailing spaces.
      print DEST "$buf\n";

      # subsequent lines....
      for ($i = 15; $i > 0 ; $i--) {
        my $result = read (SRC, $buf, 64);
        $buf =~ s/\s+$//;       # trim trailing spaces.
        print DEST "$buf\n";
      }
    }
  }

} else {
  # File to screens file.
  my $line;

  # 64 blanks, for padding out each line.
  my $blanks = '                                                                ';

  while (defined ($line = <SRC>)) {
    chomp $line;
    my $size = length ($line);
    print DEST $line;

    print DEST substr ($blanks, 0, 64-$size);

    $i++;
  }

  print ("$i lines shipped so far.\n") if ($verbose);
  while ($i%16 != 0) {
    print ("$i\n") if ($verbose);
    print DEST $blanks;
    $i++;
  }

  # OK, we've made our file. Now find screens with nothing but blanks
  # in them, and stick 0 in the first two words.
  seek (DEST, 0, 0);

  # prepare our two bytes of 0s for blank screens.
  my $blankScreen = '';
  $array[0] = $array[1] = 0;
  $blankScreen = pack ("C*", @array);

  $i = 0;

  while (read (DEST, $buf, 1024)) {

    # print $i % 15 . "\n";
    
    if (($i % 15) == 0 and $verbose) {
      print sprintf("\n%5d:", $i);
    }
    
    $buf =~ s/\s+$//;       # trim trailing spaces.

    if (length ($buf) == 0) {
      # print ("$i: Non-priniting screen.\n") if ($verbose);

      # seek back one screen....
      seek (DEST, -1024, 1);

      # write the two 0s already prepared....
      print DEST $blankScreen;

      # seek forward to the next screen....
      seek (DEST, +1022, 1);

      printf ('%4d', $i) if ($verbose);
    } else {
     print '   .' if ($verbose); 
    }

    $i++;
  }
}

close (SRC)  or die ("Can't close source file $srcFile.\n");
close (DEST) or die ("Can't close destination file $destFile.\n");
