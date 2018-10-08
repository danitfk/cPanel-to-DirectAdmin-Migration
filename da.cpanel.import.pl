#!/usr/bin/perl
use strict;
use vars qw( $VERSION $ROOT_PATH );

$VERSION = '.9.4';
$ROOT_PATH = './';

&main;

#todo - email broken?
# .9.4
#  * Added cPanel 11.24 support

# .9.3
#  * Added patch by backusnetcom to fix importing when a MySQL user does not have "ALL PRIVILEGES"
#  * Added patch by Lem0nHead to fix importing of large MySQL databases.

# .9beta1:
#  * Squirrelmail settings now converted.
#  * IMAP Maildir data now converted. (working?)
#  * Miscellanous cleanups and improvements.


sub main {

	print "\n";
	print "Welcome to the \033[1mcPanel-to-DirectAdmin conversion tool\033[0m, version $VERSION.\n";
    print "Tool created by Phillip Stier <query\@kade.nu>.\n";
	print "Please report bugs to this thread on the DirectAdmin forum:\n";
	print "http://directadmin.com/forum/showthread.php?t=2247\n";
	print "\n";
	

	print "\033[1mRead:\033[0m\n";
	print "This tool exclusively uses the cPanel backup file to do the conversion,\n";
	print "so this tool can be executed on the cPanel OR DirectAdmin server.\n";
    print "Before starting, copy your cPanel backups into the ${ROOT_PATH}import directory\n";
	print "This tool will covert backups created by both\n";
	print " - the '/scripts/pkgacct' script, and\n";
	print " - cPanel's 'Full Backup' GUI tool.\n";
	print "After running this tool, transfer the tarballs inside ${ROOT_PATH}export to any DirectAdmin reseller's 'user_backups' directory.\n";
	print "\n";
	
	print "Have you read, understood and applied the above? (y/n) [y] ";
	my $input = <>;


	print "\n";

	if ( $input !~ /^y|yes$/i &&!( $input == "\n" && length $input == 1 )) {
		print "Bye.\n";
		exit;
	}
	


	print "[If you are running this tool on the cPanel server]: After this tool is finished, should successfully created DirectAdmin tarballs be transferred to your DirectAdmin reseller user_backups directory? (y/n) [n] ";
	chomp( $input = <> );

	print "\n";

	my ($DA_PASSWD, $DA_ADDRESS, $DA_PATH);
	if ( $input =~ /^y|yes$/i ) {
		print "You've chosen to automatically transfer tarballs over.. please provide your DA server info...\n";

		my %default = read_conf("${ROOT_PATH}defaults.conf");

		print "DirectAdmin server address: [$default{ip}] ";
		chomp( $DA_ADDRESS = <> );
		$DA_ADDRESS = $default{ip} if $DA_ADDRESS eq '';

		#print "DirectAdmin root password: ";
		#chomp( $DA_PASSWD = <> );

		print "DirectAdmin user_backups directory: [/home/$default{creator}/user_backups] ";
		chomp( $DA_PATH = <> );
		$DA_PATH = "/home/$default{creator}/user_backups" if $DA_PATH eq '';

		print "\n\n";

	}

	print "Checking for ${ROOT_PATH}import/... ";

	if ( -e $ROOT_PATH.'import' ) {
		print "OK\n";
	}
	else {
		&fail;
	}


	print "Checking for ${ROOT_PATH}export/... ";

	if ( -e $ROOT_PATH.'export' ) {
		print "OK\n";
	}
	else {
		&fail;
	}


	print `clear`;
	print "We're about to begin the conversion process.\n";
	print "All tarballs residing in ${ROOT_PATH}import/ will be checked for validity and converted to the DirectAdmin format.\n";
	print "DirectAdmin formatted tarballs will be placed in ${ROOT_PATH}export/.\n";
	print "\n";
	print "Shall we begin? (y/n) [y] ";
	$input = <>;

	if ( $input !~ /^y|yes$/i &&!( $input == "\n" && length $input == 1 )) {
		print "Bye.\n";
		exit;
	}

	print "\n";


	my $c = 0;

	opendir IMPORT, "${ROOT_PATH}import/";
	while ( my $file = readdir IMPORT )
	{
		if ( $file =~ /\.tar.gz\Z/ ) {
			doImportUser($file);
			$c++;
		}
	}
	closedir IMPORT;

	$c = "No" if $c == 0;

	print "$c tarballs attempted/converted.\n\n";

	# are we suppose to transfer them?
	if ( $c ne "No" && $DA_ADDRESS ) {
		print "Transfer process running... \n";
		`scp ${ROOT_PATH}export/*.tar.gz root\@$DA_ADDRESS:$DA_PATH`;
	}

	print "~fin.\n\n";

	exit;
}


