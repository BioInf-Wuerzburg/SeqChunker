#!/bin/bash
show_usage()
{
  echo "Usage: file_chunk [OPTIONS...] FILE1 FILE2 ..."
}

show_help()
{
  show_usage
  cat <<\EOF

file_chunk samples and outputs chunks of a FASTA/FASTQ files, e.g. to serve
as on-the-fly input for other tools. 

--verbose
--help ...

EOF
}



# Execute getopt
ARGS=`getopt -o "123:" -l "one,two,three:" \
      -n "getopt.sh" -- "$@"`

#Bad arguments
if [ $? -ne 0 ];
then
  exit 1
fi

# A little magic
eval set -- "$ARGS"

# Now go through all the options
while true;
do
  case "$1" in
    -1|--one)
      echo "Uno"
      shift;;

    -2|--two)
      echo "Dos"
      shift;;

    -3|--three)
      echo "Tres"

      # We need to take the option argument
      if [ -n "$2" ];
      then
        echo "Argument: $2"
      fi
      shift 2;;

    --)
      shift
      break;;
  esac
done

DEBUG=2;
FILE_SIZE=20809342;
CHUNK_NUM=1000;
SAMPLE_PERCENTAGE=${1:-100}
CHUNK_SIZE_BRUTTO=$(( 20809342 / $CHUNK_NUM ));
CHUNK_SIZE_NETTO=$(( 20809342 * $SAMPLE_PERCENTAGE / $CHUNK_NUM * 100 ));
CHUNK_SIZE_DELTA=$(( $CHUNK_SIZE_BRUTTO - $CHUNK_SIZE_NETTO ));
[ $DEBUG -gt 0 ] && (
	echo CHUNK_SIZE_BRUTTO=$CHUNK_SIZE_BRUTTO 1>&2;
	echo CHUNK_SIZE_NETTO=$CHUNK_SIZE_NETTO 1>&2;
	echo CHUNK_SIZE_DELTA=$CHUNK_SIZE_DELTA 1>&2;
)

MAX_BLOCK_SIZE=1000000;
INFILE="/home/dumps/projects/dmuscipula/DmGenPb8.4b.fa"
#$PWD/"t/test.fa";  # $1
SKIP=0;				# $2

# Required in case $CHUNK_SIZE <= $MAX_BLOCK_SIZE
BLOCK_COUNT=$(( $CHUNK_SIZE_NETTO / $MAX_BLOCK_SIZE ))
BLOCK_REST=$(( $CHUNK_SIZE_NETTO % $MAX_BLOCK_SIZE ))

REC_CACHE="";

(
	# skip
	if [[ $SKIP > 0 ]];	then
		[ $DEBUG -gt 0 ] && echo "--offset skipping" #1>&2;
		dd bs=1 skip=$SKIP count=0 status=noxfer 2>/dev/null; 
	fi;

	# chunks
	#for I in $(seq 1 1 $CHUNK_NUM); do
for I in {1..2}; do
		# check cache
		if [ ! -z $REC_CACHE ]; then
			[ $DEBUG -gt 0 ] && echo "--cache" #1>&2;
			echo C:"$REC_CACHE";
		else
			# first record
			[ $DEBUG -gt 0 ] && echo "--first record" #1>&2;
	   	    grep -m1 -P '^>';
		fi;
			
		
		
		# chunk core
		[ $DEBUG -gt 0 ] && echo "--chunk content" #1>&2;

		if [[ $CHUNK_SIZE_NETTO < $MAX_BLOCK_SIZE ]]; then
			dd bs=$CHUNK_SIZE_NETTeO count=1 2>/dev/null;
		else
			dd bs=$MAX_BLOCK_SIZE count=$BLOCK_COUNT 2>/dev/null;
			dd bs=$BLOCK_REST count=1 2>/dev/null;
		fi;
		
		# last record
		[ $DEBUG -gt 0 ] && echo "--last record" #1>&2;
				# /^>/!p,
		REC=$(sed --unbuffered '/^>/q');
		# bad - newline in string, not replace whitespace
		echo "$REC" | head -n -1;
		
		# only required if $SAMPLE_RATIO ~ 1 and really every read is required
		if [[ $SAMPLE_RATIO == 1 ]]; then
			REC_CACHE=$(echo "$REC" | tail -n 1);
		else
			[ $DEBUG -gt 0 ] && echo "--inter-chunk skipping" #1>&2;
			dd bs=1 skip=$CHUNK_SIZE_DELTA count=0 status=noxfer 2>/dev/null; 
		fi;
	
	
	done;

	# next chunk
	#echo -e "\n------"  1>&2;
	#echo $REC_CACHE;
	#dd bs=$CHUNK_SIZE count=1 2>/dev/null;


) < "$INFILE"


# REC_OFF=$(grep -b -m1 -P '^>'); 
# REC=${REC_OFF#*:}; 
# OFF=${REC_OFF%%[^0-9]*};
# echo $REC "("$OFF")"; 
# let OFF+=1; 


#(
#  dd bs=1 skip=$skip count=0
#  dd bs=$bs count=$(($length / $bs))
#  dd bs=$(($length % $bs)) count=1
#) 
