#!/usr/bin/perl -w
#                              -*- Mode: Perl -*-
# Devotee.pm ---
# Author           : Manoj Srivastava ( srivasta@glaurung.green-gryphon.com )
# Created On       : Thu Apr 18 21:22:35 2002
# Created On Node  : glaurung.green-gryphon.com
# Last Modified By : Manoj Srivastava
# Last Modified On : Tue Oct 31 11:47:49 2006
# Last Machine Used: glaurung.internal.golden-gryphon.com
# Update Count     : 252
# Status           : Unknown, Use with caution!
# HISTORY          :
# Description      :
#
# arch-tag: 2e4c8af4-ff80-4d69-8943-5f613af3edbe
#
# Copyright (c) 2002 Manoj Srivastava <srivasta@debian.org>
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
#

require 5.002;

($main::MYNAME     = $main::0) =~ s|.*/||;
$main::Author      = "Manoj Srivastava";
$main::AuthorMail  = "srivasta\@debian.org";
$main::Version     = '1.00';


package Devotee;
$VERSION = "0.1";
my $file = __FILE__;

use strict;
require 5.001;
use Carp;
use Parse::RecDescent;
use Fcntl ':flock'; # import LOCK_* constants
use Data::Dumper;

$::RD_ERRORS=1;
$::RD_WARN  =1;
$::RD_HINT  =1;


=head1 NAME

Devotee - The common parts of the DEbian VOTe EnginE

=head1 SYNOPSIS

use Devotee;
use Getopt::Long;

my $optdesc = Devotee->Optdesc();
GetOptions (%$optdesc);
my $dvt = Devotee->new(%::ConfOpts);
$dvt->validate(%::ConfOpts) unless
  defined $::ConfOpts{'Config File'} && -r $::ConfOpts{'Config File'};
my $confref = $dvt->get_config_ref();
$dvt->lock_vote_dir();
 ...
$dvt->unlock_vote_dir();

=head1 DESCRIPTION

This package handles the details of configuration and serialization of
the vote scripts. It also contains the getopt string for the common
options recognized by the framework, the grammar for the configuration
file, and the default values for a number of parameters affecting the
engine.

=head1 OPTIONS

=over 3

=item B<--help> Print out a usage message.


=item B<--config_file> file

=over 2

Set the file from which the configuratiopn data for this vote is to be
read from.  The file contains simple Name = Value pairs, and may
contain comments starting with the '#' character and going to the end
of that line. See below for a list of known configuratiopn variables.
Please note that the configuration file is not limited to setting
these known variables only, but can extend the list for use in
individual scripts.

=back

=item B<--top_dir> dir

=over 2

This specifies the top directory under which data for the vote shall be
gathered. This directory shall contain the subdirs used by the engine
(unless specifically overridden), contain the common lock file, and
the replay and alias databases. The default for this is the users home
directory.

=back


=item B<--force>

=item B<--noforce>

=item B<-f>

=over 2

Normally, most B<Devotee> scripts run incrementally, and thus only
process new and previously unprocessed ballots.  The B<Force>
directive, set by B<--force> or B<-f>, and unset by B<--noforce>,
directs the scripts to redo the work even though the ballot in
question had been processed already, over writing previously created
output.  The default is B<OFF>.

=back

=item B<--final_tally>

=over 2

Set when you need the final tally sheet for a secret ballot. Without
this option, the tally sheet generated for a secret ballot shall be
obfuscated. Has no affect on non secret votes.

=back

=item B<--secret> 

=item B<--nosecret> 

=item B<-s>

=over 2

Set whether this vote requires secret ballots or not.  In a secret
Ballot, we create an alias database to create random monikers for each
voter, and the final tally sheet has the MD5SUM of the ID of each
voter and the secret moniker. This way, each voter may validate that
their vote exists on the tally sheet, but maintains the secrecy of the
vote. This directive is set by B<--secret> or B<-s>, and negated by
B<--nosecret>. The default is B<OFF>.

=back


=item B<--mkdir> 

=item B<--nomkdir> 

=item B<-m>

=over 2

