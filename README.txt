GENERAL:
KissMTA is an e-mail server with the goal of being easy to setup and manage.  It's written in Perl and is developed on a Linux system. Since it's goal is to be simple, there should be no problem getting it to run on other *nix systems.

One of the goals is to write it to be as portable as possible using the least number of 3rd partyPerl modules.



VERSION:
kissmta-0.0.03 - RECIEVE ONLY smtp server (will be upgraded to full MTA).
kisspop-0.0.01 - Incomplete pop server for testing. It works but it does not support all POP functions (yet).




INSTALLATION:
NOTE: KissMTA is being developed on a Slackware Linux server so other distros may have slightly different instructions.

You CAN run the server as root but, it's really a bad idea so,...
1) Create a new user (as root)
  adduser kissmta

2) Change to that user
  su kissmta

3) Download KissMTA

4) Edit the USER CONFIGURABLE VALUES in beginning of the .pl files

5) Create the binary directory and directories specified in the step above. These directories can be anywhere and named anything you want.
  mkdir ~/bin
  mkdir ~/maildir

6) Move the files into ANY directory you want
  mv kiss* ~/bin/
  mv accounts.cfg ~/bin/

7) Make sure the files are executable.
  cd ~/bin
  chmod 755 *.pl

8) Either rename the *.pl files or create symbolic links to them.
  ln -S kissmta-VERSION.pl kissmta
  ln -S kisspop-VERSION.pl kisspop

9) Configure inetd to route snmp and pop traffic to KissMTA executable
  exit (to leave kissmta user and go back to root)
  vi /etc/inetd.conf

    smtp    stream  tcp     nowait  root    /usr/sbin/tcpd  /home/kissmta/bin/kissmta
    pop3    stream  tcp     nowait  root    /usr/sbin/tcpd  /home/kissmta/bin/kisspop

10) Edit the accounts.cfg file.
FORMAT:
  email_address:password
  (one line per account)

11) You should now have a working* e-mail server.

*At this time KissMTA is recieve only.



