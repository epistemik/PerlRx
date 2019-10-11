#!/usr/local/bin/perl

use strict;

my ($file, $valid, $filemode, $outfile, $decodedline);

unless (@ARGV == 1)
{
	die <<EOF
Usage: $0 $file

Where file is the name of the file you want to decode
EOF

}

open(INFILE,"<" . $ARGV [0]) || die "Can't open the input file";

$valid=0;

while (<INFILE>)
{
	if (/^begin\s+(\d+)\s+(.*)/) 
	{
		$filemode=$1;
		$outfile=$2;
		$valid=1;
		last;
	}
}

$valid ? print "Creating $outfile\n" : die "Not a UU file";

open(OUTFILE, ">$outfile") || die "Can't open the output\n";

while(<INFILE>)
{
	$decodedline = unpack("u",$_);
	die "Invalid uuencoded line" if (!defined($decodedline));
	print OUTFILE $decodedline;
	/^end$/ && last;
}

close (INFILE);
close (OUTFILE);
chmod oct($filemode), $outfile;
