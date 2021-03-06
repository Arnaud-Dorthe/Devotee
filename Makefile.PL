#                              -*- Mode: Cperl -*- 
# Makefile.PL --- 
# Author           : Manoj Srivastava ( srivasta@glaurung.green-gryphon.com ) 
# Created On       : Sat Dec 13 18:38:23 2003
# Created On Node  : glaurung.green-gryphon.com
# Last Modified By : Manoj Srivastava
# Last Modified On : Thu Oct 14 18:31:22 2004
# Last Machine Used: glaurung.internal.golden-gryphon.com
# Update Count     : 14
# Status           : Unknown, Use with caution!
# HISTORY          : 
# Description      : 
#
# arch-tag: b9a0fdb1-aac6-4903-9d2e-248b7671adcd
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

use ExtUtils::MakeMaker;
use 5.00503;
if($] < 5.006) {
    require "eg/5005it.pl";

    print <<EOT;
########################################################
# Hm, you're still using perl 5.005. Although I don't  #
# condone that, I'll let it slip this time:            #
# Changing distribution to be backwards compatible ... #
EOT
    mk5005("t", "lib");
    print <<EOT;
# Done. But do me a favour and upgrade soon.           # 
########################################################
EOT
}

WriteMakefile(
              'NAME'        => 'Devotee',
              'VERSION_FROM' => 'lib/Devotee.pm',
              ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
               ('ABSTRACT'    => 'The DEbian VOTe EnginE for email based votes',
                'AUTHOR'      => 'Manoj Srivastava <srivasta@debian.org>') : ()),
              'EXE_FILES'    =>  [qw[dvt-ack dvt-ballot dvt-cp
                                       dvt-extract dvt-gack dvt-gpg
                                       dvt-ldap dvt-mime dvt-nack
                                       dvt-parse dvt-quorum dvt-rslt
                                       dvt-spool dvt-tally dvt-voters]],
              'LIBS'      => [''], # e.g., '-lm'
              'DEFINE'    => '', # e.g., '-DHAVE_SOMETHING'
              # Insert -I. if you add *.h files later:
              'INC'       => '', # e.g., '-I/usr/include/other'
              # Un-comment this if you add C files to link with later:
              # 'OBJECT'  => '$(O_FILES)', # link all the C files too
              'clean'     => {FILES => "*.tar.gz *.ppd pod2htm*"},
             );
##########################################
sub get_man3pods {
##########################################
  # Only done for versions < 5.8.0
  return () if $] >= 5.008;

  print <<EOT;
##################################################
# Detected buggy MakeMaker version, creating man #
# pages manually                                 #
##################################################
EOT
  require File::Find;

  my @pms = ();

  File::Find::find(sub { 
                     push @pms, $File::Find::name if /\.pm$/
                   }, "lib");

  return('MAN3PODS', {
                      map { my @comps = split /\//, $_;
                            shift @comps;
                            my $csep = join '::', @comps;
                            $csep =~ s/\.pm$//;
                            ($_, "\$(INST_MAN3DIR)/$csep.\$(MAN3EXT)");
                          } @pms
                     });
}
