#!/bin/bash

DIR=$(dirname $0);
cd $DIR;
SC="$DIR/../bin/SeqChunker"
TC=0;
rm -f tmp*;

TEMPFILENAME="$DIR/tmp"
# delete all existing tmp files
rm -f "$TEMPFILENAME"*;

TESTCOUNTER=1;

TOTAL_NUMBER_OF_TESTS=56

echo "$TESTCOUNTER..$TOTAL_NUMBER_OF_TESTS"

##----------------------------------------------------------------------------##
#
# Define a SeqChunker test script
#
##----------------------------------------------------------------------------##

function test_SeqChunker {
    local DESC="$1"
    local cmd="$2"

    # assume empty special flag
    local SPECIAL_FLAG=""

    local TAP_DIRECTIVE=""


    local STATUS="ok"

    # assume the third parameter set special switches
    if [ $# -ge 3 ]
    then
	SPECIAL_FLAG="$3"
    fi

    # assume the fourth parameter set TODO/SKIP
    if [ $# -ge 4 ]
    then
	TAP_DIRECTIVE="$4"
    fi

    if [[ $SPECIAL_FLAG =~ PIPE ]]
    then
	$cmd 2>/dev/null >"$TEMPFILENAME"."$TESTCOUNTER".01
    else
	$cmd 2>/dev/null >/dev/null
    fi

    # combine all output to a single file
    # check if the output files are existing
    FILELIST=$(find $(dirname "$TEMPFILENAME") -name $(basename "$TEMPFILENAME")".$TESTCOUNTER.*")
    if [ "$FILELIST" == "" ]
    then
	echo "" >"$TEMPFILENAME"
    else
	cat "$TEMPFILENAME"."$TESTCOUNTER".* >"$TEMPFILENAME"
    fi

    # assume a passed test
    STATUS="ok"

    # test if the special_flag contains partial
    if [[ $SPECIAL_FLAG =~ AGAINST_LAST_RUN ]]
    then
	for FILENUMBER in $(find $(dirname "$TEMPFILENAME") -name $(basename "$TEMPFILENAME")".$TESTCOUNTER.*" | sed 's/^.*\([0-9]*\)$/\1/g')
	do
	    LAST_RUN="$TEMPFILENAME".$((TESTCOUNTER-1))."$FILENUMBER"
	    NEW_RUN="$TEMPFILENAME"."$TESTCOUNTER"."$FILENUMBER"
	    DIFF=$(diff "$LAST_RUN" "$NEW_RUN")
	    if [ ! -z "$DIFF" ]; then
		STATUS="not ok"
	    fi
	done
    else
	# not against last run... Just compare against input data set
	DIFF=$(diff "$EC" "$TEMPFILENAME")
	if [ ! -z "$DIFF" ]; then
	    STATUS="not ok"
	fi
    fi

    echo "$STATUS $TESTCOUNTER - $DESC (command was '$cmd') $TAP_DIRECTIVE"

    # finally increment the test counter
    TESTCOUNTER=$((TESTCOUNTER+1))
}


##----------------------------------------------------------------------------##
#
# Cycle through all SeqChunker implementations
#
##----------------------------------------------------------------------------##
for SC in "$DIR"/../bin/SeqChunker "$DIR"/../bin/SeqChunker-perl "$DIR"/../bin/SeqChunker-dd "$DIR"/../bin/SeqChunker-sed
do
    TAP_DIRECTIVE=""
    ##----------------------------------------------------------------------------##
    # Set TAP directive to TODO if SeqChunker-sed is called
    ##----------------------------------------------------------------------------##
    if [[ "$SC" =~ -sed ]]
    then
	TAP_DIRECTIVE="# TODO SeqChunker-sed seems to be broken"
    fi

    ##----------------------------------------------------------------------------##
    # Set TAP directive to TODO if SeqChunker-dd is called and bash version <4
    ##----------------------------------------------------------------------------##
    if [[ "$SC" =~ -dd ]]
    then
	BASH_MAJOR_VER=$(bash --version | grep -Eo [0-9][.][0-9] | cut -d. -f1)
	if [ $BASH_MAJOR_VER -lt 4 ]
	then
	    TAP_DIRECTIVE="# TODO SeqChunker-dd requires bash version >= 4"
	fi
    fi


    ##----------------------------------------------------------------------------##
    #
    # Run FASTA test scripts
    #
    ##----------------------------------------------------------------------------##

    # define input file
    EC="$DIR/ec.fa"

    test_SeqChunker "FASTA: split pipe"  "$SC -n 10 $EC" "PIPE" "$TAP_DIRECTIVE"
    test_SeqChunker "FASTA: split file"  "$SC -n 20 $EC -o $TEMPFILENAME.$TESTCOUNTER.%02d" "" "$TAP_DIRECTIVE"
    test_SeqChunker "FASTA: split steps" "$SC -n 20 -x 5 $EC -o $TEMPFILENAME.$TESTCOUNTER.%02d" "AGAINST_LAST_RUN" "$TAP_DIRECTIVE"
    test_SeqChunker "FASTA: split file many chunks" "$SC -n 1000 $EC -o $TEMPFILENAME.$TESTCOUNTER.%04d" "" "$TAP_DIRECTIVE"
    test_SeqChunker "FASTA: split last first" "$SC -n 1000 -f 1000 -l 1000 $EC -o $TEMPFILENAME.$TESTCOUNTER.%04d" "AGAINST_LAST_RUN" "$TAP_DIRECTIVE"
    test_SeqChunker "FASTA: split file as preparation (same as split file test)"  "$SC -n 20 $EC -o $TEMPFILENAME.$TESTCOUNTER.%02d" "" "$TAP_DIRECTIVE"
    test_SeqChunker "FASTA: split first last step" "$SC  -n 20 -x 5 -y 2 -f 2 -l 12 $EC -o tmp.$TESTCOUNTER.%02d" "AGAINST_LAST_RUN" "$TAP_DIRECTIVE"

    ##----------------------------------------------------------------------------##
    #
    # Run FASTQ test scripts
    #
    ##----------------------------------------------------------------------------##

    # define input file
    EC="$DIR/ec.fq"

    test_SeqChunker "FASTQ: split pipe"  "$SC -n 10 $EC" "PIPE" "$TAP_DIRECTIVE"
    test_SeqChunker "FASTQ: split file"  "$SC -n 20 $EC -o $TEMPFILENAME.$TESTCOUNTER.%02d" "" "$TAP_DIRECTIVE"
    test_SeqChunker "FASTQ: split steps" "$SC -n 20 -x 5 $EC -o $TEMPFILENAME.$TESTCOUNTER.%02d" "AGAINST_LAST_RUN" "$TAP_DIRECTIVE"
    test_SeqChunker "FASTQ: split file as preparation (same as split file test)"  "$SC -n 20 $EC -o $TEMPFILENAME.$TESTCOUNTER.%02d" "" "$TAP_DIRECTIVE"
    test_SeqChunker "FASTQ: split first last step" "$SC -n 20 -x 5 -y 2 -f 2 -l 12 $EC -o $TEMPFILENAME.$TESTCOUNTER.%02d" "AGAINST_LAST_RUN" "$TAP_DIRECTIVE"
    test_SeqChunker "FASTQ: split file as preparation (same as split file test)"  "$SC -n 20 $EC -o $TEMPFILENAME.$TESTCOUNTER.%02d" "" "$TAP_DIRECTIVE"
    test_SeqChunker "FASTQ: split first last step" "$SC -n 20 -f 19 -l 19 $EC -o $TEMPFILENAME.$TESTCOUNTER.%02d" "AGAINST_LAST_RUN" "$TAP_DIRECTIVE"

    ##----------------------------------------------------------------------------##
    #
    # Clean up
    #
    ##----------------------------------------------------------------------------##
    rm tmp*

    ##----------------------------------------------------------------------------##
    #
    # And skip md5 based tests for now
    #
    ##----------------------------------------------------------------------------##
    continue

    # check against the dd-based estimated checksums
    DESC="Checksum test"
    echo "Test #"$((++TC))" $DESC";
    cmd="md5sum -c MD5SUM.dd --quiet"
    echo "$cmd";
    $cmd;
    if [ $? -ne 0 ]; then
	echo "..failed"
	echo "Different checksums found:" 1>&2;
	exit 1;
    fi;
    echo "..ok"

done
