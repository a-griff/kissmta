#! /usr/bin/perl


use Socket;

#----USER CONFIGURABLE VALUES----
my $hostname = "MAIL.DOMAIN.COM";		#Your REAL hostname, not a virtual domain name.
my $mbdir = "/home/kissmta/maildir";		#MailBox directory. Actual path, NOT relative path! NO TRAILING SLASH.
my $accountsfile = "/home/kissmta/accounts.cfg";	#actual path, NOT relative path! NO TRAILING SLASH.

my $debugfile = "/home/kissmta/mta-debug_log.txt";	#Only needed if $debug = "Y"
my $debug = "N";	#Record a log of the transaction (Y/N).

#--------------------------------

my $version = "KISSMTA V0.0.03";
my $heloflag = "0";
my $mailfromflag ="0";
my $rcpttoflag = "0";
my $dataflag = "0";
my $line;
my $helo;
my $mailfrom;
my $rcptto;	#Temp variable for use with @rcptto
my @rcptto = (); #list of VALID mail recipients
my @data;
my $count;
my @account;	#Array used to read the accounts from $accountsfile
my %accounts;	#Hash which stores
my $messagesize;

my $sockaddr = getpeername(STDIN);
my ($port, $ipaddr) = sockaddr_in($sockaddr);
my $str_ipaddr = inet_ntoa($ipaddr);

my $pid = $$;
my $sequence_number = 1;

my @today = localtime(time); #(sec,min,hour,mday,mon,yr,wday,yday,isdst)
	$today[5] += 1900;
	$today[4] ++;
@today[0..4] = map{sprintf '%02d', $_} @today[0..4]; #Make the date stuff 2 digit


open(ACCOUNTS,"<$accountsfile") or die "Can't open the file!"; # READ the accounts and passwords and put them in a hash.
while (<ACCOUNTS>)
	{
	@account = split (/:/, $_);
	chop $account[1];	#For some reason, there's a "\n" at the end of $account[1]
	$accounts{lc $account[0]} = $account[1]; # $account[1] is the password which isn't used in this proggy
	}
@account =();
close (ACCOUNTS);



$|++;  # Turn autoflush on. Immediately send data out, don't wait for a delimiter.
$/ ="\r\n"; # Input is delimited by "\r\n".
$\ ="\r\n"; # Output automatically adds "\r\n".




open(DEBUGFILE,">$debugfile") || die("Cannot Open File") if ($debug eq "Y");


#Send a greeting to the client
print "220 $hostname $version - $today[5]-$today[4]-$today[3] $today[2]:$today[1]:$today[0]";
print DEBUGFILE "SERVER: 220 $hostname $version - $today[5]-$today[4]-$today[3] $today[2]:$today[1]:$today[0]" if ($debug eq "Y");






