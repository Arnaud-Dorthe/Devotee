#!/usr/bin/perl -w

# Copyright (c) 2001, 2002 Anthony Towns <ajt@debian.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;

# Give detailed processing information and calculate the winner according
# to Cloneproof SSD.

####
# Parse input
#
# On <>, expect the processed votes, of the form:
#    V: -324-1    SOMESTUFF
# interpreted as rating the 6th option as your 1st preference, etc
# Assumes options 2, 3, 4 and 6 are all preferred over options 1 and
# 5, but no preference is given between options 1 and 5 

my %beats;		  # Votes preferring A to B == $beats{"$a $b"}
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

while (my $line = <>) {
  chomp $line;
  next unless ($line =~ m/^V:\s+(\S+)\s+\S+$/);
  my $vote = $1;
  $candidates = length($vote) unless ($candidates >= length($vote));
  for my $l (1..($candidates-1)) {
    for my $r (($l+1)..$candidates) {
      unless (defined $beats{"$l $r"}) {
	$beats{"$l $r"} = 0;
	$beats{"$r $l"} = 0;
      }

      my $L = substr($vote, $l-1, 1);
      my $R = substr($vote, $r-1, 1);

      if ($L eq "-" && $R eq "-") {
	next;
      } elsif ($R eq "-" || ($L ne "-" && $L < $R)) {
	$beats{"$l $r"}++;
      } elsif ($L eq "-" || $R < $L) {
	$beats{"$r $l"}++;
      } else {
				# equally ranked, tsk tsk
      }
    }
  }
}

####
# Determine defeats, based on how many votes ranked some candidate above
# another candidate.

my %defeat = ();

# Purely for aesthetic reasons
my @pairwise = ();
# Initialize the @pairwise array.
for my $i (1 .. $candidates) {
  $pairwise[$i][0]=0;            # Number of victories for $i
  $pairwise[$i][1]=0;            # Number of ties for $i
  $pairwise[$i][2]=0;            # Number of defeats for $i
  $pairwise[$i][3]=0;            # Worst defeat, as measured by
  # total votes against $i
}


print "\t\tCalculating ....\n";
for my $l (1..$candidates) {
  for my $r (1..$candidates) {
    next if ($l == $r);

    my $LR = $beats{"$l $r"};
    my $RL = $beats{"$r $l"};
    if ($LR > $RL) {
      $defeat{"$l $r"} = "$LR $RL";
    } elsif ($l < $r && $LR == $RL) {
      print "Exact tie between $l and $r : $LR $RL\n";
    }
  }
}
print "\n";

for my $l (1..($candidates-1)) {
  for my $r (($l+1)..$candidates) {
    next if ($l == $r);
    my $ltally = $beats{"$l $r"};
    my $rtally = $beats{"$r $l"};
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
    my $x =($ltally <=> $rtally)+1;
    my $y =2-$x;
    $pairwise[$l][$x]++;
    $pairwise[$r][$y]++;

    if ($rtally > $pairwise[$l][3]) {
      $pairwise[$l][3]=$rtally; # This is $i's worst defeat/Closest victory.
    }
    if ($ltally > $pairwise[$r][3]) {
      $pairwise[$r][3]=$ltally; # This is $j's worst defeat/Closest victory.
    }
  }
}


####
# Determine the winner according to Cloneproof SSD.
#
#     1. Calculate Schwartz set according to uneliminated defeats.
#     2. If there are no defeats amongst the Schwartz set:
#	    2a. If there is only one member in the Schwartz set, it wins.
#           2b. Otherwise, there is a tie amongst the Schwatz set.
#           2c. End
#     3. If there are defeats amongst the Schwartz set:
#           3a. Eliminate the weakest defeat/s.
#           3b. Repeat, beginning at 1.

my $phase = 0;
while (1) {
  $phase++;
  print "_" x 70, "\n\n";
  print "Defeats at beginning of phase $phase:\n";
  for my $d (sort keys %defeat) {
    my ($l, $r) = split /\s+/, $d;
    my ($x, $y) = split /\s+/, $defeat{$d};
    print "    $l beats $r: $defeat{$d}\t= ", $x - $y, "\n";
  }

  my @schwartz = calculate_schwartz();
  print "\nSchwartz set: " . join(",", map {$Candidates[$_]} @schwartz) . "\n";

  my @schwartzdefeats = 
    grep { defined $defeat{$_} } crossproduct(@schwartz);

  if (!@schwartzdefeats) {
    print "\nNo defeats left in Schwartz set!\n";
    print "=" x 70, "\n\n";
    if (@schwartz == 1) {
      print "Winner is: $Candidates[$schwartz[0]]\n";
    } else {
      print "Tie amongst: " . join(", ", map {$Candidates[$_]} @schwartz)
	. "\n";
    }
    print "\n\n";
    last;
  }

  my $weakest = (sort { defeatcmp($defeat{$a},$defeat{$b}) }
		 @schwartzdefeats)[0];

  my $weakstrength = $defeat{$weakest};
  print "Weakest defeat amongst schwartz set is $weakstrength\n";

  for my $d (@schwartzdefeats) {
    die "Defeat weaker than weakest! $d, $weakstrength, $defeat{$d}" 
      if (defeatcmp($defeat{$d}, $weakstrength) < 0);
    if (defeatcmp($defeat{$d}, $weakstrength) == 0) {
      print "Removing defeat $d, $defeat{$d}\n";
      delete $defeat{$d};
    }
  }
  print "\n";
  print "_" x 70, "\n\n";
}

