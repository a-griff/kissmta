#! /usr/bin/perl


use Socket;

#----USER CONFIGURABLE VALUES----
my $hostname = "mail.raidatum.com";	#Your REAL hostname, not a virtual domain name.
my $mbdir = "/home/kissmta/maildir";		#actual path, NOT relative path! NO TRAILING SLASH.
my $accountsfile = "/home/kissmta/accounts.cfg";	#actual path, NOT relative path! NO TRAILING SLASH.

#my $configfile = "/home/kissmta/pop-config.cfg";	#Not yet implemented
#my $blockedips = "/home/kissmta/pop-blocked.cfg";	#Not yet implemented
my $debugfile   = "/home/kissmta/pop-debug_log.txt";	#Only needed if $debug = "Y"
my $debug = "Y";	#Record a log of the transaction (Y/N).
#--------------------------------

my $version = "KISSMTA-POP3 V0.9.03";
my $userflag = "0";
my $passflag ="0";
#my $statflag = "0";
#my $listflag = "0";
#my $retrflag = "0";
my $deleflag = "0";
#my $rsetflag = "0";
#my $topflag  = "0";
#my $quitflag = "0";

my $user;
my @user;
my $password;
my @account;		#Temp array used to make the accounts vs password hash
my %accounts;		#Hash of valid accounts vs passwords
my @filenames;		#Temp array used to read the MBDIR directory
my $file;		#Temp variable used to read the MBDIR directory
my %filenames;		#Hash of message number and filename
my $messagecount;	#Number of messages on the server
my $filesizes;		#Hash of the filename vs filesize
my $totalsize;		#Total size of all message files in a mailbox
my @deletes;		#array of messages to be deleted on a QUIT command
my $deletes;		#Temp variable used to read out @deletes in QUIT



my $line;
my $maildir;
my @data;
my $count;


#my $sockaddr = getpeername(STDIN);
#my ($port, $ipaddr) = sockaddr_in($sockaddr);
#my $str_ipaddr = inet_ntoa($ipaddr);
my $pid = $$;

my @today = localtime(time); #(sec,min,hour,mday,mon,yr,wday,yday,isdst)
	$today[5] += 1900;
	$today[4] ++;
for ($count=0;$count<=4;$count++)  #Make the date stuff 2 digits
	{
	$today[$count] = "0".$today[$count] if ($today[$count]< 10);
	}

open(ACCOUNTS,"<$accountsfile") or die "Can't open the file!"; # READ the accounts and passwords and put them in a hash.
while (<ACCOUNTS>)
	{
	@account = split (/:/, $_);
	chop $account[1];	#For some reason, there's a "\n" at the end of $account[1]
	$accounts{lc $account[0]} = $account[1];
	}
close (ACCOUNTS);

$|++;  # Turn autoflush on.
$/ = $\ ="\r\n"; #automatically add /r/n to all STDIN & STDOUT traffic

open(DEBUGFILE,">$debugfile") || die("Cannot Open File") if ($debug eq "Y");

print "+OK POP3 $hostname $version server ready";
print DEBUGFILE "SERVER: +OK POP3 $hostname $version server ready" if ($debug eq "Y");

# Commands: USER <username>,PASS <password>,STAT,LIST,RETR,DELE,RSET,TOP,QUIT

