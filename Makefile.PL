#                              -*- Mode: Cperl -*- 
# Makefile.PL --- 
# Author           : Manoj Srivastava ( srivasta@glaurung.green-gryphon.com ) 
# Created On       : Sat Dec 13 18:38:23 2003
# Created On Node  : glaurung.green-gryphon.com
# Last Modified By : Manoj Srivastava
# Last Modified On : Sat Dec 13 19:13:24 2003
# Last Machine Used: glaurung.green-gryphon.com
# Update Count     : 9
# Status           : Unknown, Use with caution!
# HISTORY          : 
# Description      : 
#
# arch-tag: b9a0fdb1-aac6-4903-9d2e-248b7671adcd
#

use ExtUtils::MakeMaker;
WriteMakefile(
	      'NAME'          => 'Devotee',
	      'VERSION_FROM'  => 'lib/Devotee.pm',
	      'ABSTRACT'      => 'The DEbian VOte Engine for email based votes',
	      'AUTHOR'        => 'Manoj Srivastava <srivasta@debian.org>',
	      'EXE_FILES'     =>  [qw[dvt-ack dvt-ballot dvt-cp
                                     dvt-extract dvt-gack dvt-gpg
                                     dvt-ldap dvt-mime dvt-nack
                                     dvt-parse dvt-quorum dvt-rslt
                                     dvt-spool dvt-tally dvt-voters]],
	     );