print "=" x 70, "\n";
print "\nPairwise elections won-lost-tied:\n";
# Well, trying to do a pretty print out
my $required_width = 0;
my @padding;

for (@Candidates) {
  $required_width = length($_) if length($_) > $required_width;
}

for my $i (1 .. $#Candidates ) {
  $padding[$i] = $required_width - length "$Candidates[$i]";
}

for my $i (1 .. $candidates) {
  if (!defined($pairwise[$i][0])) {
    $pairwise[$i][0]=0;
  }
  if (!defined($pairwise[$i][1])) {
    $pairwise[$i][1]=0;
  }
  if (!defined($pairwise[$i][2])) {
    $pairwise[$i][2]=0;
  }
  print "$Candidates[$i] ", " " x $padding[$i], 
    "$pairwise[$i][2]-$pairwise[$i][0]-$pairwise[$i][1]";
  print " (votes against in worst defeat/closest victory: ";
  print "$pairwise[$i][3])\n";
}

# Print out the raw tally table.
print "\n\n";
print "_" x 70, "\n";
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
    print "\t";
    print $beats{"$i $j"} if defined $beats{"$i $j"};
  }
  print "\t|\n";
}
print "\n";
print "Looking at row 2, column 1, Candidate 2 ($Candidates[2]) \n";
print "recieved ", $beats{"2 1"}, 
  " votes over Candidate 1 ($Candidates[1])\n\n";
print "Looking at row 1, column 2, Candidate 1 ($Candidates[1])\n";
print "recieved ", $beats{"1 2"}, 
  " votes over Candidate 2 ($Candidates[2]).\n\n";
print "=" x 70, "\n";

# End of raw tally table printout.


sub crossproduct {
  my @l = @_;
  return map { my $k = $_; map { "$k $_" } @l } @l;
}

sub defeatcmp {
  my ($Awin, $Alose) = split /\s+/, shift;
  my ($Bwin, $Blose) = split /\s+/, shift;

  return 1 if ($Awin > $Bwin);
  return -1 if ($Awin < $Bwin);
  return 1 if ($Alose < $Blose);
  return -1 if ($Alose > $Blose);

  return 0;
}

####
# Code to calculate the schwartz set
#
# We note that given two unbeaten subsets, S and T, either, then S^T is
# also unbeaten, so either S^T is empty, or S^T is a smaller unbeaten subset.
#
# We can thus find a unique, smallest unbeaten set containing each candidate
# by a simple iterative method. This is find_unbeaten_superset.
#
# So given the smallest supersets for each candidate, we have all the smallest
# unbeaten subsets (since each one will be the smallest superset of any of
# its members). So, each set is either a proper superset of another set
# (and can thus be discarded), or it's a smallest unbeaten subset.
#
# We eliminate the sets in and then union the remainder (which are either
# equal or disjoint), and we've thus found the Schwartz set. This is 
# done in calculate_schwartz.

sub find_unbeaten_superset {
  my @l = @_;
  for my $r (1..$candidates) {
    my $add = 1;
    for my $l (@l) {
      if ($l == $r) {
	$add = 0;
	next;
      }
    }
    next unless ($add);
    $add = 0;
    for my $l (@l) {
      if (defined $defeat{"$r $l"}) {
	$add = 1;
      }
    }
    if ($add) {
      return find_unbeaten_superset(@l, $r);
    }
  }
  return sort(@l);
}


sub is_subset {
  my @l = @{$_[0]};
  my @r = @{$_[1]};

  for my $x (@r) {
    last if (!@l);
    shift @l if ($l[0] == $x);
  }

  return !@l;
}


sub calculate_schwartz {
  my @schwartz = ();
  for my $k (1..$candidates) {
    my @us = find_unbeaten_superset($k);
    my $new = 1;
    for my $x (@schwartz) {
      if (is_subset($x, \@us)) {
	$new = 0;
      } elsif (is_subset(\@us, $x)) {
	$x = \@us;
	$new = 0;
      }
    }
    if ($new) {
      push @schwartz, \@us;
    }
    #print "$k : " . join(",", @us) . "\n";
    #print "schwartz : " . join(":", map { join(",", @{$_}) } @schwartz) . "\n";
  }
  my @result = ();
  for my $x (@schwartz) {
    if (!is_subset($x, \@result)) {
      @result = sort(@result, @{$x});
    }
  }
  return @result;
}
