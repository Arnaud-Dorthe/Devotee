#!/usr/bin/perl

#    condorcet.pl - tallies ranked preference ballots using Condorcet's method
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
#    For more information about this program, check out my home page
#    at <URL:http://www.eskimo.com/~robla>, or email me (Rob Lanphier
#    <robla@eskimo.com>) for what the web page doesn't answer.
#
#    See $helpstring below for more details.

use strict;

#  Variable "declaration"

#  $tally[candx][candy]
#  $tally is a two-dimensional array (ala Perl 5) that stores the
#  number of votes that candx received over candy.
my @tally;


# $Candidates[candx] is the name of the candidate (option)
my @Candidates = (
		  "",
		  "Moshe Zadka",
		  "Bdale Garbee",
		  "Branden Robinson",
                  "Martin Michlmayr",
		  "None Of The Above"
		 );

# Total number of candidates (nominally $#Candidates)
my $candidates = 0;

# The total number of votes cast
my $total_vote = 0;

while (my $line = <>) {
  chomp $line;
  next unless ($line =~ m/^V:\s+(\S+)\s+\S+$/);
  $total_vote++;
  my $vote = $1;

  $candidates = length($vote) unless ($candidates >= length($vote));
  for my $l (1..($candidates-1)) {
    for my $r (($l+1)..$candidates) {

      my $L = substr($vote, $l-1, 1);
      my $R = substr($vote, $r-1, 1);

      if ($L eq "-" && $R eq "-") {
	next;
      } elsif ($R eq "-" || ($L ne "-" && $L < $R)) {
	$tally["$l"]["$r"]++;
      } elsif ($L eq "-" || $R < $L) {
	$tally["$r"]["$l"]++;
      } else {
	# equally ranked, tsk tsk
      }
    }
  }
}

# Variable declaration for @results
# A two-dimensional array storing election results for each candidate
my @results;

# Initialize the @results array.
for my $i (1 .. $candidates) {
  $results[$i][0]=0;		# Number of victories for $i
  $results[$i][1]=0;		# Number of ties for $i
  $results[$i][2]=0;		# Number of defeats for $i
  $results[$i][3]=0;		# Worst defeat, as measured by
  # total votes against $i
}


# Now for the pairwise tally...
for my $i (1..($candidates-1)) {
  for my $j (($i+1)..$candidates) {
    if (!defined($tally[$i][$j])) # Initialize the tally
      # array for uninitialized value.
      {
	$tally[$i][$j] =0;
      }
    if (!defined($tally[$j][$i])) {
      $tally[$j][$i] =0;
    }

    my $itally = $tally[$i][$j]; # Votes for candidate   number $i
    my $jtally =$tally[$j][$i]; # Votes for candidate number $j

    # This is a gross hack. (I should replace it with more understandable code)
    # If candidate i has won, then $itally <=> $jtally = -1
    #                              $x would be -1 + 1  =  0
    #                              $y would be  2 - 2  =  2
    # If candidate j has won, then $itally <=> $jtally =  1
    #                              $x would be  1 + 1  =  2
    #                              $y would be  2 - 2  =  0
    # If niether wins, i.e., a tie $itally <=> $jtally =  0
    #                              $x would be  0 + 1  =  1
    #                              $y would be  2 - 1  =  1
    my $x =($itally <=> $jtally)+1;
    my $y =2-$x;
    $results[$i][$x]++;
    $results[$j][$y]++;


    if ($jtally > $results[$i][3]) {
      $results[$i][3]=$jtally; # This is $i's worst defeat/Closest victory.
    }
    if ($itally > $results[$j][3]) {
      $results[$j][3]=$itally; # This is $j's worst defeat/Closest victory.
    }
  }
}


# This is the loop where the winner is calculated.  The winner is
# stored in an array to deal with the possibility of a tie, in which
# the array grows to accomodate multiple "winners".  God help us if
# there is a tie.
my @leading_cand_num=();


{
  my $min_worst_defeat = $total_vote;
  for my $i (1 .. $candidates) {
    if ($results[$i][3]<$min_worst_defeat) {
      # $i is now the hands-down winner, so far
      $min_worst_defeat=$results[$i][3];
      @leading_cand_num=($i);
    } elsif ($results[$i][3]==$min_worst_defeat) {
      # $i is tied for the lead with those already in
      # the@leading_cand_num array
      push(@leading_cand_num, $i); 
    }
    if ($results[$i][0]==0 && $results[$i][1]==0)      {
      # If they haven't lost or tied any elections, they win.
      @leading_cand_num=($i);
      #print "\n$Candidates[$i] is the winner.\n\n";
      last;			# That's all she wrote.
    }
  }
}

# Well, trying to do a pretty print out
my $required_width = 0;
my @padding;

for (@Candidates) {
  $required_width = length($_) if length($_) > $required_width;
}

for my $i (1 .. $#Candidates ) {
  $padding[$i] = $required_width - length "$Candidates[$i]";
}


# Now for the moment we've been waiting for.  This is where we
# announce the winner(s)
if ($#leading_cand_num==0)
  {
    # i.e. if there is only one leading_cand_num, they win
    print"\nThe Winner is $Candidates[$leading_cand_num[0]]\n\n";
  } else			# Oh, hell...
  {
    print"There has been a tie\nThe winners are:\n";
    for (my $i=0;$i<=$#leading_cand_num;$i++) {
      print"\t $Candidates[$leading_cand_num[$i]]\n";
    }
    print"\n";
  }

print "Total votes tallied: $total_vote\n\n";

print "Pairwise elections won-lost-tied:\n";

for my $i (1 .. $candidates) {
  if (!defined($results[$i][0])) {
    $results[$i][0]=0;
  }
  if (!defined($results[$i][1])) {
    $results[$i][1]=0;
  }
  if (!defined($results[$i][2])) {
    $results[$i][2]=0;
  }
  print "$Candidates[$i] ", " " x $padding[$i], 
    "$results[$i][2]-$results[$i][0]-$results[$i][1]";
  print " (votes against in worst defeat/closest victory: ";
  print "$results[$i][3])\n";
}

# Print out the raw tally table.
print "\n\n";
print "=" x 70, "\n";
print " " x 25, "The raw tally table\n\n";
print "In this table, tally[row x][col y] represents the votes that \n";
print "candidate x received over candidate y. \n\n";
print "\t|", "-" x 40, "\n";
print "\t|   |";
for my $i (1 .. $candidates) {
  print "\t$i";
}
print "\t|\n";
print "\t|", "-" x 40, "\n";

for my $i (1 .. $candidates) {
  print "\t| $i | ";
  for my $j (1 .. $candidates) {
    print"\t$tally[$i][$j]";
  }
  print "\t|\n";
}
print "\n";
print "Looking at row 2, column 1, Candidate 2 ($Candidates[2]) \n";
print "recieved $tally[2][1] votes over Candidate 1($Candidates[1])\n\n";
print "Looking at row 1, column 2, Candidate 1 ($Candidates[1])\n";
print "recieved $tally[1][2] votes over Candidate 2 ($Candidates[2]).\n\n";
print "=" x 70, "\n";

# End of raw tally table printout.






