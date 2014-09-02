#!/usr/bin/env perl

##----------------------------------------------------------------------------##
# Author: Frank Foerster, frank.foerster@biozentrum.uni-wuerzburg.de
# Based on SeqChunker.chunk by Thomas Hackl, thomas.hackl@uni-wuerzburg.de
# Last Modified: Frank Foerster, 2014-09-02
# Version 0.1

##----------------------------------------------------------------------------##
## TODO
# BUGS
#  non known

# FEATURES
#  stdin - problem: cannot autocompute...
#  rand - if possible with seed to allow for consistent recomputation

##----------------------------------------------------------------------------##
## CHANGELOG

## 0.1
#  First implementation to test speed of perl implementation

use strict;
use warnings;

use Getopt::Long;

# Variable defaults
my $_debug=1;

my $CHUNK_NUM=0;

my $CHUNK_SIZE=0;
my $CHUNK_FIRST=1;
my $CHUNK_LAST=0;
my $CHUNK_STEP=1;
my $CHUNK_STEP_NUM=1;

my $OUT="";
my $OUT_SPLIT=0;
my $MAX_BLOCK_SIZE=1000000;

my $SED_FASTA='/^>/{p;Q}'; # with -n, prints only matching line with,
                       #  else prints all previous lines + matching line

my $SED_FIRST_FASTQ='/^@/ { # if ^@
                N # read a second line
                /\n@/ { s/^@.*\n// ; N} # remove first line and read another
                N;N;p;q; # read two more lines, print and quit
        }';

my $SED_LAST_FASTQ='/^@/ { # if ^@
                N # read a second line
                /\n@/ { N } # read additonal line if second is head
                N;N;q; # read two more lines, print and quit
        }';

my $PRINTF_DEBUG="  %-10s %10s : '%s'\n";


sub show_usage
{
    printf "Usage: SeqChunker --chunk-number/--chunk-size INT [OPTIONS ...] FILE1 FILE2 ...";
}

sub show_help
{
    show_usage();
    print<<EOF;

SeqChunker efficiently samples and outputs chunks from FASTA and FASTQ files,
 e.g. to serve as on-the-fly input for other tools.

Required: Either one of the following, but not both at the same time. The unset
 parameter is computed respectively.

  -n/--chunk-number       Total number of chunks to be sampled (including
                          skipped ones).
  -s/--chunk-size         Size of chunks to be sampled. Supports suffixes "k,M,G".

Optional:

  -f/--first-chunk        Skip chunks before this chunk [$CHUNK_FIRST]
  -l/--last-chunk         Last after this chunk (including skipped ones) [$CHUNK_LAST]
  -x/--chunk-step         Output a chunk every -x chunks [$CHUNK_STEP]
  -y/--chunks-per-step    Output -y chunks every -x chunks. Cannot be greater
                          than -x [$CHUNK_STEP_NUM]

  -o/--out                Output filename. To split chunks into individual files
                          provide a "printf" style pattern, e.g. "chunk%02d.fa",
                          with a substitution for the chunk counter.
  -m/--max-block-size     Maximum size of blocks in output stream [$MAX_BLOCK_SIZE]
  -q/--quiet              Suppress non-critical messages
  -V/--version            Version of the script.
  -d/--debug              Output more verbose messages
  -h/--help               Show this help screen

NOTE: Chunk sizes need to be at least twice as great as the longest record in
 the file. Otherwise results will be inconsistent.

NOTE: Chunk related computations are run each input file individually.


  # output only even numbered chunks
  SeqChunker --chunk-size 5M --chunk-first 2 --chunk-step 2 my.fa

  # Split file in 100 individual files of similar size
  SeqChunker --chunk-number 100 --out "my.%03d.fa" my.fa

EOF
}

__END__


