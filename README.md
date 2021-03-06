# DEVOTEE -- The DEbian VOTe EnginE

First of all, we would like to thank our generous sponsors for making this project possible. See the list of our [sponsors](doc/Sponsors.md).

	This directory contains the code for the mechanism used by the
 Debian project to conduct email based votes. This system has been
 written from scratch for use by the Debian project, though it is
 hoped that other people would also find it useful.

	The emphasis here is data integrity. Votes should *NEVER EVER*
 be lost by the system. The mechanism is modular, and one should be
 able to test, and refactor, each module independently. The process is
 reproducible, and idempotent, so that one has some assurance of the
 integrity of the process.

	Intermediate results are saved (adds to replayability),
 and may be examinable by common UNIX text processing tools -- ls,
 cat, and your favourite text editor. Devotee goes back to the UNIX
 philosophy of having independent tools that do one thing well. (kinda
 goes along with modularity, independence, etc).

	Devotee breaks down the voting process into 9 steps, each of
 which is implemented by independent pieces of code (some of these
 steps have sub-parts, and each sub-part, then, is an independent
 script).

======================================================================
 Stage 1: spool vote mail. 

 dvt-spool - Safely spool incoming data to a spool file
     This stage is responsible for storing each incoming mail into a
     separate file. A script run from .forward (as has traditionally
     been the case for Debian voting) spools the ballot into a spool
     directory (flocking the sequence file as needed). This routine is
     designed to spool mail safely into individual files a la maildir.

     The emphasis here is safety, and alacrity: this routine needs to
     be very light weight, in order to scale to large numbers of
     votes, and be able to safely deliver the contents to the disk
     even under high loads.  Due to this extremely simple goal, there
     are few configurable parameters, and even fewer command line
     options. The resulting files shall be marked read only. The file
     names are chosen to sort correctly.  This involves a mechanism to
     serialize the file naming, using locks to sync the asynchronous
     incoming mails.


 dvt-cp - Safely copy mails from the spool file to a working dir
      1a: Periodically, another script should be run from cron that
          copies files from the spool directory to the working
          dir. The emphasis here is safety, and interaction with the
          other Devotee scripts. The spooling scripts are
          asynchronous, and so this script carefully locks files
          cooperatively with the spooler script so as to not tread on
          each others toes. If the destination file already exists,
          one need not recopy unless the force option is on. This
          script is thus idempotent.

----------------------------------------------------------------------
 Stage 2: Handle MIME encoding

 dvt-mime - From the work dir, decode and save the body of the message
          This routine is designed to handle various forms of MIME
          encampulation, including PGP/MIME, and create a decoded body
          text in a format that can be easily checked for cryptograhic
          signatures.

          The idea here is to be forgiving of MIME errors and be able
          to present as many signed votes to the signature verifier as
          possible.  To further this goal, we save the body part of
          RFC 3156 PGP/MIME encoded ballots in two formats: one in
          CRLF line ending formatm as required by the RFC's, and
          another in simple UNIX line ending format, since some MUA's
          incorrectly calculate the signature over the raw message,
          without converting to CRLF format.

          Additionally, this script attempts to be idempotent. It is
          also incremental, unless a force option is given, in which
          case it re-decodes previously decoded messages.

----------------------------------------------------------------------
 Stage 3: Validate signature
      
 dvt-gpg - verify digital signatures on the ballot
	This is also run from cron, after the copy script from 1a is
	done. For each new file in the work dir, it shall check the
	signature against keyrings specified on the command line. It
	shall mark failure/success (initial implementation: It works
	touching a file in a gpg subdir with the same name as the file
	in the working dir. If the file already exists in the gpg
	subdir, one need not check the sig unless the force option is
	on) This script is thus idempotent.

	 This utility handles both PGP/MIME signed messages, as well
	 as the text/plain ascii armored signed messages.  When
	 handling PGP/MIME messages, if it fails to validate the
	 signature with the body with CRLF line endings, it tries to
	 validate against an alternate version of the body where the
	 line ending is the normal unix newline; since some MUAs
	 incorrectly generate the signature without normalizing the
	 line endings. It also maintains a database of sig ids to
	 prevent a replay attack.

----------------------------------------------------------------------
 Stage 4: Query LDAP

 dvt-ldap
	 This routine is designed to query the debian ldap server to
	 determine the unique uid for every debian developer.

	 The unique uid that is determined from LDAP, using the key
	 fingerprint as a filter, shall be used as primary index,
	 allowing for developers with multiple keys to still be able
	 to replace their vote. The LDAP check also acts as an
	 additional check; there are keys in the keyring that belong
	 to administrative roles in Debian (Security Key, for
	 instance), which should not have voting proviledges.

	 It is important to add a filter to limit the matches from
	 LDAP, if, like Debian's LDAP, the server contains entries for
	 people other than those enfranchised.

	For each file in the gpg dir which succeeded, query ldap using
	information from the corresponding file in the work
	subdir. Store results in a file in the ldap subdir (if the
	file already exists in ldap subdir, no query need be made,
	unless the force option is set). Mark the results as valid or
	invalid. This script is idempotent.

