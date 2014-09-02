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
my $help=0;

my $CHUNK_NUM=0;

my $CHUNK_SIZE=0;
my $CHUNK_FIRST=1;
my $CHUNK_LAST=0;
my $CHUNK_STEP=1;
my $CHUNK_STEP_NUM=1;

my $OUT="";
my $OUT_SPLIT=0;
my $MAX_BLOCK_SIZE=1000000;

my $cache = "";

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

sub expand_byte_suffix
{
    my ($value) = @_;

    if ($value =~ /^\d+$/)
    {
	return $value+0;
    } elsif  ($value =~ /^(\d+)\s*([kmg])$/i)
    {
	my ($base, $suffix) = ($1, $2);
	return $base*1024**(index("kmg", lc($suffix))+1);
    } else {
	die "The value '$value' does not represent a number or a suffixed number!\n";
    }
}

sub guess_file_format
{
    my ($fh) = @_;

    # read the first byte of the file
    my $first_byte = "";
    my $bytes_received=read $fh, $first_byte, 1;
    if ($bytes_received != 1)
    {
	die "Error on retriving first byte from file: $!\n";
    }

    # check the first byte for indicating a fasta (>), fastq (@) or other file ([^>@])

    if ($first_byte eq "@")
    {
	$cache = $first_byte;
	return "fastq";
    } elsif ($first_byte eq ">")
    {
	$cache = $first_byte;
	return "fasta";
    } else {
	return undef;
    }

}

sub get_chunk
{
    my (
	$fh,
	$output_fh,
	$fileformat,
	$skip
	) = @_;

    my $starting_pos = tell($fh);

    if ($_debug)
    {
	printf "Starting file position: current %d, but should be %d\n", $starting_pos, $starting_pos-length($cache);
    }

    # we reduce the chunk size by 10 to find the right new block
    my $security_margin = 10;

    my $chunksize2get = $CHUNK_SIZE - $security_margin - length($cache);

    my $buffer = $cache;
    # empty cache
    $cache = "";

    # print the buffer to output_fh if skip is not set
    if ($skip == 0 && $buffer)
    {
	print $output_fh $buffer;
    }

    # read the number of chunksize2get bytes if skip is not set
    if ($skip == 0)
    {
	my $bytesread = read($fh, $buffer, $chunksize2get);
    } else {
	seek($fh, $chunksize2get, 1);
    }

    # print the buffer to output_fh if skip is not set
    if ($skip == 0 && $buffer)
    {
	print $output_fh $buffer;
    }

    # find the next block
    # read until the next line break
    $buffer = <$fh>;

    # minimum length of buffer have to be 10
    if ($buffer && length($buffer) <= $security_margin)
    {
	# print the buffer to output_fh if skip is not set
	if ($skip == 0  && $buffer)
	{
	    print $output_fh $buffer;
	}
	# and get the next line
	$buffer = <$fh>;
    }

    # print the buffer to output_fh if skip is not set
    if ($skip == 0 && $buffer)
    {
	print $output_fh $buffer;
    }

    # find next block
    while (1)
    {
	$buffer = <$fh>;

	# check if we reached the eof and leave the loop in this case
	if (eof($fh))
	{
	    last;
	}

	# check if buffer contains a new block
	if (($fileformat eq "fasta" && $buffer =~ /^>/) || ($fileformat eq "fastq" && $buffer =~ /^@/))
	{
	    # store the new block inside the cache variable
	    $cache = $buffer;
	    # and leave the loop
	    last;
	} else {
	    # not a new block so print the buffer to output_fh if skip is not set
	    if ($skip == 0  && $buffer)
	    {
		print $output_fh $buffer;
	    }
	}
    }
}