while(<STDIN>)
	{
	$line = $_;
	chomp($line);
	print DEBUGFILE "CLIENT: $line" if ($debug eq "Y");



	if ($dataflag eq "1")
		{
		if ($line eq ".")
			{
			my $queue_id = "$today[5]$today[4]$today[3]$today[2]$today[1]$today[0]-$pid-$sequence_number";
			print "250 OK queued as id=$queue_id";
			print DEBUGFILE "SERVER: 250 OK queued as id=$queue_id" if ($debug eq "Y");
			if (($mailfromflag eq "1") && ($rcpttoflag eq "1"))
				{
				local $\ = ""; #remove the "\r\n" from the output for message file writing.
				foreach $rcptto(@rcptto)  #Rpeat for each VALID recipient
					{
					my @rcpttocheck = split(/@/, $rcptto);
					my $mailfile = $mbdir."/".$rcpttocheck[1]."/".$rcpttocheck[0]."/".$queue_id.".txt";
					open(MSGFILE,">$mailfile") || die("Cannot Open File");
					print MSGFILE "Received from: $helo ([$str_ipaddr]) by $hostname ($version) at $today[5]-$today[4]-$today[3], $today[2]:$today[1]:$today[0]\n";
					foreach (@data)
						{
  						print MSGFILE "$_\n";
						}
					}
				close (MSGFILE);
				}
			$rcptto = undef;
			$rcpttoflag ="0";
			$sequence_number++;
			$mailfrom = undef;
			$mailfromflag = '0';
			$dataflag = "0";
			}
		else
			{
			push @data, $line;
			$messagesize = $messagesize + length($line);
#			$dataflag = "4" if ($messagesize >= $maxmessagesize)
			}
		}
	elsif ($line =~ s/^HELO//i)
		{
		$line =~ s/^\s+//; #Remove leading spaces
		$line =~ s/\s+$//; #Remove trailing spaces
		$helo = $line;
		$heloflag = "1";
		print "250 $hostname Hello $helo [$str_ipaddr]";
		print DEBUGFILE "SERVER: 250 $hostname Hello $helo [$str_ipaddr]" if ($debug eq "Y");
		}
	elsif ($heloflag eq "0")
		{
		print "503 Polite people say HELO first";
		print DEBUGFILE "SERVER: 503 Polite people say HELO first" if ($debug eq "Y");
		}
	elsif (($line =~ s/^MAIL FROM://i) && ($heloflag eq "1"))
		{
		if ($line =~ m/([A-Z0-9._%-]+@[A-Z0-9._%-]+\.[A-Z]{2,4})/i)
			{
			$mailfrom = $1; #$1 = matched part of $line;
			$mailfromflag = "1";
			print "250 OK";
			print DEBUGFILE "SERVER: 250 OK" if ($debug eq "Y");
			}
		else
			{
			$mailfromflag = "0";
			print "501 Syntax error in parameters or arguments";
			print DEBUGFILE "SERVER: 501 Syntax error in parameters or arguments" if ($debug eq "Y");
			}
		}
	elsif (($line =~ s/^RCPT TO://i) && ($heloflag eq "1"))
		{
		if ($line =~ m/([A-Z0-9._%-]+@[A-Z0-9._%-]+\.[A-Z]{2,4})/i)
			{
			$rcptto = lc($1); #$1 = matched part of $line;
			if (defined $accounts{$rcptto})
				{
				push (@rcptto,$rcptto);
				$rcpttoflag ="1";
				my @rcpttocheck = split(/@/, $rcptto);
				mkdir("$mbdir/$rcpttocheck[1]", 0777) if (!-d "$mbdir/$rcpttocheck[1]");
				mkdir("$mbdir/$rcpttocheck[1]/$rcpttocheck[0]", 0777) if (!-d "$mbdir/$rcpttocheck[1]/$rcpttocheck[0]");
				print "250 Accepted";
				print DEBUGFILE "SERVER: 250 Accepted" if ($debug eq "Y");
				}
			else
				{
				print "550 Requested action not taken: mailbox unavailable";
				print DEBUGFILE "SERVER: 550 Requested action not taken: mailbox unavailable" if ($debug eq "Y");
				}
			}
		else
			{
			print "550 Requested action not taken: mailbox unavailable";
			print DEBUGFILE "SERVER: 550 Requested action not taken: mailbox unavailable" if ($debug eq "Y");
			}
		}
	elsif (($line =~ s/^DATA//i) && ($heloflag eq "1"))
		{
		$dataflag = "1";
		print "354 Enter message, ending with \".\" on a line by itself";
		print DEBUGFILE "SERVER: 354 Enter message, ending with \".\" on a line by itself" if ($debug eq "Y");
		}
	elsif ($line =~ s/^QUIT//i)
		{
		print "503 Bad sequence of commands: MAIL FROM missing. Mail not delivered." if ($mailfromflag eq "0");
		print DEBUGFILE "SERVER: 503 Bad sequence of commands: MAIL FROM missing. Mail not delivered." if (($mailfromflag eq "0") && ($debug eq "Y"));
		print "503 Bad sequence of commands: RCPT TO missing. Mail not delivered." if ($rcpttoflag eq "0");
		print DEBUGFILE "SERVER: 503 Bad sequence of commands: RCPT TO missing. Mail not delivered." if (($rcpttoflag eq "0") && ($debug eq "Y"));
		print "503 Bad sequence of commands: DATA missing. Mail not delivered." if ($dataflag eq "0");
		print DEBUGFILE "SERVER: 503 Bad sequence of commands: DATA missing. Mail not delivered." if (($dataflag eq "0") && ($debug eq "Y"));
		print "221 $hostname closing transmission channel.  Goodbye." if (($mailfromflag eq "1") && ($rcpttoflag eq "1") && ($dataflag eq "2"));
		print DEBUGFILE "SERVER: 221 $hostname closing transmission channel.  Goodbye." if (($mailfromflag eq "1") && ($rcpttoflag eq "1") && ($dataflag eq "2") && ($debug eq "Y"));
		last;
		}
	elsif (($line =~ s/^EHLO//i) || ($line =~ s/^RSET//i) || ($line =~ s/^SEND//i) || ($line =~ s/^SOML//i) || ($line =~ s/^SAML//i) || ($line =~ s/^VRFY//i) || ($line =~ s/^EXPN//i) || ($line =~ s/^HELP//i) || ($line =~ s/^NOOP//i) || ($line =~ s/^TURN//i))
		{
		print "502 Command not implemented";
		print DEBUGFILE "SERVER: 502 Command not implemented" if ($debug eq "Y");
		}
	else
		{
		print "500 Syntax error or command unrecognised";
		print DEBUGFILE "SERVER: Syntax error or command unrecognised" if ($debug eq "Y");
		}
	}




#Got a QUIT command, let's see if we got all the data and now save it to the directories


close (DEBUGFILE) if ($debug eq "Y");