The various scripts that comprise the vote engine save intermediate
steps in various subdirectories, and these subdirs are used to hold
and communicate data between the scripts and subsequent invocations.
If the user has not specified any of the sub directories explicitly,
or if the specified directories do not exist, setting the mkdir flag
shall instruct the vote engine to create missing subdiretories under
the Top Directory. Please note that the directories are created under
the Top Directory, regardless of the specified location. (negate with
--nomkdir). Default is B<OFF>.

=back



=item B<--need_gpg>

=over 2

Specifying this flag implies that this vote will be checked against a
GPG keyring.  Failure to find the GPG keyring is a fatal error.
(negate with --noneed_gpg). Default is B<ON>.


=back


=item B<--need_pgp>

=over 2

Specifying this flag implies that this vote will be checked against a
PGP keyring.  Failure to find the PGP keyring is a fatal error.
(negate with --noneed_pgp). Default is B<ON>.


=back


=item B<--need_ldap>

=over 2

Specifying this flag implies that this vote will be checked against a
LDAP database (negate with --noneed_ldap). Default is B<ON>.


=back

=item B<--sign_ack>

=over 2

Specifying this flag implies that acknowledgements of votes sent to
voters shall be signed as well as encrypted (negate with
--nosign_ack). Default is B<ON>. Failure to find the secret keyring
shall be fatal.


=back



=item B<--gpg_ring>  KEYRING

=over 2

Specify the GPG public keyring to use to validate votes


=back


=item B<--pgp_ring>  KEYRING

=over 2

Specify the PGP public keyring to use to validate votes

=back


=item B<--sec_ring>  KEYRING

=over 2

Specify the secret keyring to use to sign acks

=back


=item B<--ldap_host> HOST

=over 2

Specify the LDAP host to contact to validate votes

=back


=item B<--ldap_base> BASESTR

=over 2

Specify the base for the LDAP query

=back

=item B<--quorum_out> FILE

=over 2

Specify the file name where calculated quorum shall be kept. The file
contains the number of developers, and the value of the variable Q and
K, as defined in the Debian constitution.

=back

=item B<--quorum_err> FILE

=over 2

Specify the file name where information of missing keys is kept

=back

=item B<--quorum_detail> FILE

=over 2

Specify the file name for developers uids and fingerprints

=back

=item B<--tally_file>  FILE

=over 2

Specify the file name for the tally sheet

=back

=item B<--tally_dummy> FILE

=over 2

Specify the file name for the dummy tally sheet

=back

=item B<--voters_file> FILE

=over 2

Specify the file name for the list of people who have voted


=back

=item B<--results> FILE

=over 2

Specify the file name where the results should be put

=back

=back

=cut