----------------------------------------------------------------------
 Stage 5: Extract and Parse the ballot
 
 5a:
  dvt-extract
         This routine is designed to handle various forms of MIME
         encampulation, including PGP/MIME, and create a decoded body
         in a form easy to parse (as opposed to not altering anything
         in order to execute a cryptographic check).
 5b:
  dvt-parse - parse the ballot and create a single line synopsis
	This routine parses the ballot, and writes out a compact,
	single line representation of the choices. It also flags
	ballots that it can't parse so that nacks can be sent out to
	the voter, detailing the problems encountered while parsing.

	Additionally, this script attempts to be idempotent. It is also
	incremental, unless a force option is given, in which case it
	re-parses previously parsed messages.

----------------------------------------------------------------------
 Stage 6: generate response.
 dvt-gack - generate an acknowledgement for the vote
	  Also run from cron, this script is responsible for
	  generating the acknowledgement for the vote, after ensuring
	  that the ballot passed GPG and LDAP checks. If vote is by
	  secret ballot, it creates a secret alias associated with the
	  voter (since the voter is identified by the uid field of the
	  LDAP data, each voter can be uniquely identified; we only
	  have one alias per voter, no matter how many times thew
	  voter votes.  This alias, along with the UID of the voter,
	  is passed on to md5sum; and the resulting opaque psuedo
	  random string is displayed on the final tally sheet.

	  The ack also notes if this is not the first vote by the
	  voter (If the ack subdir already has a file, we can skip
	  that unless the force option is given). This script is thus
	  idempotent.

----------------------------------------------------------------------
 Stage 7: Send acks and nacks

 dvt-ack - encrypt and mail a previously generated acknowledgement.
	 Also run from cron.  This routine encrypts and emails
	 acknowledgements that had been generated by dvt-gack.  The
	 email address and the key used are the canonical ones found
	 in the LDAP database.

	 Additionally, this script attempts to be idempotent. It is
	 also incremental, unless a force option is given, in which
	 case it re-sends previously sent messages.  The acks are
	 digitally signed by a vote key.

 dvt-nack - send out rejection messages for problems encountered in processing
      This routine sends out rejection letters for failed ballots,
      including the reasons for the failure. The mail is not
      encrypted, since the failure mode could be an inability to
      determine the GPG key for the voter.


----------------------------------------------------------------------
 Stage 8: Create input file for vote method

 dvt-tally - create a tally sheet from the votes cast.
	   This routine is designed to create a tally sheet from the
	   votes cast.  This routine looks at the messages in the
	   tally dir to look at votes that have been succesfully
	   recorded, and then looks for the unique user id determined
	   by querying the LDAP database.  The unique uid that is
	   determined from LDAP, using the key fingerprint as a
	   filter, shall be used as primary index, allowing for
	   developers with multiple keys to still be able to replace
	   their vote.

	   The tally sheet produced depends on a couple of factors;
	   firstly, whether this is the final tally or not (in the
	   case it is not, a dummy tally sheet is produced). Secondly,
	   if this is a secret ballot vote, the tally sheet is
	   produced with the alias of the voter rather than the name;
	   the alias having been sent in when the acknowledgement was
	   generated for the first vote cast by the voter.

 dvt-voters - List the people who have successfully voted
	   This routine uses the output of dvt-ldap and tabulates the
	   names of people who have succesfully voted so far.

	   This routine looks at the messages in the tally dir to look
	   at votes that have been succesfully recorded, and then
	   looks for the unique user id determined by querying the
	   LDAP database. Finally, it sorts and pretty prints the
	   results into the configured destination.


----------------------------------------------------------------------
Stage 9: Determine the results of the vote.
 dvt-rslt - Given a tally sheet, calculate the Condorcet winner
	This routine is the heart of the voting system. It takes into
	account quorum requirements (reading the output file produced
	by dvt-quorum), and also the configured majority requirements,
	if any.

	It reads the tally sheet produced by dvt-tally, and creates
	the initial beat matrix; and the pairwise defeat list, and
	finally the schwartz set. If there are defeats between the
	members of the schwartz set, it drops the weakest defeat and
	repeats, until there is a winner.

	It puts the results in the configured output file.