sub main_loop
{
    my @files = @_;

    foreach my $act_file (@files)
    {
	# check if the file exists
	unless (-e $act_file)
	{
	    die "The file '$act_file' does not exist!\n";
	}

	# get the filesize and open the file
	my $filesize = (stat($act_file))[7];

	if ($_debug) { printf STDERR "Filesize for file '%s' is %d bytes!\n", $act_file, $filesize; }

	open(my $fh, "<", $act_file) || die "Unable to open file '$act_file' for reading\n";

	my $fileformat=guess_file_format($fh) || die "The file '$act_file' seems to be neigher a FASTQ nor a FASTA file\n";

	# calculate the chunk size and the number of chunks expected
	if ($CHUNK_SIZE == 0)
	{
	    $CHUNK_SIZE=int($filesize/$CHUNK_NUM)+1;
	} else {
	    $CHUNK_NUM=int($filesize/$CHUNK_SIZE)+1;
	}

	# set chunk last if not set
	if ($CHUNK_LAST == 0)
	{
	    $CHUNK_LAST=$CHUNK_NUM;
	}

	# print debug information
	if ($_debug)
	{
	    printf STDERR "ARGV=%s\nCHUNK_SIZE=%d\nCHUNK_NUM=%d\nCHUNK_FIRST=%d\nCHUNK_LAST=%d\nCHUNK_STEP=%d\nCHUNK_STEP_NUM=%d\n", join(",", @_), $CHUNK_SIZE, $CHUNK_NUM, $CHUNK_FIRST, $CHUNK_LAST, $CHUNK_STEP, $CHUNK_STEP_NUM;
	}

	# counter for the current chunk
	my $current_chunk=1;

	# this variable determines if a block should be skipped (=1) or kept (=0)
	my $skip = 1;

	# process all chunks until LAST_CHUNK is reached
	while ($current_chunk<=$CHUNK_LAST)
	{
	    # skipped should be true, if the number of the current_chunk < $CHUNK_FIRST
	    if ($current_chunk < $CHUNK_FIRST)
	    {
		$skip = 1;
	    }

	    # moreover if not every chunk should be returned, we have to determine if this chunk should be returned or not
	    if ((($current_chunk-$CHUNK_FIRST)%$CHUNK_STEP) < $CHUNK_STEP_NUM)
	    {
		$skip = 0;
	    } else {
		$skip = 1;
	    }

	    # generate the filehandle for the output
	    my $output_fh = undef;
	    my $output_filename = undef;

	    if ($OUT_SPLIT && $skip == 0)
	    {
		$output_filename = sprintf($OUT, $current_chunk);
		if ($_debug)
		{
		    printf STDERR "The next filename for output is '%s'\n", $output_filename;
		}
		open($output_fh, ">", $output_filename) || die "Unable to open file '$output_filename' for writing! $!\n";
	    } else {
		$output_fh = *STDOUT;
	    }

	    get_chunk($fh, $output_fh, $fileformat, $skip);

	    # close the file if a new one was created
	    if ($OUT_SPLIT && $skip == 0)
	    {
		close($output_fh) || die "Unable to open file '$output_filename' after writing! $!\n";
	    }

	    $current_chunk++;

	    # check if the whole file was read
	    if (eof($fh))
	    {
		last;
	    }
	}

	close($fh) || die "Unable to close file '$act_file' after reading\n";
    }
}

GetOptions(
    'chunk-number|n=i' => \$CHUNK_NUM,
    'chunk-size|s=s' => \$CHUNK_SIZE,
    'first-chunk|f=i' => \$CHUNK_FIRST,
    'chunk-step|x=i' => \$CHUNK_STEP,
    'chunks-per-step|y=i' => \$CHUNK_STEP_NUM,
    'debug|d' => \$_debug,
    'help|?|h' => \$help,
    'out|o=s' => \$OUT,
    );

if ($help)
{
    show_help();
    exit;
}

$CHUNK_SIZE=expand_byte_suffix($CHUNK_SIZE);

if ($OUT)
{
    $OUT_SPLIT=1;
}

main_loop(@ARGV);

sub test_expand_byte_suffix
{
    foreach (qw(100 0001 15 10k 10K 10m 10M 10g 10G 5 9L4))
    {
	print STDERR expand_byte_suffix($_), "\n";
    }
}

sub test_guess_file_format
{
    foreach (qw(test.fasta test.fastq test.other))
    {
	open(my $fh, "<", $_) || die;
	my $fileformat=guess_file_format($fh) || die "The file seems to be neigher a FASTQ nor a FASTA file\n";
	print STDERR "$_ was detected as $fileformat\n";
	close($fh) || die;
    }
}

__END__