sub doImportUser {
	my $incoming_file = shift;

	print "Examining \033[1m$incoming_file\033[0m... ";

	#backup-8.5.2004_00-04-27_USER.tar.gz
	#cpmove-USER.tar.gz

	(my $incoming_user = $incoming_file) =~ s/\.tar\.gz//;
	$incoming_user =~ s/^cpmove-//;
	$incoming_user =~ s/^package-//;
	$incoming_user =~ s/^backup-\d+\.\d+\.\d+_\d+-\d+-\d+_//;

	print "(user \033[1m$incoming_user\033[0m)";
	print "\n\tExtracting cPanel backup.";


	mkdir "${ROOT_PATH}export/$incoming_user",0755;
	mkdir "${ROOT_PATH}export/$incoming_user/domains",0755;
	mkdir "${ROOT_PATH}export/$incoming_user/backup",0755;
	#mkdir "${ROOT_PATH}export/$incoming_user/email_data",0755;

	# is it a valid cPanel tarball?
	# lets try to export it to ./import/$import_user
	`tar xzfC ${ROOT_PATH}import/$incoming_file ${ROOT_PATH}import`;

	print ".";

	(my $tmp_folder = $incoming_file) =~ s/\.tar\.gz//;
	`mv ${ROOT_PATH}import/$tmp_folder ${ROOT_PATH}import/$incoming_user`;

	# cPanel 11.24 tars the "homedir" folder, so we need to extract it
	if ( -e "${ROOT_PATH}import/$incoming_user/homedir.tar" )
	{
		print ".";
		`tar xfC ${ROOT_PATH}import/$incoming_user/homedir.tar ${ROOT_PATH}import/$incoming_user/homedir`;
	}
	
	print ". ";

	open FH, "${ROOT_PATH}import/$incoming_user/quota";
	my $cp_quota = int( do { local $/; <FH> } );
	close FH;

	open FH, "${ROOT_PATH}import/$incoming_user/shadow";
	my $cp_shadow = do { local $/; <FH> };
	close FH;

	open FH, "${ROOT_PATH}import/$incoming_user/homedir/.contactemail";
	my $cp_email = do { local $/; <FH> };
	close FH;

	if (!$cp_email) {
		$cp_email = 'joe'.int(rand(2550)).'@whereever'.int(rand(2550)).'.com'; # DA apparently needs an email address.. so I give it one :>
	}

	my %cp_user = read_conf("${ROOT_PATH}import/$incoming_user/cp/$incoming_user");
	my %default = read_conf("${ROOT_PATH}defaults.conf");


	# append default cP domain to cP-addon-domain listing (because I'm lazy)
	open FH, ">>${ROOT_PATH}import/$incoming_user/addons";
	print FH "$cp_user{DNS}=null_$cp_user{DNS}\n";
	close FH;

	my $dom_count = 0;

	# load up cP-addon-domains
	open FH, "${ROOT_PATH}import/$incoming_user/addons";
	while ( my $line = <FH> ) {
		chomp $line;
		my ($domain, $sub) = split /=/, $line, 2;
		my ($sub_dir, $sub_parent) = split /_/, $sub, 2;

		print "\n\tDomain ".(1+$dom_count).": $domain...";
		
		# create cP-addon-domain in both DA-domain-dir and DA-backup-dir
		mkdir "${ROOT_PATH}export/$incoming_user/domains/$domain",0755;
		mkdir "${ROOT_PATH}export/$incoming_user/backup/$domain",0755;
		mkdir "${ROOT_PATH}export/$incoming_user/backup/$domain/email",0755;
		mkdir "${ROOT_PATH}export/$incoming_user/backup/$domain/email/data",0755;

		# create DA-domain.conf file in DA-backup-dir/$domain
		my %da_domain = (
				bandwidth		=>	'unlimited',
				cgi				=>	$default{cgi},
				defaultdomain	=>	$cp_user{DNS} eq $domain ? 'yes' : 'no' ,
				domain			=>	$domain,
				ip				=>	$default{ip},
				php				=>	$default{php},
				quota			=>	'unlimited',
				ssl				=>	$default{ssl},
				suspended		=>	'no',
				username		=>	$incoming_user
			);
		write_conf("${ROOT_PATH}export/$incoming_user/backup/$domain/domain.conf",\%da_domain);

		# create DA-domain.usage file in DA-backup-dir/$domain
		my %da_usage = (
				bandwidth	=>	0,
				log_quota	=>	0,
				quota		=>	0
			);
		write_conf("${ROOT_PATH}export/$incoming_user/backup/$domain/domain.usage",\%da_usage);

		# create DA-ftp.conf file in DA-backup-dir/$domain
		my %da_ftp = (
				Anonymous		=>	$default{aftp} eq 'ON' ? 'yes' : 'no' ,
				AnonymousUpload	=>	'no'
			);
		write_conf("${ROOT_PATH}export/$incoming_user/backup/$domain/ftp.conf",\%da_ftp);

		# create DA-ftp.passwd file in DA-backup-dir/$domain
		open GH, ">${ROOT_PATH}export/$incoming_user/backup/$domain/ftp.passwd";
		print GH "";
		close GH;

		my $da_domain_db = '';


		print "\n\t\tSub-domains... ";
		my $subs_count = 0;
		my $subs_list = '';

		# loop potential subdomains in cP-sds file
		open GH, "${ROOT_PATH}import/$incoming_user/sds";
		while ( my $sds = <GH> ) {
			chomp $sds;
			my ($sds_sub, $sds_domain) = split /_/, $sds, 2;

			# if cP-subdomain belongs to current DA-$domain...
			if ( $sds_domain eq $domain ) {

				$subs_list .= "\n\t\t\to $sds_sub.$domain";

				# append subdomain to DA-subdomain.list
				open HH, ">>${ROOT_PATH}export/$incoming_user/backup/$domain/subdomain.list";
				print HH "$sds_sub\n";
				close HH;

				# append DNS info to temp DA-$domain.db cache
				$da_domain_db .= "$sds_sub     14400   IN      A       $default{ip}\n";

				$subs_count++;

			}

		}
		close GH;

		print "($subs_count converted)$subs_list";



		print "\n\t\tBuilding DNS... ";

		# create DA-$domain.db file in DA-backup-dir/$domain
		open GH, ">${ROOT_PATH}export/$incoming_user/backup/$domain/$domain.db";
		print GH qq~
\$TTL 14400
\@       IN      SOA     $default{ns1}.      root.$domain. (
                                                2003120200
                                                7200
                                                3600
                                                1209600
                                                86400 )

$domain.     14400   IN      NS      $default{ns1}.
$domain.     14400   IN      NS      $default{ns2}.

$domain.     14400   IN      A       $default{ip}
ftp     14400   IN      A       $default{ip}
localhost.$domain.   14400   IN      A       127.0.0.1
mail    14400   IN      A       $default{ip}
www     14400   IN      A       $default{ip}
$da_domain_db

$domain.     14400   IN      MX      0 $domain.

~;
		close GH;


		# if we're *not* the default cP domain...
		if ( $cp_user{DNS} ne $domain ) {

			print "\n\t\tCopying files... ";

			# move cP-addon-domain-dir over to DA-domain-dir/public_html
			`mv ${ROOT_PATH}import/$incoming_user/homedir/public_html/$sub_dir ${ROOT_PATH}export/$incoming_user/domains/$domain/public_html`;
		}


		print "\n\t\tFTP Addresses... ";
		my $ftp_count = 0;
		my $ftp_list = '';

		# FTP beckons. Loop over cP-proftpdpasswd file
		open GH, "${ROOT_PATH}import/$incoming_user/proftpdpasswd";
		while ( my $fp = <GH> ) {
			my ($login, $passwd, $gibber1, $gibber2, $gibber3, $dir, $gibber4) = split /:/, $fp;
			my @dir = reverse split /\//, $dir;

			open HH, ">>${ROOT_PATH}export/$incoming_user/backup/$domain/ftp.passwd";

			# if this is the default domain *and* login-name equals cP-homedir, we're system
			if ( $domain eq $cp_user{DNS} && $dir[0] eq $login ) {
				print HH "$login=passwd=$passwd&type=system\n";
				$ftp_list .= "\n\t\t\to $login";
			}

			# if cP-homedir = this cP-domain's sub-dir, we're a domain ftp of $domain
			elsif ( $dir[0] eq $sub_dir ) {
				print HH "$login\@$domain=passwd=$passwd&type=domain\n";
				$ftp_list .= "\n\t\t\to $login\@$domain";
			}

			# if cP-homedir equals 'public_ftp', we're a ftp user
			elsif ( $dir[0] eq 'public_ftp' ) {
				print HH "$login\@$domain=passwd=$passwd&type=ftp\n";
				$ftp_list .= "\n\t\t\to $login\@$domain";
			}

			# otherwise, if our cP-homedir equals our $login, we're a standard user
			elsif ( $dir[0] eq $login && -e "${ROOT_PATH}export/$incoming_user/domains/$domain/public_html/$dir[0]" ) {
				print HH "$login\@$domain=passwd=$passwd&type=user\n";
				$ftp_list .= "\n\t\t\to $login\@$domain";
			}

			close HH;

			$ftp_count++;
		
		}
		close GH;

		print "($ftp_count converted)$ftp_list";


		print "\n\t\tPOP3/IMAP Accounts and data... ";
		my $mail_count = 0;
		my $mail_list = '';

		# transfer pop3's over to DA-backup-dir/$domain/email/passwd
		open GH, "${ROOT_PATH}import/$incoming_user/homedir/etc/$domain/shadow";
		open HH, ">${ROOT_PATH}export/$incoming_user/backup/$domain/email/passwd";
		while ( my $ml = <GH> ) {
			my ($login, $passwd, @extra) = split /:/, $ml;

			print HH "$login:$passwd\n";

			if ($login) {
				my $cP_mbox_domain_bit = $domain eq $cp_user{DNS} ? '' : "/$domain";

		   		$mail_list .= "\n\t\t\to $login\@$domain";

				# now mv over mailbox data
				if ( -e "${ROOT_PATH}import/$incoming_user/homedir/mail$cP_mbox_domain_bit/$login/inbox" ) {
					mkdir "${ROOT_PATH}export/$incoming_user/backup/$domain/email/data/pop",0755;
					`mv ${ROOT_PATH}import/$incoming_user/homedir/mail$cP_mbox_domain_bit/$login/inbox ${ROOT_PATH}export/$incoming_user/backup/$domain/email/data/pop/$login`;
				}

				# move Maildir data
				if ( -e "${ROOT_PATH}import/$incoming_user/homedir/mail/$domain/$login/maildirsize" ) { # used to check courierimapsubscribed
					mkdir "${ROOT_PATH}export/$incoming_user/backup/$domain/email/data/imap",0755;
					mkdir "${ROOT_PATH}export/$incoming_user/backup/$domain/email/data/imap/$login",0755;
					#mkdir "${ROOT_PATH}export/$incoming_user/backup/$domain/email/data/imap/$login/Maildir",0755;
					#`mv ${ROOT_PATH}import/$incoming_user/homedir/mail/$domain/$login/courierimapsubscribed ${ROOT_PATH}export/$incoming_user/backup/$domain/email/data/imap/$login/.mailboxlist`;
					`mv ${ROOT_PATH}import/$incoming_user/homedir/mail/$domain/$login ${ROOT_PATH}export/$incoming_user/backup/$domain/email/data/imap/$login/Maildir`;
					`cp ${ROOT_PATH}export/$incoming_user/backup/$domain/email/data/imap/$login/Maildir/courierimapsubscribed ${ROOT_PATH}export/$incoming_user/backup/$domain/email/data/imap/$login/.mailboxlist`;
				}

				$mail_count++;

			}

		}
		close HH;
		close GH;

		`rm -fr ${ROOT_PATH}import/$incoming_user/homedir/mail/$domain`;

		print "($mail_count converted)$mail_list";

		# create some empty files (to keep DA from croaking)...
		open GH, ">${ROOT_PATH}export/$incoming_user/backup/$domain/email/aliases"; close GH;
		open GH, ">${ROOT_PATH}export/$incoming_user/backup/$domain/email/autoresponder.conf"; close GH;
		open GH, ">${ROOT_PATH}export/$incoming_user/backup/$domain/email/vacation.conf"; close GH;
		open GH, ">${ROOT_PATH}export/$incoming_user/backup/$domain/email/email.conf"; close GH;


		$dom_count++;

	}
	close FH;



	# transfering top-level account email address Maildir data
	if ( -e "${ROOT_PATH}import/$incoming_user/homedir/mail/maildirsize" ) { # used to check courierimapsubscribed
		print "\n\tRoot IMAP mail data... ";

		# needs to go inside DA's home.tar.gz file:
		`mv ${ROOT_PATH}import/$incoming_user/homedir/mail ${ROOT_PATH}import/$incoming_user/homedir/Maildir`;
		`tar czfp ${ROOT_PATH}export/$incoming_user/backup/home.tar.gz -C ${ROOT_PATH}import/$incoming_user/homedir Maildir`;

	} else {
		print "\n\tNo Root IMAP mail data detected, skipping. ";
	}


	if ( -e "{ROOT_PATH}import/$incoming_user/homedir/.sqmaildata" ) {
		print "\n\tSquirrelmail preferences... ";
		`mv ${ROOT_PATH}import/$incoming_user/homedir/.sqmaildata ${ROOT_PATH}export/$incoming_user/backup/email_data/squirrelmail`;
	} else {
		print "\n\tNo Squirrelmail preferences detected, skipping. ";
	}


	print "\n\tCopying remaining files... ";

	# move remaining cP-public_html over to default-domain DA-public_html
	`mv ${ROOT_PATH}import/$incoming_user/homedir/public_html ${ROOT_PATH}export/$incoming_user/domains/$cp_user{DNS}/public_html`;

	# now for public_ftp, if we have that
	if ( $default{aftp} =~ /on/i ) {
		`mv ${ROOT_PATH}import/$incoming_user/homedir/public_ftp ${ROOT_PATH}export/$incoming_user/domains/$cp_user{DNS}/public_ftp`;
	}



	print "\n\tDomain pointers... ";
	my $dompoint_count = 0;

	# load 'n loop cP-domain-pointers...
	open FH, "${ROOT_PATH}import/$incoming_user/pds";
	while (<FH>) {
		chomp;
		my ($pointer, $extra) = split / /;

		# append cP-$pointer to DA-backup/$cp_user{DNS}/domain.pointers
		open GH, ">>${ROOT_PATH}export/$incoming_user/backup/$cp_user{DNS}/domain.pointers";
		print GH "$pointer\n";
		close GH;

		$dompoint_count++;
	}
	close FH;

	print "($dompoint_count converted)";


	# create DA-.shadow file
	$cp_shadow =~ s/\n//g;
	open FH, ">${ROOT_PATH}export/$incoming_user/backup/.shadow";
	print FH $cp_shadow;
	close FH;

	# and an empty DA-bandwidth.tally file
	open FH, ">${ROOT_PATH}export/$incoming_user/backup/bandwidth.tally"; close FH;

	# and another empty for user.usage (this will be recalculated by DA on nightly build.. I hope)
	open FH, ">${ROOT_PATH}export/$incoming_user/backup/user.usage"; close FH;


	print "\n\tTranslating any Crontab entries... ";
	my $ccounter = 0;

	# crontabs
	if ( -e "${ROOT_PATH}import/$incoming_user/cron/$incoming_user" ) {
		open FH, "${ROOT_PATH}import/$incoming_user/cron/$incoming_user";
		while (<FH>) {
			chomp;
			open NEW, ">>${ROOT_PATH}export/$incoming_user/backup/crontab.conf";
			print NEW "0=$ccounter $_\n";
			close NEW;
			$ccounter++;
		}
		close FH;
	}
	print "($ccounter converted)";



	print "\n\tMySQL Databases... ";
	my $db_count = 0;
	my $db_list = '';

	# MySQL user privileges - from cP-mysql.sql file

	# loop all databases
	# loop all users and associate with DB

	my (%users, %dbs);
	open FH, "${ROOT_PATH}import/$incoming_user/mysql.sql";
	while (<FH>) {
		chomp;

		if ( $_ =~ m/GRANT USAGE ON .+? TO '(.+?)'\@'(.+?)' IDENTIFIED BY PASSWORD '(.+?)';/ ) {
			my ($user, $host, $pass) = ($1, $2, $3);
			$users{"$user\@$host"} = $pass;
		}
		# was ALL PRIVILEGES
		elsif ( $_ =~ m/GRANT .+? ON \`(.+?)\`.* TO '(.+?)'\@'(.+?)';/ ) {
			my ($db, $user, $host) = ($1, $2, $3);
			$db =~ s/\\_/_/g;
			push @{$dbs{$db}}, [$user, $host];
		}


	}
	close FH;

	while ( my ($db, $users) = each %dbs ) {

		my (@hosts, @users);
		my $out = '';

		$db_list .= "\n\t\to $db";

		for my $usrpair (@$users) {

			my ($user, $host) = ($usrpair->[0], $usrpair->[1]);

			if (! grep /^$host$/, @hosts ) {
				$db_list .= "\n\t\t\t+ host $host";
				push @hosts, $host;
			}

			if (! grep /^$user$/, @users ) {
				$out .= "$user=alter_priv=Y&create_priv=Y&create_tmp_table_priv=Y&delete_priv=Y&drop_priv=Y&grant_priv=N&index_priv=Y&insert_priv=Y&lock_tables_priv=Y&passwd=".$users{"$user\@$host"}."&references_priv=Y&select_priv=Y&update_priv=Y\n";
				push @users, $user;

				$db_list .= "\n\t\t\t+ user $user";
			}
		}

		open FH, ">${ROOT_PATH}export/$incoming_user/backup/$db.conf";
		for ( my $i = 0; $i < @hosts; $i++) {
			print FH "accesshosts=$i=$hosts[$i]\n";
		}
		print FH $out;
		close FH;

	}

	`rm -f ${ROOT_PATH}export/$incoming_user/mysql/${incoming_user}_.conf ${ROOT_PATH}import/$incoming_user/mysql/$incoming_user.sql`;
	
	# copy .sql backups from cP to DA :)
	opendir FD, "${ROOT_PATH}import/$incoming_user/mysql";
	while ( my $db = readdir FD ) {
		if ( $db !~ /\A\.\.?\Z/ ) {
			`cp ${ROOT_PATH}import/$incoming_user/mysql/$db ${ROOT_PATH}export/$incoming_user/backup/$db`;
			
			#needed to laod into memory:
			#open NEW, ">${ROOT_PATH}export/$incoming_user/backup/$db";
			#open OLD, "${ROOT_PATH}import/$incoming_user/mysql/$db";
			#print NEW do { local $/; <OLD> };
			#close OLD;
			#close NEW;

			$db =~ s/\.sql$//;
			if (!$dbs{$db}) {
				$db_list .= "\n\t\to $db";
			}

			$db_count++;
		}
	}
	closedir FD;

	print "($db_count converted)$db_list";
	
	
	# if no contact email provided, use username@primary-domain.tld
	$cp_email = "$incoming_user\@$cp_user{DNS}" if $cp_email eq '';


	my %da_user = (
			account		=>	$default{account},
			aftp		=>	$default{aftp},
			bandwidth	=>	$cp_user{BWLIMIT} ? int($cp_user{BWLIMIT}/1048576) : 'unlimited', # cPanel uses Bytes; DA uses MBytes
			cgi			=>	$default{cgi},
			creator		=>	$default{creator},
			dnscontrol	=>	$default{dnscontrol},
			docsroot	=>	$default{docsroot},
			domain		=>	$cp_user{DNS},
			domainptr	=>	$cp_user{MAXPARK} || 'unlimited',
			email		=>	$cp_email,
			ftp			=>	$cp_user{MAXFTP},
			ip			=>	$default{ip},
			mysql		=>	$cp_user{MAXSQL} || 'unlimited',
			name		=>	$incoming_user,
			nemailf		=>	$cp_user{MAXPOP} || 'unlimited',
			nemailml	=>	$cp_user{MAXLST} || 'unlimited',
			nemailr		=>	$default{nemailr},
			nemails		=>	$default{nemails}, # MAXPOP = accounts
			ns1			=>	$default{ns1},
			ns2			=>	$default{ns2},
			nsubdomains	=>	$cp_user{MAXSUB} || 'unlimited',
			package		=>	$default{package},
			php			=>	$default{php},
			quota		=>	$cp_quota,
			sentwarning	=>	'no',
			skin		=>	$default{skin},
			ssh			=>	$default{ssh},
			ssl			=>	$default{ssl},
			suspend_at_limit => $default{suspend_at_limit},
			suspended	=>	$default{suspended},
			username	=>	$incoming_user,
			usertype	=>	'user',
			vdomains	=>	$cp_user{MAXADDON} || 'unlimited',
			zoom		=>	$default{zoom},
		);
		
	write_conf("${ROOT_PATH}export/$incoming_user/backup/user.conf",\%da_user);

	#`chown -r $incoming_user ${ROOT_PATH}export/$incoming_user`;


	print "\n\tCreating DirectAdmin tarball... ";

	# create DA-.tar.gz
	#`tar czfC ${ROOT_PATH}export/$incoming_user.tar.gz ${ROOT_PATH}export/$incoming_user . --owner=$incoming_user`;
	#`chown -R $incoming_user:$incoming_user ${ROOT_PATH}export/$incoming_user`;
	`tar czfp ${ROOT_PATH}export/$incoming_user.tar.gz -C ${ROOT_PATH}export/$incoming_user domains backup`;


	print "\n\tCleaning up... ";
	
	# clean up time
	`rm -fr ${ROOT_PATH}import/$incoming_user ${ROOT_PATH}export/$incoming_user`;


	print "\n\tSuccess!\n\n";
}


sub fail {
	print "FAILED\n";

	if ($_[0]) {
		print "\t$_[0]\n";
	}

	print "\n";

	exit;
}


sub read_conf {
	my $file = shift;
	my %return;

	open RC, $file;
	while (<RC>) {
		chomp;
		my ($key,$value) = split /=/, $_, 2;
		$return{$key} = $value;
	}
	close RC;

	return %return;
}


sub write_conf {
	my ($fn, $r_data) = @_;

	open WC, ">$fn";
	while ( my ($key, $value) = each %$r_data ) {
		print WC "$key=$value\n";
	}
	close WC;
}