while(<STDIN>)
	{
	$line = $_;
	chomp($line);
	print DEBUGFILE "CLIENT: $line" if ($debug eq "Y");
	if ($line =~ s/^USER//i)
		{
		$line =~ s/^\s+//; #Remove leading spaces
		$line =~ s/\s+$//; #Remove trailing spaces
		if ($line =~ m/([A-Z0-9._%-]+@[A-Z0-9._%-]+\.[A-Z]{2,4})/i)
			{
			$user = lc $1; #$1 = matched part of $line;
			# my $maildir = $mbdir."/".$usercheck[1]."/".$usercheck[0]; #Checks for the directory
			if (defined $accounts{$user})
				{
				$userflag = "1";
				print "+OK User name accepted, password please";
				print DEBUGFILE "SERVER: +OK User name accepted, password please" if ($debug eq "Y");
				}
			else
				{
				$userflag ="0";
				print "-ERR I don't know that user.";
				print DEBUGFILE "SERVER: -ERR I don't know that user." if ($debug eq "Y");
				}
			}
		else
			{
			print "-ERR USER syntax error. Should be: USER\@DOMAIN";
			print DEBUGFILE "SERVER: -ERR USER syntax error. Should be: USER\@DOMAIN" if ($debug eq "Y");
			}
		}

	elsif ($line =~ s/^PASS//i)
		{
		$line =~ s/^\s+//; #Remove leading spaces
		$line =~ s/\s+$//; #Remove trailing spaces
		if ($userflag eq "1")
			{
			if ($accounts{$user} eq $line)
				{
				$password = $line;
				$passflag = "1";
				@user = split (/@/, $user);			#USER & PASS ok, set the message dir...	
				$maildir = $mbdir."/".$user[1]."/".$user[0];	#USER & PASS ok, set the message dir...

				# PASS OK, Now read the messages and message sizes...
				opendir (MBDIR,"$maildir") or die "can't opendir $maildir";
				@filenames = readdir(MBDIR);
				closedir (MBDIR);
				$count = "1";
				$totalsize = "0";
				foreach $file(@filenames)
					{
					$filenames{$count} = $file if ($file =~ /.txt/); # need to make this more restrictive
					$filesize{$file} = -s "$maildir/$file";
					$totalsize = $totalsize + $filesize{$file};
#			print "$count:$filenames{$count}:$filesize{$file}" if ($file =~ /.txt/);
					$count++ if ($file =~ /.txt/);
					}
				$messagecount = $count - 1;

				print "+OK mailbox open, $messagecount messages";
				print DEBUGFILE "SERVER: +OK mailbox open, $messagecount messages" if ($debug eq "Y");
				}
			else
				{
				$passflag = "0";
				$messagecount = "0";
				print "-ERR Invalid password";
				print DEBUGFILE "SERVER: -ERR Invalid password" if ($debug eq "Y");
				}
			}
		else
			{
			print "-ERR You must first USER";
			print DEBUGFILE "SERVER: -ERR You must first USER" if ($debug eq "Y");
			}
		}

	elsif (($line =~ s/^STAT//i) && ($passflag ="1"))
		{
		print "+OK $messagecount $totalsize";
		print DEBUGFILE "SERVER: +OK $messagecount $totalsize" if ($debug eq "Y");
		}

	elsif (($line =~ s/^LIST//i) && ($passflag ="1"))
		{
		print "+OK Mailbox scan listing follows";
		print DEBUGFILE "SERVER: +OK Mailbox scan listing follows" if ($debug eq "Y");
		for ($count = 1; $count <= $messagecount; $count++)
			{
			print "$count $filesize{$filenames{$count}}";
			print DEBUGFILE "SERVER: $count $filesize{$filenames{$count}}" if ($debug eq "Y");
			}
		print ".";
		print DEBUGFILE "SERVER: ." if ($debug eq "Y");
		}

	elsif (($line =~ s/^RETR//i) && ($passflag ="1"))
		{
		$line =~ s/^\s+//; #Remove leading spaces
		$line =~ s/\s+$//; #Remove trailing spaces
		print "+OK $filesize{$filenames{$line}} octets";
		print DEBUGFILE "SERVER: +OK $filesize{$filenames{$line}} octets" if ($debug eq "Y");
		open (MESSTEXT,"<$maildir/$filenames{$line}") or die "can't open file";
		while (<MESSTEXT>)
			{
			chop $_;
			chop $_;
			chop $_;
			print $_;
			}
		close (MESSTEXT);
		print DEBUGFILE "SERVER: TEXT OF MESSAGE #$line" if ($debug eq "Y");
		print ".";
		print DEBUGFILE "SERVER: ." if ($debug eq "Y");
		}

	elsif (($line =~ s/^DELE//i) && ($passflag ="1"))
		{
		$line =~ s/^\s+//; #Remove leading spaces
		$line =~ s/\s+$//; #Remove trailing spaces
		#NEED TO CHECK $line TO MAKE SURE ITS ONLY A NUMBER
		if ($line <= $messagecount)
			{
			$deleflag = "1";
			push (@deletes, $line);
			print "+OK Message deleted";
			print DEBUGFILE "SERVER: +OK Message deleted" if ($debug eq "Y");
			}
		else
			{
			print "-ERR That message does not exist";
			print DEBUGFILE "SERVER: -ERR That message does not exist" if ($debug eq "Y");
			}
		}

	elsif (($line =~ s/^RSET//i) && ($passflag ="1"))
		{
		$deleflag ="0";
		@deletes = ();
		print "+OK Reset state";
		print DEBUGFILE "SERVER: +OK Reset state" if ($debug eq "Y");
		}

	elsif (($line =~ s/^NOOP//i) && ($passflag ="1"))
		{
		print "+OK";
		print DEBUGFILE "SERVER: +OK" if ($debug eq "Y");
		}

	elsif (($line =~ s/^TOP//i) && ($passflag ="1"))
		{
		$line =~ s/^\s+//; #Remove leading spaces
		$line =~ s/\s+$//; #Remove trailing spaces
		print "+OK Top of message follows";
		print DEBUGFILE "SERVER: +OK Top of message follows" if ($debug eq "Y");
		open (MESSTEXT,"<$maildir/$filenames{$line}") or die "can't open file";
		$count = 1;
		while (<MESSTEXT>)
			{
			chop $_;
			chop $_;
			chop $_;
			print $_;
			last if ($count >= 10);
			}
		close (MESSTEXT);
		print DEBUGFILE "SERVER: 10 LINES OF TEXT OF MESSAGE #$line" if ($debug eq "Y");
		print ".";
		print DEBUGFILE "SERVER: ." if ($debug eq "Y");
		}

	elsif ($line =~ s/^QUIT//i)
		{
		if ($deleflag eq "1")
			{
			foreach $deletes(@deletes)
				{
				unlink ("$maildir/$filenames{$deletes}");
				}
			}
		print "+OK Have a nice day! :)";
		print DEBUGFILE "SERVER: +OK Have a nice day! :) \r\nSERVER ACTION: Deleting message $deletes" if ($debug eq "Y");
		last;
		}

	elsif ($line =~ s/^CAPA//i)
		{
		print "+OK Here's what I can do:\r\nUSER\r\nUIDL\r\nTOP\r\nLOGIN-DELAY 10\r\n.";
		print DEBUGFILE "SERVER: +OK Here's what I can do:\r\nUSER\r\nUIDL\r\nTOP\r\nLOGIN-DELAY 10\r\n." if ($debug eq "Y");
		}

	elsif (($line =~ s/^UIDL//i) && ($passflag ="1"))
		{
		$line =~ s/^\s+//; #Remove leading spaces
		$line =~ s/\s+$//; #Remove trailing spaces
		print "+OK";
		print DEBUGFILE "SERVER: +OK" if ($debug eq "Y");
		if (($line >= 1) && ($line <= $messagecount))
			{
			$file = substr($filenames{$count},0,(length($filenames{$count})-4));
			print "$line $file";
			}
		elsif ($line > $mesagecount)
			{
			print "-ERR no such message, only $messagecount messages in maildrop";
			print DEBUGFILE "SERVER: -ERR no such message, only $messagecount messages in maildrop" if ($debug eq "Y");
			}
#		elsif (defined $line)  #If $line !== a number THEN....
#			{
#			print "-ERR no such message, only $messagecount messages in maildrop";
#			print DEBUGFILE "SERVER: -ERR no such message, only $messagecount messages in maildrop" if ($debug eq "Y");
#			}
		else
			{
			for ($count = 1; $count <= $messagecount; $count ++)
				{
				$file = substr($filenames{$count},0,(length($filenames{$count})-4));
				print "$count $file";
				print DEBUGFILE "SERVER: $count $file" if ($debug eq "Y");
				}
			print ".";
			print DEBUGFILE "SERVER: ." if ($debug eq "Y");
			}
		}

	else	#(CATCH ALL COMMAND)
		{
		print "-ERR I don't understand that";
		print DEBUGFILE "SERVER: -ERR I don't understand that" if ($debug eq "Y");
		}



	}

close (DEBUG);
