#!/usr/bin/perl -s

# see "Cryptonomicon" by Neal Stephenson, p.480
# DOES NOT WORK !!
# sub e starts an infinite loop ... problem with eval

# usage: <this file name> [-d] <key> <stream to en/de-crypt: file name OR stdin>

$f = $d ? -1 : 1 ;
$D = pack( 'C*', 33..86 );

$p = shift ;
$p =~ y/a-z/A-Z/ ;

$U = '$D =~ s/(.*)U$/U$1/; $D =~ s/(U.)/$1U/;' ;
# print "\$U = $U\n" ;
($V = $U) =~ s/U/V/g ;
# print "\$V = $V\n" ;

$p =~ s/[A-Z]/$k = ord($&)-64, &e/eg ;
$k = 0 ;

while( <> )
{
  y/a-z/A-Z/ ;
  y/A-Z//dc ;
  $o .= $_
}
#print "$o\n" ;

$o .= 'X' while length($o)%5 && !$d ;
#print "$o\n" ;

$o =~ s/./chr( ($f*&e + ord($&) - 13)%26+65 )/eg ;
#print "$o\n" ;

$o =~ s/X*$// if $d ;
#print "$o\n" ;

$o =~ s/.{5}/$& /g ;

print "$o\n" ;

sub v
{
  $v = ord( substr($D,$_[0]) )-32 ;
  $v>53 ? 53 : $v
}

sub w
{ $D =~ s/(.{$_[0]})(.*)(.)/$2$1$3/ }

sub e
{
	#+ ORIGINAL PONTIFEX CODE
  eval "$U$V$V" ;
	print "eval" ;
  $D =~ s/(.*)([UV].*[UV])(.*)/$3$2$1/;
  &w( &v(53) );
  $k ? ( &w($k) ) : ( $c=&v(&v(0)), $c>52 ? &e : $c )
}
	#+ SOLITAIRE CODE
    ## If the U (joker A) is at the bottom of the deck, move it to the top
    #$D =~ s/(.*)U$/U$1/;
    ## Swap the U (joker A) with the card below it
    #$D =~ s/U(.)/$1U/;
		
    ## Do the same as above, but with the V (joker B), and do it twice.
    #$D =~ s/(.*)V$/V$1/; $D =~ s/V(.)/$1V/;
    #$D =~ s/(.*)V$/V$1/; $D =~ s/V(.)/$1V/;

    ## Do the triple cut: swap the pieces before the first joker, and
    ## after the second joker.
    #$D =~ s/(.*)([UV].*[UV])(.*)/$3$2$1/;
		
    ## Do the count cut: find the value of the bottom card in the deck
    #$c=&v(53);
    ## Switch that many cards from the top of the deck with all but
    ## the last card.
    #$D =~ s/(.{$c})(.*)(.)/$2$1$3/;
		
    ## If we're doing key setup, do another count cut here, with the
    ## count value being the letter value of the key character (A=1, B=2,
    ## etc.; this value will already have been stored in $k).  After the
    ## second count cut, return, so that we don't happen to do the loop
    ## at the bottom.
    #if( $k ){
		#  $D =~ s/(.{$k})(.*)(.)/$2$1$3/;
		#  return; }
		
    ## Find the value of the nth card in the deck, where n is the value
    ## of the top card (be careful about off-by-one errors here)
    #$c = &v( &v(0) );
		
    ## If this wasn't a joker, return its value.  If it was a joker,
    ## just start again at the top of this subroutine.
    #$c>52 ? &e : $c ;
