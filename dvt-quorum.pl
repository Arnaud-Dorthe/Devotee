#                              -*- Mode: Cperl -*- 
# dvt-quorum.pl --- 
# Author           : Manoj Srivastava ( srivasta@glaurung.green-gryphon.com ) 
# Created On       : Thu Mar 13 18:07:30 2003
# Created On Node  : glaurung.green-gryphon.com
# Last Modified By : Manoj Srivastava
# Last Modified On : Sat Jun  7 02:30:14 2003
# Last Machine Used: glaurung.green-gryphon.com
# Update Count     : 22
# Status           : Unknown, Use with caution!
# HISTORY          : 
# Description      : 
# 
# 


#gpg --fast-list-mode --no-options --no-default-keyring \
#    --keyring ./debian-keyring.pgp --keyring ./debian-keyring.gpg \
#    --fingerprint --with-colons | grep ^fpr | cut -d: -f10 > ~/allkeys
#ldapsearch -LLLxP2  -h db.debian.org -b dc=debian,dc=org  uid keyfingerprint > ldapids
#ldapsearch -LLLxP2  -h db.debian.org -b dc=debian,dc=org '(gidnumber=800)' uid 
#ldapsearch -LLLxP2  -h db.debian.org -b dc=debian,dc=org '(objectclass=debiandeveloper)' uid 

if (! -e "allkeys") {
  system 'gpg --fast-list-mode --no-options --no-default-keyring --keyring ./debian-keyring.pgp --keyring ./debian-keyring.gpg  --fingerprint --with-colons | grep ^fpr | cut -d: -f10 > allkeys';
}

if (! -e "ldapids") {
  system 'ldapsearch -LLLxP2  -h db.debian.org -b dc=debian,dc=org  uid keyfingerprint > ldapids';
}



my $Seen;

open(FINGERPRINTS, "allkeys") || die "Could not open allkeys: $!";
while (<FINGERPRINTS>) {
  chomp;
  $Seen{$_}++;
}
close FINGERPRINTS;

open(LDAP, "ldapids") || die "Could not open ldapids: $!";
{
  local $/="";
  while (<LDAP>) {
    my ($uid, @fingerprints);
    ($uid) = m/^uid: (\S+)/sm;
    next unless $uid;
    @fingerprints= m/^keyfingerprint: (\S+)/gsm;
    next unless @fingerprints;
    for (@fingerprints) {
      if ($Seen{$_}) {
	$found{$uid}++;
      }
    }
  }
}

for (sort keys %found) {
  print "$found{$_} $_ \n";
}

my $total =  keys %found;
print "Total = $total\n";
