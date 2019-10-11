# finalMarks.pl
# Bookmarks: 1,6 1,9 1,20 1,31 1,41
# CALCULATE THE FINAL MARKS AND PRINT THEM OUT FROM HIGHEST TO LOWEST 

#open file
open(MARKS, "finalMarks.in") or die "Can't open finalMarks.in: $!\n" ;

#process each line and store the values in hashes
while ($line = <MARKS>) {
  #split the line into the stud#, assignment marks, midterm, final, and grade
  ($studnum, $a1, $a2, $a3, $a4, $mid, $final, $grade) = split / /, $line ;
  #concatenate the marks into one string as the value of key studnum in hash %marks
  $marks{$studnum} = $a1 . " " . $a2 . " " . $a3 . " " . $a4 . " " . $mid . " " . $final ;
  #put grade as the value of studnum in a separate hash %grades
  $grades{$studnum} = $grade ;
  }

#sort in order of studnum
#use default variable $_ for the value of studnum in each loop
foreach (sort keys %marks) {
  $total = 0 ;
  #split out the marks into array @marks and add them up into $total
  @marks = split / /, $marks{$_} ;
  foreach $mark (@marks) {
    $total += $mark ;
    }
  #create hash %totals with total as the key and studnum as the value of each entry
  $totals{$total} = $_ ;
  }

$count = 1 ;
$sum = 0 ;
#sort in order from highest total mark to lowest
#print out the rank($count), total($_), studnum($totals{$_}), and grade($grades{$totals{$_}}) 
foreach (reverse sort keys %totals) {
  print "$count/$_:\t$totals{$_}\t$grades{$totals{$_}}\n" ;
  $count++ ;
  $sum += $_ ;
  }

$ave = $sum/$count ;
#print out the average mark
print "\n Average:\t$ave\n" ;