{  # scope for ultra-private meta-object for class attributes
  my %Devotee =
    (
     Grammar  => q(
 { my %Config; }
 Config     : component(s) /\Z/  { $return = \%Config;  }
 component  : definition(s /;/)  { $return = "";        }
            | comment            { $return = "";        }
            | <error>
 comment    : /#[^\n]*/          { $return = "";        }
 definition : lvalue comment(s?) '=' comment(s?) value
                                 { chomp($Config{$item[1]} = $item{value});
                                   $return = "";        }
            | comment            { $return = "";        }
 lvalue     : /\w[a-z0-9_]*/i    { $return = $item[1]; }
 value      : /[^;#]+/           { $return = $item[1]; }
),
     Optdesc  => {
		  'config_file=s'=> sub {$::ConfOpts{"Config_File"}= "$_[1]";},
		  'force!'       => sub {$::ConfOpts{"Force"}      = "$_[1]";},
		  'f'            => sub {$::ConfOpts{"Force"}      = "$_[1]";},
		  'final_tally'  => sub {$::ConfOpts{"Final_Tally"}= "$_[1]";},
		  'gpg_ring=s'   => sub {$::ConfOpts{"GPG_Keyring"}= "$_[1]";},
		  'help'         => sub {print Devotee->Usage();      exit 0;},
		  'html_result=s'=> sub {$::ConfOpts{"HTML_Result"}= "$_[1]";},
		  'ldap_base=s'  => sub {$::ConfOpts{"Ldap_Base"}  = "$_[1]";},
		  'ldap_host=s'  => sub {$::ConfOpts{"Ldap_Host"}  = "$_[1]";},
		  'ldap_filter=s'=> sub {$::ConfOpts{"Ldap_Filter"}= "$_[1]";},
		  'mkdir!'       => sub {$::ConfOpts{"Create_Dirs"}= "$_[1]";},
		  'm'            => sub {$::ConfOpts{"Create_Dirs"}= "$_[1]";},
		  'need_gpg!'    => sub {$::ConfOpts{"Need_GPG"}   = "$_[1]";},
		  'need_ldap!'   => sub {$::ConfOpts{"Need_LDAP"}  = "$_[1]";},
		  'need_pgp!'    => sub {$::ConfOpts{"Need_PGP"}   = "$_[1]";},
		  'sign_ack!'    => sub {$::ConfOpts{"Sign_Ack"}   = "$_[1]";},
		  'pgp_ring=s'   => sub {$::ConfOpts{"PGP_Keyring"}= "$_[1]";},
		  'pub_ring=s'   => sub {$::ConfOpts{"PUB_Keyring"}= "$_[1]";},
		  'sec_ring=s'   => sub {$::ConfOpts{"SEC_Keyring"}= "$_[1]";},
		  'password=s'   => sub {$::ConfOpts{"Pass_Word"}  = "$_[1]";},
		  'secret!'      => sub {$::ConfOpts{"Secret"}     = "$_[1]";},
		  's'            => sub {$::ConfOpts{"Secret"}     = "$_[1]";},
		  'tally_file=s' => sub {$::ConfOpts{"Tally_File"} = "$_[1]";},
		  'tally_dummy=s'=> sub {$::ConfOpts{"Tally_Dummy"}= "$_[1]";},
		  'top_dir=s'    => sub {$::ConfOpts{"Top_Dir"}    = "$_[1]";},
		  'quorum_out=s' => sub {$::ConfOpts{"Quorum_File"}= "$_[1]";},
		  'quorum_detail=s' => sub {$::ConfOpts{"Quorum_Details"}= "$_[1]";},
		  'quorum_err=s' => sub {$::ConfOpts{"Quorum_Error"}= "$_[1]";},
		  'voters_file=s'=> sub {$::ConfOpts{"Voters_File"} = "$_[1]";},
		  'results=s'    => sub {$::ConfOpts{"Results"}     = "$_[1]";},
		  'graph=s'      => sub {$::ConfOpts{"Graph"}       = "$_[1]";},
		 },
     Usage    => qq(Usage: $main::MYNAME [options]
Author: $main::Author <$main::AuthorMail>
Version $main::Version
  where options are:
 --help                This message.
 --config_file <FILE>  The file to read configuration data from 
 --top_dir     <DIR>   The top level directory where data for the vote 
                       shall be kept 
 --force  | -f         Force over writing previously created output. Generally
                       most Devotee scripts work incrementally, only
                       processing new ballots. (negate with --noforce)
 --final_tally         Used to create a non obfuscated tally sheet for a secret ballot.
 --secret | -s         Make this vote is a secret ballot (--nosecret negates)
 --mkdir  | -m         Create missing subdiretories under the Top Directory
                       (negate with --nomkdir)
 --need_gpg            This vote will be checked against a GPG keyring (negate
                       with --noneed_gpg)
 --need_pgp            This vote will be checked against a PGP keyring (negate
                       with --noneed_pgp)
 --need_ldap           This vote shall be checked against a LDAP database
                       (negate with --noneed_ldap)
 --sign_ack            Acknowledgements shall be signed (negate with 
                       --nosign_ack)
 --gpg_ring  <KEYRING> Specify the GPG public keyring to use to validate votes
 --pgp_ring  <KEYRING> Specify the PGP public keyring to use to validate votes
 --pub_ring  <KEYRING> Specify the public keyring that contains the vote key.
 --sec_ring  <KEYRING> Specify the private keyring to use to Ksign acks
 --password  <passwd>  Specify the pass phrase for the private keyring
 --ldap_host <HOST>    Specify the LDAP host to contact to validate votes
 --ldap_base <BASESTR> Specify the base for the LDAP query
 --ldap_base <FILTER>  Specify the filter ot use for checking with LDAP
 --quorum_out <FILE>   Specify the file name where calculated quorum shall be kept
 --quorum_err <FILE>   Specify the file name where information of missing keys is kept
 --quorum_detail <FILE>Specify the file name for developers uids and fingerprints
 --tally_file  <FILE>  Specify the file name for the tally sheet
 --tally_dummy <FILE>  Specify the file name for the dummy tally sheet
 --voters_file <FILE>  Specify the file name for the list of people who have voted
 --results     <FILE>  Specify the file name where the results should be put
),
     Defaults => {
                  "Body_Suffix"      => 'body',
                  "Common_Lock"      => 'lock',
                  "Create_Dirs"      => 0,
                  "Dir_Mask"         => 0770,
                  "File_Mask"        => 0660,
                  "Force"            => 0,
                  "Info_Suffix"      => 'info',
                  "Ldap_Base"        => "dc=debian,dc=org",
                  "Ldap_Host"        => "db.debian.org",
                  "Ldap_Filter"      => "(gidnumber=800)",
                  "Lock_Suffix"      => 'lock',
		  "Max_Choices"      => 0,
		  "Msg_Preffix"      => 'msg',
		  "Msg_Suffix"       => 'raw',
		  "Secret"           => 1,
		  "Encrypted_Ack"    => 1,
                  "Vote_Taker_Name"  => "Debian Project Secretary",
                  "Vote_Taker_EMAIL" => "secretary\@debian.org",
                  "My_Email"         => "devotee\@vote.debian.org",
                  "Publish_To"       => "debian-vote\@lists.debian.org",
                  "Publish_CC"       => "debian-devel\@lists.debian.org",
		  "Sig_Suffix"       => 'sig',
                  "Encrypted_Suffix" => 'gpg',
                  "UUID"             => "",
		  "Need_GPG"         => 1,
		  "Need_PGP"         => 1,
		  "Need_LDAP"        => 1,
		  "Sign_Ack"         => 1,
		  "Vote_Ref"         => "vote_001",
		  "Vote_Name"        => "gr_fixme",
		  "Option_1"         => "None of the Above",
		  "Option_2"         => "",
		  "Option_3"         => "",
		  "Option_4"         => "",
		  "Option_5"         => "",
		  "Option_6"         => "",
		  "Option_7"         => "",
		  "Option_8"         => "",
		  "Option_9"         => "",
		  "Majority_1"       => "1",
		  "Majority_2"       => "1",
		  "Majority_3"       => "1",
		  "Majority_4"       => "1",
		  "Majority_5"       => "1",
		  "Majority_6"       => "1",
		  "Majority_7"       => "1",
		  "Majority_8"       => "1",
		  "Majority_9"       => "1",
		 },
     Files   => {
		  "Alias_DB"       => "AliasDB",   # Only needed if secret
		  "Replay_DB"      => "ReplayDB",  # only if need gpg or need pgp
		  "Quorum_File"    => "quorum.txt",# Where the quorum is written to
		  "Quorum_Details" => "quorum.log",# developers and fingerprints
		  "Quorum_Error"   => "quorum.err",# missing keys
		  "Tally_File"     => "tally.txt", # tally sheet 
		  "Tally_Dummy"    => "dummy_tally.txt", # dummy tally sheet 
		  "Voters_File"    => "voters.txt", # List of people who have voted
		  "HTML_Result"    => "results.src",
		  "HTML_Quorum"    => "quorum.src",
		  "HTML_Majority"  => "majority.src",
		  "Results"        => "results.txt",
		  "Graph"          => "results.dot",
		},
     SubDirs => {
		 "Ack_Dir"      => "ack",
		 "Ballot_Dir"   => "ballot", # Not needed
		 "Body_Dir"     => "body",
		 "Check_Dir"    => "check",
		 "Content_Dir"  => "content", # Not needed
		 "LDAP_Dir"     => "ldap",
		 "Log_Dir"      => "log",
		 "Nack_Dir"     => "nack",
		 "Sig_Dir"      => "sig",
		 "Spool_Dir"    => "spool",
		 "Tally_Dir"    => "tally",
		 "Temp_Dir"     => "tmp",
                 "Time_Line"    => "timeline",
		 "Work_Dir"     => "work",
		},
    );

  # tri-natured: function, class method, or object method
  sub _classobj {
    my $obclass = shift || __PACKAGE__;
    my $class   = ref($obclass) || $obclass;
    no strict "refs";   # to convert sym ref to real one
    return \%$class;
  }

  for my $datum (keys %Devotee ) {
    no strict "refs";
    *$datum = sub {
      use strict "refs";
      my ($self, $newvalue) = @_;
      $Devotee{$datum} = $newvalue if @_ > 1;
      return $Devotee{$datum};
    }
  }
}


=head1 CLASS METHODS

All class methods mediate access to class variables.  All class
methods can be invoked with zero or one parameters. When invoked with
the optional parameter, the class method sets the value of the
underlying class data.  In either case, the value of the underlying
variable is returned.

=cut

=head2 Grammar


=head2 Optdesc

=head2 Usage

=head2 Defaults

=head2 Files

=head2 Subdirs

=cut

=head1 INSTANCE METHODS

=cut

=head2 new

This is the constructor for the class. It takes a number of optional
parameters. If the parameter B<Config_File> is present, then the
configuration file is read, and the parameters provided override the
values in the configuration file. If there is no parameter
B<Config_File>, then the parameter list is ignored, and the
initialization of the object is deferred.

=cut

sub new {
  my $this = shift;
  my %params = @_;
  my $class = ref($this) || $this;
  my $self = {};
  my $dotdir = $ENV{HOME} || $ENV{LOGNAME} || (getpwuid($>))[7] ;

  croak ("Home directory does not exist") unless -d $dotdir;

  bless $self => $class;

  $self->{Dot_Dir}= $dotdir;

  # If we are passed a configuration file, read it immediately and validate
  if ($params{'Config_File'}) {
    $self->read_config(%params);
  }
  return $self;
}

=head2 read_config

This routine attempts to find a configuration file, and parses and
stashes the results if succesfull. It calls the validate method to set
the defaults and validate the settings.

=cut

sub read_config {
  my $this = shift;
  my %params = @_;
  my $config_file;

  # Try and determine the location of the configuration file.
  if (defined $params{'Config_File'} && -r $params{'Config_File'} ) {
    $config_file = $params{'Config_File'};
  }  elsif (-r $this->{Dot_Dir} . "/.dvtrc") {
    $config_file = $this->{Dot_Dir} . "/.dvtrc";
  }  elsif (-r '/etc/dvt.conf') {
    $config_file = '/etc/dvt.conf';
  } else {
    carp("Missing required paramater 'Config File'");
  }

  # If the file is readable, we read and parse it
  if (-r $config_file) {
    open(CONF, $config_file) ||
      croak ("Could not open Config file $config_file");
    undef $/;
    my $text = <CONF>;
    $/="\n";
    close CONF;

    my $parser = Parse::RecDescent->new($this->Grammar());
    $this->{Con_Ref} = $parser->Config($text);
  }

  # In anycase, validate and sanitize the settings
  $this->validate(%params);
  return $this->{Con_Ref};
}

=head2 validate

This routine is responsible for ensuring that the parameters passed in
(presumably from the command line) are given preference. It then does a
sanity check over the setting, including ensuring that the directories
required are present. Note that we only create the directories if
asked to do so, and then again we only create them under the specified
top level directory Top_Dir. If the seting says we need pgp or gpg, or
both, we try and determine the location of the public keyrings that we
may use.

=cut

sub validate{
  my $this     = shift;
  my %params   = @_;
  my $subdirs  = $this->SubDirs();
  my $defaults = $this->Defaults();
  my $files    = $this->Files();

  # Make sure runtime options override what we get from the config file
  for my $option (keys %params) {
    $this->{Con_Ref}->{"$option"} = $params{"$option"};
  }

  # Make sure we have a top level directory
  my $topdir = $this->{Con_Ref}->{"Top_Dir"};
  if (defined  $topdir && $topdir && -d $topdir) {
    # nop
  } else {
    $topdir = $this->{Dot_Dir};
    $this->{Con_Ref}->{"Top_Dir"} = $topdir;
  }

  # Ensure that if default parameters have not been set on the comman
  # line on in the configuration file, if any, we use the built in
  # defaults.
  for my $default (keys %$defaults) {
    if (! defined $this->{Con_Ref}->{"$default"}) {
      $this->{Con_Ref}->{"$default"} = $defaults->{"$default"};
    }
  }

  # Make sure that various subdirectories are present, giving
  # preference to anything explicitly set by the user
  for my $dir (keys %$subdirs) {
    if (!(defined $this->{Con_Ref}->{"$dir"} && 
	  -d $this->{Con_Ref}->{"$dir"})) {
      # either the user did not specify a dir, or it does not exist
      $this->{Con_Ref}->{"$dir"} = "$topdir/" . $subdirs->{"$dir"};
      if (! -d $this->{Con_Ref}->{"$dir"}) {
	# Hmm. Directory does not exist
	if ($this->{Con_Ref}->{"Create_Dirs"}) {
	  # But we may create it
	  mkdir $this->{Con_Ref}->{"$dir"}, $this->{Con_Ref}->{"Dir_Mask"} ||
	    croak "Could not create dir $this->{Con_Ref}->{$dir}:$!";
	} else {
	  # Ah well.
	  croak "The directory \"$dir\" (", $this->{Con_Ref}->{"$dir"},
	    ") does not exist";
	}
      }
    }
  }

  # Set the names of a few files, which perhaps shall be needed;
  # unless explicitly set by the user.
  for my $file (keys %$files) {
    if (! defined $this->{Con_Ref}->{"$file"}) {
      $this->{Con_Ref}->{"$file"} = "$topdir/" . $files->{"$file"};
    }
  }

  # If we need GPG, give special treatment to the location of the keyring.
  if ($this->{Con_Ref}->{'Need_GPG'}) {
    if (! (defined $this->{Con_Ref}->{'GPG_Keyring'} && 
	   -r $this->{Con_Ref}->{'GPG_Keyring'})) {
      # The user has not specified a location
      if (-r "$topdir/debian-keyring.gpg") {
	# But, one exists in the logical place
	$this->{Con_Ref}->{'GPG_Keyring'} = "$topdir/debian-keyring.gpg";
      }
      elsif (-r "/org/keyring.debian.org/keyrings/debian-keyring.gpg") {
	# Oh well, the debian origins are showing
	$this->{Con_Ref}->{'GPG_Keyring'} = 
	  "/org/keyring.debian.org/keyrings/debian-keyring.gpg"
	}
      else {
	# since we need the keyring, but we can't find any
	croak "Could not find gpg ring: no default, and not found in " .
	  "$topdir/debian-keyring.gpg or in " .
	    "/org/keyring.debian.org/keyrings/debian-keyring.gpg";
      }
    }
  }

  # If we need PGP, give special treatment to the location of the keyring.
  if ($this->{Con_Ref}->{'Need_PGP'}) {
    if (! (defined $this->{Con_Ref}->{'PGP_Keyring'} && 
	   -r $this->{Con_Ref}->{'PGP_Keyring'})) {
      # The user has not specified a location
      if (-r "$topdir/debian-keyring.pgp") {
	# But, one exists in the logical place
	$this->{Con_Ref}->{'PGP_Keyring'} = "$topdir/debian-keyring.pgp";
      }
      elsif (-r "/org/keyring.debian.org/keyrings/debian-keyring.pgp") {
	# Oh well, the debian origins are showing
	$this->{Con_Ref}->{'PGP_Keyring'} = 
	  "/org/keyring.debian.org/keyrings/debian-keyring.pgp"
	}
      else {
	# since we need the keyring, but we can't find any
	croak "Could not find pgp ring: no default, and not found in " .
	  "$topdir/debian-keyring.pgp or in " .
	    "/org/keyring.debian.org/keyrings/debian-keyring.pgp";
      }
    }
  }

  # If we need to sign the acks, give special treatment to the
  # location of the keyring.
  if ($this->{Con_Ref}->{'Sign_Ack'}) {
    if (! (defined $this->{Con_Ref}->{'SEC_Keyring'} && 
	   -r $this->{Con_Ref}->{'SEC_Keyring'})) {
      # The user has not specified a location
      if (-r "$topdir/secring.gpg") {
	# But, one exists in the logical place
	$this->{Con_Ref}->{'SEC_Keyring'} = "$topdir/secring.gpg";
      }
      else {
	# since we need the keyring, but we can't find any
	croak "Could not find private key ring"
      }
    }

    if (! (defined $this->{Con_Ref}->{'PUB_Keyring'} && 
	   -r $this->{Con_Ref}->{'PUB_Keyring'})) {
      # The user has not specified a location
      if (-r "$topdir/pubring.gpg") {
	# But, one exists in the logical place
	$this->{Con_Ref}->{'PUB_Keyring'} = "$topdir/pubring.gpg";
      }
      else {
	# since we need the keyring, but we can't find any
	croak "Could not find public key ring"
      }
    }
  }
}

=head2 dump_config 

This routine returns a C<Data::Dumper> for debugging purposes

=cut

sub dump_config {
  my $this     = shift;
  return Data::Dumper->new([$this->{Con_Ref}]);
}

=head2 get_config_ref

This routine returns a reference to the configuration hash

=cut

sub get_config_ref {

  my $this     = shift;
  return $this->{Con_Ref};
}


=head2 lock_vote_dir

This routine is used to lock the vote directory, and ensure only one
process is running for the vote in question. Unlike the spooling
process, the rest of the voting scripts can be run in sequence, and
thus this simple lock ensures that we can continue without treading on
the toes of other voting scripts.

=cut

sub lock_vote_dir {
  my $this     = shift;
  my %params   = @_;
  my $lockfile = $this->{Con_Ref}->{"Top_Dir"} . "/" . 
    $this->{Con_Ref}->{"Common_Lock"};

  open (LOCK, ">$lockfile") ||  die "Could not lock common lockfile:$!";
  flock(LOCK, LOCK_EX);
}

=head2 unlock_vote_dir

This routine is the correpsonding unlock routine.

=cut

sub unlock_vote_dir {
  my $this     = shift;
  my %params   = @_;
  my $lockfile = $this->{Con_Ref}->{"Top_Dir"} . "/" . 
    $this->{Con_Ref}->{"Common_Lock"};


  open (LOCK, ">$lockfile") ||  die "Could not lock common lockfile:$!";
  flock(LOCK, LOCK_UN);
}

=head2 log_message

This routine logs a message into the Log dir

=cut

sub log_message {
  my $this    = shift;
  my $msg     = shift;
  my $message = shift;
  my $dolog   = 1;
  my $ret     = open(LOG, ">>$this->{Con_Ref}->{Log_Dir}/$msg");
  if (! $ret) {
    warn "Could not append to log file $this->{Con_Ref}->{Log_Dir}/$msg";
    $dolog = 0;
  }
  warn $message unless $dolog;
  $dolog && chmod $this->{"Con_Ref"}->{"File_Mask"}, "$this->{Con_Ref}->{Log_Dir}/$msg";
  $dolog && print LOG  $message;
  close(LOG);
}



=head1 CAVEATS

This is very inchoate, at the moment, and needs testing.

=cut

=head1 BUGS

None Known so far.

=cut

=head1 AUTHOR

Manoj Srivastava <srivasta@debian.org>

=head1 COPYRIGHT AND LICENSE

This script is a part of the Devotee package, and is 

Copyright (c) 2002 Manoj Srivastava <srivasta@debian.org>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=cut

{ # Execute simple test if run as a script
  package main; no strict;
  eval join('',<main::DATA>) || die "$@ $main::DATA" unless caller();
}


1;

__END__

# Test code. Execute this module as a script.
# perl -w Devotee.pm --top_dir=/tmp -m --noneed_gpg --noneed_pgp --nosign_ack

use Getopt::Long;
use Data::Dumper;

sub main {
  my $optdesc = Devotee->Optdesc();
  GetOptions (%$optdesc);
  print "Config File = ", $::ConfOpts{'Config_File'}, " \n"
    if defined $::ConfOpts{'Config_File'};

  my $dvt = Devotee->new(%::ConfOpts);
  $dvt->validate(%::ConfOpts) unless 
    defined $::ConfOpts{'Config_File'} && -r $::ConfOpts{'Config_File'};
  $dvt->lock_vote_dir();
  my $confref = $dvt->get_config_ref();
  my $d = $dvt->dump_config();
  print $d->Dump();
  $dvt->unlock_vote_dir();
}

&main();

1;


