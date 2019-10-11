#!/bin/env perl

die "Usage: b64Validate <file name> \n" unless scalar(@ARGV) == 1 ;
$argFile = shift;
open(FH, "< $argFile") or die "Unable to open $argFile: $!/n";

$expectedLength = 0;
$linecount = 1;
while( <FH> ) {
    if( $expectedLength == 0 ) {
        $expectedLength = length($_);
    }
    $line = $_;
    if( length($line) != $expectedLength ) {
        print("Non-Uniform Length Found at line $linecount:");
        print("< $line >\n");
    }
    $linecount++;
}

close(FH);
exit;

