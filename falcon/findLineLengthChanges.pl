#!/bin/env perl

die "Usage: findLineLengthChanges <file name> \n" unless scalar(@ARGV) == 1 ;
$argFile = shift;
open(FH, "< $argFile") or die "Unable to open $argFile: $!/n";

$expectedLength = 0;
$linecount = 1;
while( <FH> ) {
    $line = $_;
    if( length($line) != $expectedLength ) {
        $expectedLength = length($line);
        chomp($line);
        print("Non-Uniform Length ($expectedLength) found at line $linecount: $line\n");
    }
    $linecount++;
}

close(FH);
exit;

