package AN::Common;
#
# This will store general purpose functions.
# 

use strict;
use warnings;
use Encode;
use CGI;
use utf8;
use IO::Handle;
use Term::ReadKey;
use XML::Simple qw(:strict);

use AN::Cluster;

# Set static variables.
my $THIS_FILE = 'AN::Cluster.pm';


# This takes an integer and, if it is a valid CIDR range, returns the 
# dotted-decimal equivalent. If it's not, it returns '#!INVALID!#'.
sub convert_cidr_to_dotted_decimal
{
	my ($conf, $netmask) = @_;
	
	if ($netmask =~ /^\d{1,2}$/)
	{
		# Make sure it's a (useful) CIDR
		if (($netmask >= 1) && ($netmask <= 32))
		{
			# 0 and 31 are useless in Striker
			if    ($netmask == 1)  { $netmask = "128.0.0.0"; }
			elsif ($netmask == 2)  { $netmask = "192.0.0.0"; }
			elsif ($netmask == 3)  { $netmask = "224.0.0.0"; }
			elsif ($netmask == 4)  { $netmask = "240.0.0.0"; }
			elsif ($netmask == 5)  { $netmask = "248.0.0.0"; }
			elsif ($netmask == 6)  { $netmask = "252.0.0.0"; }
			elsif ($netmask == 7)  { $netmask = "254.0.0.0"; }
			elsif ($netmask == 8)  { $netmask = "255.0.0.0"; }
			elsif ($netmask == 9)  { $netmask = "255.128.0.0"; }
			elsif ($netmask == 10) { $netmask = "255.192.0.0"; }
			elsif ($netmask == 11) { $netmask = "255.224.0.0"; }
			elsif ($netmask == 12) { $netmask = "255.240.0.0"; }
			elsif ($netmask == 13) { $netmask = "255.248.0.0"; }
			elsif ($netmask == 14) { $netmask = "255.252.0.0"; }
			elsif ($netmask == 15) { $netmask = "255.254.0.0"; }
			elsif ($netmask == 16) { $netmask = "255.255.0.0"; }
			elsif ($netmask == 17) { $netmask = "255.255.128.0"; }
			elsif ($netmask == 18) { $netmask = "255.255.192.0"; }
			elsif ($netmask == 19) { $netmask = "255.255.224.0"; }
			elsif ($netmask == 20) { $netmask = "255.255.240.0"; }
			elsif ($netmask == 21) { $netmask = "255.255.248.0"; }
			elsif ($netmask == 22) { $netmask = "255.255.252.0"; }
			elsif ($netmask == 23) { $netmask = "255.255.254.0"; }
			elsif ($netmask == 24) { $netmask = "255.255.255.0"; }
			elsif ($netmask == 25) { $netmask = "255.255.255.128"; }
			elsif ($netmask == 26) { $netmask = "255.255.255.192"; }
			elsif ($netmask == 27) { $netmask = "255.255.255.224"; }
			elsif ($netmask == 28) { $netmask = "255.255.255.240"; }
			elsif ($netmask == 29) { $netmask = "255.255.255.248"; }
			elsif ($netmask == 30) { $netmask = "255.255.255.252"; }
			elsif ($netmask == 32) { $netmask = "255.255.255.255"; }
			else
			{
				$netmask = "#!INVALID!#";
			}
		}
		else
		{
			$netmask = "#!INVALID!#";
		}
	}
	
	return($netmask);
}

# This creates an 'expect' script for an rsync call.
sub create_rsync_wrapper
{
	my ($conf, $node) = @_;
	
	my $cluster = $conf->{cgi}{cluster};
	my $root_pw = $conf->{clusters}{$cluster}{root_pw};
	my $sc = "
echo '#!/usr/bin/expect' > ~/rsync.$node
echo 'set timeout 3600' >> ~/rsync.$node
echo 'eval spawn rsync \$argv' >> ~/rsync.$node
echo 'expect  \"*?assword:\" \{ send \"$root_pw\\\\n\" \}' >> ~/rsync.$node
echo 'expect eof' >> ~/rsync.$node
chmod 755 ~/rsync.$node;";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
	my $fh = IO::Handle->new();
	open ($fh, "$sc 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$sc], error was: $!\n";
	while(<$fh>)
	{
		print $_;
	}
	$fh->close();
	
	return(0);
}

# This checks to see if we've see the peer before and if not, add it's ssh
# fingerprint to known_hosts
sub test_ssh_fingerprint
{
	my ($conf, $node) = @_;
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; test_ssh_fingerprint(); node: [$node]\n");
	
	my $failed  = 0;
	my $cluster = $conf->{cgi}{cluster};
	my $root_pw = $conf->{clusters}{$cluster}{root_pw};
	my $sc = "ssh root\@$node \"uname -a\"";
	AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; Calling: [$sc]\n");
	my $fh = IO::Handle->new();
	open ($fh, "$sc 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$sc], error was: $!\n";
	while(<$fh>)
	{
		chomp;
		my $line =  $_;
		   $line =~ s/\n/ /g;
		   $line =~ s/\r/ /g;
		   $line =~ s/\s+$//;
		AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
		if ($line =~ /The authenticity of host/)
		{
			# Add fingerprint to known_hosts
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; authenticity of host message\n");
			my $message = get_string($conf, {key => "message_0279", variables => {
				node	=>	$node,
			}});
			print template($conf, "common.html", "generic-note", {
				message	=>	$message,
			});
			#print "Trying to add the node: <span class=\"fixed_width\">$node</span>'s ssh fingerprint to my list of known hosts...<br />";
			#print template($conf, "common.html", "shell-output-header");
			my $fh = IO::Handle->new();
			my $sc = "$conf->{path}{'ssh-keyscan'} $node >> ~/.ssh/known_hosts";
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; sc: [$sc]\n");
			open ($fh, "$sc 2>&1 |") or die "$THIS_FILE ".__LINE__."; Failed to call: [$sc], error was: $!\n";
			while(<$fh>)
			{
				chomp;
				my $line = $_;
				AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; line: [$line]\n");
				#print template($conf, "common.html", "shell-call-output", {
				#	line	=>	$line,
				#});
			}
			$fh->close();
			#print template($conf, "common.html", "shell-output-footer");
			#$message = get_string($conf, {key => "message_0120"});
			#print template($conf, "common.html", "generic-note", {
			#	message	=>	$message,
			#});
			sleep 5;
		}
		elsif ($line =~ /Host key verification failed/)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; host key verification failed message\n");
			my $message = get_string($conf, {key => "message_0360", variables => {
				node	=>	$node,
			}});
			print template($conf, "common.html", "generic-error", {
				message	=>	$message,
			});
			$failed  = 1;
		}
		elsif ($line =~ /Offending key .*? (.*?):(\d+)/)
		{
			AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; offending key message\n");
			my $file = $1;
			my $line = $2;
			my $message = get_string($conf, {key => "message_0358", variables => {
				node	=>	$node,
				file	=>	$file,
				line	=>	$line,
			}});
			print template($conf, "common.html", "generic-error", {
				message	=>	$message,
			});
			$failed  = 1;
		}
	}
	$fh->close();

	return($failed);
}

# This simply sorts out the current directory the program is running in.
sub get_current_directory
{
	my ($conf) = @_;
	
	my $current_dir = "/var/www/html/";
	if ($ENV{DOCUMENT_ROOT})
	{
		$current_dir = $ENV{DOCUMENT_ROOT};
	}
	elsif ($ENV{CONTEXT_DOCUMENT_ROOT})
	{
		$current_dir = $ENV{CONTEXT_DOCUMENT_ROOT};
	}
	elsif ($ENV{PWD})
	{
		$current_dir = $ENV{PWD};
	}
	
	return($current_dir);
}

# This returns the date and time based on the given unix-time.
sub get_date_and_time
{
	my ($conf, $variables) = @_;
	
	# Set default values then check for passed parameters to over-write
	# them with.
	my $offset          = $variables->{offset}          ? $variables->{offset}          : 0;
	my $use_time        = $variables->{use_time}        ? $variables->{use_time}        : time;
	my $require_weekday = $variables->{require_weekday} ? $variables->{require_weekday} : 0;
	my $skip_weekends   = $variables->{skip_weekends}   ? $variables->{skip_weekends}   : 0;
	my $use_24h         = $variables->{use_24h}         ? $variables->{use_24h}         : $conf->{sys}{use_24h};
	
	# Do my initial calculation.
	my %time          = ();
	my $adjusted_time = $use_time + $offset;
	($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);

	# If I am set to skip weekends and I land on a weekend, simply add 48
	# hours. This is useful when you need to move X-weekdays.
	if (($skip_weekends) && ($offset))
	{
		# First thing I need to know is how many weekends pass between
		# now and the requested date. So to start, how many days are we
		# talking about?
		my $difference   = 0;			# Hold the accumulated days in seconds.
		my $local_offset = $offset;		# Local offset I can mess with.
		my $day          = 24 * 60 * 60;	# For clarity.
		my $week         = $day * 7;		# For clarity.
		
		# As I proceed, 'local_time' will be subtracted as I account
		# for time and 'difference' will increase to account for known
		# weekend days.
		if ($local_offset =~ /^-/)
		{
			### Go back in time...
			$local_offset =~ s/^-//;
			
			# First, how many seconds have passed today?
			my $seconds_passed_today = $time{sec} + ($time{min} * 60) + ($time{hour} * 60 * 60);
			
			# Now, get the number of seconds in the offset beyond
			# an even day. This is compared to the seconds passed
			# in this day. If greater, I count an extra day.
			my $local_offset_second_over_day =  $local_offset % $day;
			$local_offset                    -= $local_offset_second_over_day;
			my $local_offset_days            =  $local_offset / $day;
			$local_offset_days++ if $local_offset_second_over_day > $seconds_passed_today;
			
			# If the number of days is greater than one week, add
			# two days to the 'difference' for every seven days and
			# reduce 'local_offset_days' to the number of days
			# beyond the given number of weeks.
			my $local_offset_remaining_days = $local_offset_days;
			if ($local_offset_days > 7)
			{
				# Greater than a week, do the math.
				$local_offset_remaining_days =  $local_offset_days % 7;
				$local_offset_days           -= $local_offset_remaining_days;
				my $weeks_passed             =  $local_offset_days / 7;
				$difference                  += ($weeks_passed * (2 * $day));
			}
			
			# If I am currently in a weekend, add two days.
			if (($time{wday} == 6) || ($time{wday} == 0))
			{
				$difference += (2 * $day);
			}
			else
			{
				# Compare 'local_offset_remaining_days' to
				# today's day. If greater, I've passed a
				# weekend and need to add two days to
				# 'difference'.
				my $today_day = (localtime())[6];
				if ($local_offset_remaining_days > $today_day)
				{
					$difference+=(2 * $day);
				}
			}
			
			# If I have a difference, recalculate the offset date.
			if ($difference)
			{
				my $new_offset = ($offset - $difference);
				$adjusted_time = ($use_time + $new_offset);
				($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);
			}
		}
		else
		{
			### Go forward in time...
			# First, how many seconds are left in today?
			my $left_hours            = 23 - $time{hour};
			my $left_minutes          = 59 - $time{min};
			my $left_seconds          = 59 - $time{sec};
			my $seconds_left_in_today = $left_seconds + ($left_minutes * 60) + ($left_hours * 60 * 60);
			
			# Now, get the number of seconds in the offset beyond
			# an even day. This is compared to the seconds left in
			# this day. If greater, I count an extra day.
			my $local_offset_second_over_day =  $local_offset % $day;
			$local_offset                    -= $local_offset_second_over_day;
			my $local_offset_days            =  $local_offset / $day;
			$local_offset_days++ if $local_offset_second_over_day > $seconds_left_in_today;
			
			# If the number of days is greater than one week, add
			# two days to the 'difference' for every seven days and
			# reduce 'local_offset_days' to the number of days
			# beyond the given number of weeks.
			my $local_offset_remaining_days = $local_offset_days;
			if ($local_offset_days > 7)
			{
				# Greater than a week, do the math.
				$local_offset_remaining_days =  $local_offset_days % 7;
				$local_offset_days           -= $local_offset_remaining_days;
				my $weeks_passed             =  $local_offset_days / 7;
				$difference                  += ($weeks_passed * (2 * $day));
			}
			
			# If I am currently in a weekend, add two days.
			if (($time{wday} == 6) || ($time{wday} == 0))
			{
				$difference += (2 * $day);
			}
			else
			{
				# Compare 'local_offset_remaining_days' to
				# 5 minus today's day to get the number of days
				# until the weekend. If greater, I've crossed a
				# weekend and need to add two days to
				# 'difference'.
				my $today_day       = (localtime())[6];
				my $days_to_weekend = 5 - $today_day;
				if ($local_offset_remaining_days > $days_to_weekend)
				{
					$difference += (2 * $day);
				}
			}
			
			# If I have a difference, recalculate the offset date.
			if ($difference)
			{
				my $new_offset = ($offset + $difference);
				$adjusted_time = ($use_time + $new_offset);
				($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);
			}
		}
	}

	# If the 'require_weekday' is set and if 'time{wday}' is 0 (Sunday) or
	# 6 (Saturday), set or increase the offset by 24 or 48 hours.
	if (($require_weekday) && (($time{wday} == 0) || ($time{wday} == 6)))
	{
		# The resulting day is a weekend and the require weekday was
		# set.
		$adjusted_time = $use_time + ($offset + (24 * 60 * 60));
		($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);
		
		# I don't check for the date and adjust automatically because I
		# don't know if I am going forward or backwards in the calander.
		if (($time{wday} == 0) || ($time{wday} == 6))
		{
			# Am I still ending on a weekday?
			$adjusted_time = $use_time + ($offset + (48 * 60 * 60));
			($time{sec}, $time{min}, $time{hour}, $time{mday}, $time{mon}, $time{year}, $time{wday}, $time{yday}, $time{isdst}) = localtime($adjusted_time);
		}
	}

	# Increment the month by one.
	$time{mon}++;
	
	# Parse the 12/24h time components.
	if ($use_24h)
	{
		# 24h time.
		$time{pad_hour} = sprintf("%02d", $time{hour});
		$time{suffix}   = "";
	}
	else
	{
		# 12h am/pm time.
		if ( $time{hour} == 0 )
		{
			$time{pad_hour} = 12;
			$time{suffix}   = " am";
		}
		elsif ( $time{hour} < 12 )
		{
			$time{pad_hour} = $time{hour};
			$time{suffix}   = " am";
		}
		else
		{
			$time{pad_hour} = ($time{hour}-12);
			$time{suffix}   = " pm";
		}
		$time{pad_hour} = sprintf("%02d", $time{pad_hour});
	}
	
	# Now parse the global components.
	$time{pad_min}  = sprintf("%02d", $time{min});
	$time{pad_sec}  = sprintf("%02d", $time{sec});
	$time{year}     = ($time{year} + 1900);
	$time{pad_mon}  = sprintf("%02d", $time{mon});
	$time{pad_mday} = sprintf("%02d", $time{mday});
	$time{mon}++;
	
	my $date = $time{year}.$conf->{sys}{date_seperator}.$time{pad_mon}.$conf->{sys}{date_seperator}.$time{pad_mday};
	my $time = $time{pad_hour}.$conf->{sys}{time_seperator}.$time{pad_min}.$conf->{sys}{time_seperator}.$time{pad_sec}.$time{suffix};
	
	return($date, $time);
}

# This pulls out all of the configured languages from the 'strings.xml' file
# and returns them as an array reference with comma-separated "key,name" 
# values.
sub get_languages
{
	my ($conf) = @_;
	my $language_options = [];
	
	foreach my $key (sort {$a cmp $b} keys %{$conf->{string}{lang}})
	{
		my $name = $conf->{string}{lang}{$key}{lang}{long_name};
		push @{$language_options}, "$key,$name";
	}
	
	return($language_options);
}

# This takes a string key and returns the string for the currently active
# language.
sub get_string
{
	my ($conf, $vars) = @_;
	#print __LINE__."; vars: [$vars]\n";
	
	my $key       = $vars->{key};
	my $language  = $vars->{language}  ? $vars->{language}  : $conf->{sys}{language};
	my $variables = $vars->{variables} ? $vars->{variables} : "";
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; key: [$key], language: [$language], variables: [$variables]\n");
	
	if (not $key)
	{
		hard_die($conf, $THIS_FILE, __LINE__, 2, "No string key was passed into common.lib's 'get_string()' function.\n");
	}
	if (not $language)
	{
		hard_die($conf, $THIS_FILE, __LINE__, 3, "No language key was set when trying to build a string in common.lib's 'get_string()' function.\n");
	}
	elsif (not exists $conf->{string}{lang}{$language})
	{
		hard_die($conf, $THIS_FILE, __LINE__, 4, "The language key: [$language] does not exist in the 'strings.xml' file.\n");
	}
	my $say_language = $language;
	#print __LINE__."; 2. say_language: [$say_language]\n";
	if ($conf->{string}{lang}{$language}{lang}{long_name})
	{
		$say_language = "$language ($conf->{string}{lang}{$language}{lang}{long_name})";
		#print __LINE__."; 2. say_language: [$say_language]\n";
	}
	if (($variables) && (ref($variables) ne "HASH"))
	{
		hard_die($conf, $THIS_FILE, __LINE__, 5, "The 'variables' string passed into common.lib's 'get_string()' function is not a hash reference. The string's data is: [$variables].\n");
	}
	
	#print "$THIS_FILE ".__LINE__."; string::lang::${language}::key::${key}::content: [$conf->{string}{lang}{$language}{key}{$key}{content}]\n";
	if (not exists $conf->{string}{lang}{$language}{key}{$key}{content})
	{
		#use Data::Dumper; print Dumper %{$conf->{string}{lang}{$language}};
		hard_die($conf, $THIS_FILE, __LINE__, 6, "The 'string' generated by common.lib's 'get_string()' function is undefined.<br />This passed string key: '$key' for the language: '$say_language' may not exist in the 'strings.xml' file.\n");
	}
	
	# Grab the string and start cleaning it up.
	my $string = $conf->{string}{lang}{$language}{key}{$key}{content};
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; 1. string: [$string]\n");
	#print __LINE__."; 3. string: [$string]\n";
	
	# This clears off the new-line and trailing white-spaces caused by the
	# indenting of the '</key>' field in the words XML file when printing
	# to the command line.
	$string =~ s/^\n//;
	$string =~ s/\n(\s+)$//;
	#print __LINE__."; 4. string: [$string]\n";
	
	# Process all the #!...!# escape variables.
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> string: [$string]\n");
	($string) = process_string($conf, $string, $variables);
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << string: [$string]\n");
	
	#print "$THIS_FILE ".__LINE__."; key: [$key], language: [$language]\n";
	return($string);
}

# This is a wrapper for 'get_string' that simply calls 'wrap_string()' before returning.
sub get_wrapped_string
{
	my ($conf, $vars) = @_;
	
	#print __LINE__."; vars: [$vars]\n";
	my $string = wrap_string($conf, get_string($conf, $vars));
	
	return($string);
}

# This funtion does not try to parse anything, use templates or what have you.
# It's very close to a simple 'die'. This should be used as rarely as possible
# as translations can't be used.
sub hard_die
{
	my ($conf, $file, $line, $exit_code, $message) = @_;
	
	$file      = "--" if not defined $file;
	$line      = 0    if not defined $line;
	$exit_code = 999  if not defined $exit_code;
	$message   = "?"  if not defined $message;
	
	# This can't be skinned or translated. :(
	print "
	<div name=\"hard_die\">
	Fatal error: [<span class=\"code\">$exit_code</span>] in file: [<span class=\"code\">$file</span>] at line: [<span class=\"code\">$line</span>]!<br />
	$message<br />
	Exiting.<br />
	</div>
	";
	
	exit ($exit_code);
}

# This initializes a call; reads variables, etc.
sub initialize
{
	# Set default configuration variable values
	my ($conf) = initialize_conf();
	
	# First thing first, initialize the web session.
	initialize_http($conf);

	# First up, read in the default strings file.
	read_strings($conf, $conf->{path}{words_common});
	read_strings($conf, $conf->{path}{words_file});

	# Read in the configuration file. If the file doesn't exist, initial 
	# setup will be triggered.
	read_configuration_file($conf);
	
	return($conf);
}

# Set default configuration variable values
sub initialize_conf
{
	# Setup (sane) defaults
	my $conf={
		nodes			=>	"",
		check_using_node	=>	"",
		up_nodes		=>	[],
		online_nodes		=>	[],
		handles			=>	{
			'log'			=>	"",
		},
		path			=>	{
			'striker_files'		=>	"/var/www/home",
			'striker_cache'		=>	"/var/www/home/cache",
			striker_conf		=>	"/etc/striker/striker.conf",
			apache_manifests_dir	=>	"/var/www/html/manifests",
			apache_manifests_url	=>	"/manifests",
			backup_config		=>	"/var/www/html/striker-backup_#!hostname!#_#!date!#.txt",	# Remember to update the sys::backup_url value below if you change this
			'call_gather-system-info'	=>	"/var/www/tools/call_gather-system-info",
			cat			=>	"/bin/cat",
			ccs			=>	"/usr/sbin/ccs",
			cluster_conf		=>	"/etc/cluster/cluster.conf",
			clusvcadm		=>	"/usr/sbin/clusvcadm",
			cp			=>	"/bin/cp",
			email_password_file	=>	"/var/www/tools/email_pw.txt",
			expect			=>	"/usr/bin/expect",
			fence_ipmilan		=>	"/sbin/fence_ipmilan",
			gethostip		=>	"/bin/gethostip",
			'grep'			=>	"/bin/grep",
			guacamole_config	=>	"/etc/guacamole/noauth-config.xml",
			home			=>	"/var/www/home/",
			hostname		=>	"/bin/hostname",
			hosts			=>	"/etc/hosts",
			ifconfig		=>	"/sbin/ifconfig",
			'log'			=>	"/var/log/striker.log",
			lvdisplay		=>	"/sbin/lvdisplay",
			ping			=>	"/usr/bin/ping",
			restart_guacd		=>	"/var/www/tools/restart_guacd",
			restart_tomcat		=>	"/var/www/tools/restart_tomcat6",
			ssh_config		=>	"/etc/ssh/ssh_config",
			sync			=>	"/bin/sync",
			virsh			=>	"/usr/bin/virsh",
			screen			=>	"/usr/bin/screen",
			shared			=>	"/shared/files/",	# This is hard-coded in the file delete function.
			status			=>	"/var/www/home/status/",
			media			=>	"/var/www/home/media/",
			check_dvd		=>	"/var/www/tools/check_dvd",
			do_dd			=>	"/var/www/tools/do_dd",
			rsync			=>	"/usr/bin/rsync",
			skins			=>	"../html/skins/",
			tput			=>	"/usr/bin/tput",
			words_common		=>	"Data/common.xml",
			words_file		=>	"Data/strings.xml",
			log_file		=>	"/var/log/striker.log",
			config_file		=>	"/etc/striker/striker.conf",	# TODO: Why is this here?!
			'ssh-keyscan'		=>	"/usr/bin/ssh-keyscan",
		},
		args			=>	{
			check_dvd		=>	"--dvd --no-cddb --no-device-info --no-disc-mode --no-vcd",
			rsync			=>	"-av --partial",
		},
		sys			=>	{
			backup_url		=>	"/striker-backup_#!hostname!#_#!date!#.txt",
			error_limit		=>	10000,
			language		=>	"en_CA",
			html_lang		=>	"en",
			skin			=>	"alteeve",
			version			=>	"1.1.7",
			log_level		=>	3,
			use_24h			=>	1,			# Set to 0 for am/pm time, 1 for 24h time
			date_seperator		=>	"-",			# Should put these in the strings.xml file
			time_seperator		=>	":",
			log_language		=>	"en_CA",
			system_timezone		=>	"America/Toronto",
			output			=>	"web",
		},
		# Config values needed to managing strings
		strings				=>	{
			encoding			=>	"",
			force_utf8			=>	0,
			xml_version			=>	"",
		},
		# The actual strings
		string				=>	{},
		url				=>	{
			skins				=>	"/skins",
			cgi				=>	"/cgi-bin",
		},
		'system'		=>	{
			dd_block_size		=>	"1M",
			debug			=>	1,
			username		=>	getpwuid( $< ),
			config_read		=>	0,
			up_nodes		=>	0,
			online_nodes		=>	0,
			show_nodes		=>	0,
			footer_printed		=>	0,
			show_refresh		=>	1,
			root_password		=>	"",
			ignore_missing_vm	=>	0,
			# ~3 GiB, but in practice more because it will round down the
			# available RAM before subtracting this to leave the user with
			# an even number of GiB or RAM to allocate to servers.
			unusable_ram		=>	(3 * (1024 ** 3)),
			os_variant		=>	[
				"win7#!#Microsoft Windows 7",
				"win7#!#Microsoft Windows 8",
				"vista#!#Microsoft Windows Vista",
				"winxp64#!#Microsoft Windows XP (x86_64)",
				"winxp#!#Microsoft Windows XP",
				"win2k#!#Microsoft Windows 2000",
				"win2k8#!#Microsoft Windows Server 2008 (R2)",
				"win2k8#!#Microsoft Windows Server 2012 (R2)",
				"win2k3#!#Microsoft Windows Server 2003",
				"openbsd4#!#OpenBSD 4.x",
				"freebsd8#!#FreeBSD 8.x",
				"freebsd7#!#FreeBSD 7.x",
				"freebsd6#!#FreeBSD 6.x",
				"solaris9#!#Sun Solaris 9",
				"solaris10#!#Sun Solaris 10",
				"opensolaris#!#Sun OpenSolaris",
				"netware6#!#Novell Netware 6",
				"netware5#!#Novell Netware 5",
				"netware4#!#Novell Netware 4",
				"msdos#!#MS-DOS",
				"generic#!#Generic",
				"debianwheezy#!#Debian Wheezy",
				"debiansqueeze#!#Debian Squeeze",
				"debianlenny#!#Debian Lenny",
				"debianetch#!#Debian Etch",
				"fedora18#!#Fedora 18",
				"fedora17#!#Fedora 17",
				"fedora16#!#Fedora 16",
				"fedora15#!#Fedora 15",
				"fedora14#!#Fedora 14",
				"fedora13#!#Fedora 13",
				"fedora12#!#Fedora 12",
				"fedora11#!#Fedora 11",
				"fedora10#!#Fedora 10",
				"fedora9#!#Fedora 9",
				"fedora8#!#Fedora 8",
				"fedora7#!#Fedora 7",
				"fedora6#!#Fedora Core 6",
				"fedora5#!#Fedora Core 5",
				"mageia1#!#Mageia 1 and later",
				"mes5.1#!#Mandriva Enterprise Server 5.1 and later",
				"mes5#!#Mandriva Enterprise Server 5.0",
				"mandriva2010#!#Mandriva Linux 2010 and later",
				"mandriva2009#!#Mandriva Linux 2009 and earlier",
				"rhel7#!#Red Hat Enterprise Linux 7",
				"rhel6#!#Red Hat Enterprise Linux 6",
				"rhel5.4#!#Red Hat Enterprise Linux 5.4 or later",
				"rhel5#!#Red Hat Enterprise Linux 5",
				"rhel4#!#Red Hat Enterprise Linux 4",
				"rhel3#!#Red Hat Enterprise Linux 3",
				"rhel2.1#!#Red Hat Enterprise Linux 2.1",
				"sles11#!#Suse Linux Enterprise Server 11",
				"sles10#!#Suse Linux Enterprise Server",
				"opensuse12#!#openSuse 12",
				"opensuse11#!#openSuse 11",
				"ubuntuquantal#!#Ubuntu 12.10 (Quantal Quetzal)",
				"ubuntuprecise#!#Ubuntu 12.04 LTS (Precise Pangolin)",
				"ubuntuoneiric#!#Ubuntu 11.10 (Oneiric Ocelot)",
				"ubuntunatty#!#Ubuntu 11.04 (Natty Narwhal)",
				"ubuntumaverick#!#Ubuntu 10.10 (Maverick Meerkat)",
				"ubuntulucid#!#Ubuntu 10.04 LTS (Lucid Lynx)",
				"ubuntukarmic#!#Ubuntu 9.10 (Karmic Koala)",
				"ubuntujaunty#!#Ubuntu 9.04 (Jaunty Jackalope)",
				"ubuntuintrepid#!#Ubuntu 8.10 (Intrepid Ibex)",
				"ubuntuhardy#!#Ubuntu 8.04 LTS (Hardy Heron)",
				"virtio26#!#Generic 2.6.25 or later kernel with virtio",
				"generic26#!#Generic 2.6.x kernel",
				"generic24#!#Generic 2.4.x kernel",
			],
		},
	};
	
	return($conf);
}

# At this point in time, all this does is print the content type needed for
# printing to browsers.
sub initialize_http
{
	my ($conf) = @_;
	
	print "Content-type: text/html; charset=utf-8\n\n";
	
	return(0);
}

# This takes a completed string and inserts variables into it as needed.
sub insert_variables_into_string
{
	my ($conf, $string, $variables) = @_;
	
	my $i = 0;
	#print "$THIS_FILE ".__LINE__."; string: [$string], variables: [$variables]\n";
	while ($string =~ /#!variable!(.+?)!#/s)
	{
		my $variable = $1;
		#print "$THIS_FILE ".__LINE__."; variable [$variable]: [$variables->{$variable}]\n";
		if (not defined $variables->{$variable})
		{
			# I can't expect there to always be a defined value in
			# the variables array at any given position so if it's
			# blank I blank the key.
			$string =~ s/#!variable!$variable!#//;
		}
		else
		{
			my $value = $variables->{$variable};
			chomp $value;
			$string =~ s/#!variable!$variable!#/$value/;
		}
		
		# Die if I've looped too many times.
		if ($i > $conf->{sys}{error_limit})
		{
			hard_die($conf, $THIS_FILE, __LINE__, 7, "Infitie loop detected will inserting variables into the string: [$string]. If this is triggered erroneously, increase the 'sys::error_limit' value.\n");
		}
		$i++;
	}
	
	#print "$THIS_FILE ".__LINE__."; << string: [$string]\n";
	return($string);
}

# This reads in the configuration file.
sub read_configuration_file
{
	my ($conf) = @_;
	
	$conf->{raw}{config_file} = [];
	my $fh = IO::Handle->new();
	my $sc = "$conf->{path}{config_file}";
	open ($fh, "<$sc") or die "$THIS_FILE ".__LINE__."; Failed to read: [$sc], error was: $!\n";
	while (<$fh>)
	{
		chomp;
		my $line = $_;
		push @{$conf->{raw}{config_file}}, $line;
		next if not $line;
		next if $line !~ /=/;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		next if $line =~ /^#/;
		next if not $line;
		my ($var, $val) = (split/=/, $line, 2);
		$var =~ s/^\s+//;
		$var =~ s/\s+$//;
		$val =~ s/^\s+//;
		$val =~ s/\s+$//;
		next if (not $var);
		_make_hash_reference($conf, $var, $val);
	}
	$fh->close();
	
	return(0);
}

# This records log messages to the log file.
sub to_log
{
	my ($conf, $variables) = @_;
	
	my $line    = $variables->{line}    ? $variables->{line}    : "--";
	my $file    = $variables->{file}    ? $variables->{file}    : "--";
	my $level   = $variables->{level}   ? $variables->{level}   : 1;
	my $message = $variables->{message} ? $variables->{message} : "--";
	
	#print "<pre>record; line: [$line], file: [$file], level: [$level] (sys::log_level: [$conf->{sys}{log_level}]), message: [$message]</pre>\n";
	if ($conf->{sys}{log_level} >= $level)
	{
		my $fh = $conf->{handles}{'log'};
		if (not $fh)
		{
			$fh                     = IO::Handle->new();
			$conf->{handles}{'log'} = $fh;
			my $current_dir         = get_current_directory($conf);
			my $log_file            = $current_dir."/".$conf->{path}{log_file};
			if ($conf->{path}{log_file} =~ /^\//)
			{
				$log_file = $conf->{path}{log_file};
			}
			open ($fh, ">>$log_file") or hard_die($conf, $THIS_FILE, __LINE__, 13, "Unable to open the file: [$log_file] for writing. The error was: $!.\n");
			my ($date, $time)  = get_date_and_time($conf);
			my $say_log_header = get_string($conf, {language => $conf->{sys}{log_language}, key => "log_0001", variables => {
				date	=>	$date,
				'time'	=>	$time,
			}});
			print $fh "-=] $say_log_header\n";
		}
		print $fh "$file $line; $message";
	}
	
	return(0);
}

# This takes the name of a template file, the name of a template section within
# the file, an optional hash containing replacement variables to feed into the
# template and an optional hash containing variables to pass into strings, and
# generates a page to display formatted according to the page.
sub template
{
	my ($conf, $file, $template, $replace, $variables, $hide_template_name) = @_;
	$replace            = {} if not defined $replace;
	$variables          = {} if not defined $variables;
	$hide_template_name = 0 if not defined $hide_template_name;
	
	my @contents;
	# Down the road, I may want to have different suffixes depending on the
	# user's environment. For now, it'll always be ".html".
	my $current_dir   = get_current_directory($conf);
	my $template_file = $current_dir."/".$conf->{path}{skins}."/".$conf->{sys}{skin}."/".$file;
	
	# Make sure the file exists.
	if (not -e $template_file)
	{
		hard_die($conf, $THIS_FILE, __LINE__, 10, "The template file: [$template_file] does not appear to exist.\n");
	}
	elsif (not -r $template_file)
	{
		my $user  = getpwuid($<);
		hard_die($conf, $THIS_FILE, __LINE__, 11, "The template file: [$template_file] is not readable by the user this program is running as the user: [$user]. Please check the permissions on the template file and it's parent directory.\n");
	}
	
	# Read in the raw template.
	my $in_template = 0;
	my $read        = IO::Handle->new();
	my $shell_call  = "$template_file";
	open ($read, $shell_call) or hard_die($conf, $THIS_FILE, __LINE__, 1, "Failed to read: [$shell_call]. The error was: $!\n");
	binmode $read, ":utf8:";
	while (<$read>)
	{
		chomp;
		my $line = $_;
		
		if ($line =~ /<!-- start $template -->/)
		{
			$in_template = 1;
			next;
		}
		if ($line =~ /<!-- end $template -->/)
		{
			# Once I hit this, I am done.
			$in_template = 0;
			last;
		}
		if ($in_template)
		{
			# Read in the template.
			push @contents, $line;
		}
	}
	$read->close();
	
	# Now parse the contents for replacement keys.
	my $page = "";
	if (not $hide_template_name)
	{
		$page .= "<!-- Start template: [$template] from file: [$file] -->\n";
	}
	foreach my $string (@contents)
	{
		# Replace the '#!replace!...!#' substitution keys.
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> string: [$string]\n");
		($string) = process_string_replace($conf, $string, $replace, $template_file, $template);
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << string: [$string]\n");
		
		# Process all the #!...!# escape variables.
		#print "$THIS_FILE ".__LINE__."; >> string: [$string]\n";
		#print __LINE__."; >> file: [$file], template: [$template], string: [$string]\n";
		($string) = process_string($conf, $string, $variables);
		#print __LINE__."; << file: [$file], template: [$template], string: [$string\n";
		#print "$THIS_FILE ".__LINE__."; << string: [$string]\n";
		$page .= "$string\n";
	}
	if (not $hide_template_name)
	{
		$page .= "<!-- End template: [$template] from file: [$file] -->\n\n";
	}
	
	return($page);
}

# Process all the other #!...!# escape variables.
sub process_string
{
	my ($conf, $string, $variables) = @_;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> string: [$string]\n");
	#print __LINE__."; i. string: [$string], variables: [$variables]\n";
	
	# Insert variables into #!variable!x!# 
	my $i = 0;
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; >> string: [$string]\n");
	($string) = insert_variables_into_string($conf, $string, $variables);
	#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; << string: [$string]\n");
	
	while ($string =~ /#!(.+?)!#/s)
	{
		# Insert strings that are referenced in this string.
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; [$i], 2.\n");
		($string) = process_string_insert_strings($conf, $string, $variables);
		
		# Protect unmatchable keys.
		#print __LINE__."; [$i], 3.\n";
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; [$i], 3.\n");
		($string) = process_string_protect_escape_variables($conf, $string, "string");

		# Inject any 'conf' values.
		#AN::Cluster::record($conf, "$THIS_FILE ".__LINE__."; [$i], 4.\n");
		($string) = process_string_conf_escape_variables($conf, $string);
		
		# Die if I've looped too many times.
		if ($i > $conf->{sys}{error_limit})
		{
			hard_die($conf, $THIS_FILE, __LINE__, 8, "Infitie loop detected will processing escape variables in the string: [$string]. If this is triggered erroneously, increase the 'sys::error_limit' value. If you are a developer or translator, did you use '#!replace!...!#' when you meant to use '#!variable!...!#' in a string key?\n");
		}
		$i++;
	}

	# Restore and unrecognized substitution values.
	($string) = process_string_restore_escape_variables($conf, $string);
	#print __LINE__."; << string: [$string]\n";
	if ($string =~ /Etc\/GMT\+0/)
	{
		$conf->{i}++;
		die if $conf->{i} > 10;
	}
	
	return($string);
}

# This looks for #!string!...!# substitution variables.
sub process_string_insert_strings
{
	my ($conf, $string, $variables) = @_;
	
	#print __LINE__."; A. string: [$string], variables: [$variables]\n";
	while ($string =~ /#!string!(.+?)!#/)
	{
		my $key        = $1;
		#print __LINE__."; B. key: [$key]\n";
		# I don't insert variables into strings here. If a complex
		# string is needed, the user should process it and pass the
		# completed string to the template function as a
		# #!replace!...!# substitution variable.
		#print __LINE__."; >>> string: [$string]\n";
		my $say_string = get_string($conf, {key => $key, variables => $variables});
		#print __LINE__."; C. say_string: [$key]\n";
		if ($say_string eq "")
		{
			$string =~ s/#!string!$key!#/!! [$key] !!/;
		}
		else
		{
			$string =~ s/#!string!$key!#/$say_string/;
		}
		#print __LINE__."; <<< string: [$string]\n";
	}
	
	return($string);
}

# This replaces "conf" escape variables using variables 
sub process_string_conf_escape_variables
{
	my ($conf, $string) = @_;

	while ($string =~ /#!conf!(.+?)!#/)
	{
		my $key   = $1;
		my $value = "";
		
		# If the key has double-colons, I need to break it up and make
		# each one a key in the multi-dimensional hash.
		if ($key =~ /::/)
		{
			($value) = _get_hash_value_from_string($conf, $key);
		}
		else
		{
			# First dimension
			($value) = defined $conf->{$key} ? $conf->{$key} : "!!Undefined config variable: [$key]!!";
		}
		$string =~ s/#!conf!$key!#/$value/;
	}

	return($string);
}

# Protect unrecognized or unused replacement keys by flipping '#!...!#' to
# '_!|...|!_'. This gets reversed in 'process_string_restore_escape_variables()'.
sub process_string_protect_escape_variables
{
	my ($conf, $string) = @_;

	foreach my $check ($string =~ /#!(.+?)!#/)
	{
		if (
			($check !~ /^free/)    &&
			($check !~ /^replace/) &&
			($check !~ /^conf/)    &&
			($check !~ /^var/)
		)
		{
			$string =~ s/#!($check)!#/_!\|$1\|!_/g;
		}
	}

	return($string);
}

# This is used by the 'template()' function to insert '#!replace!...!#' 
# replacement variables in templates.
sub process_string_replace
{
	my ($conf, $string, $replace, $template_file, $template) = @_;
	
	my $i = 0;
	while ($string =~ /#!replace!(.+?)!#/)
	{
		my $key   =  $1;
		my $value =  defined $replace->{$key} ? $replace->{$key} : "!! Undefined replacement key: [$key] !!\n";
		$string   =~ s/#!replace!$key!#/$value/;
		
		# Die if I've looped too many times.
		if ($i > $conf->{sys}{error_limit})
		{
			hard_die($conf, $THIS_FILE, __LINE__, 12, "Infitie loop detected while replacing '#!replace!...!#' replacement variables in the template file: [$template_file] in the template: [$template]. If this is triggered erroneously, increase the 'sys::error_limit' value.\n");
		}
		$i++;
	}
	
	return($string);
}

# This restores the original escape variable format for escape variables that
# were protected by the 'process_string_protect_escape_variables()' function.
sub process_string_restore_escape_variables
{
	my ($conf, $string)=@_;

	# Restore and unrecognized substitution values.
	my $i = 0;
	while ($string =~ /_!\|(.+?)\|!_/s)
	{
		my $check  =  $1;
		   $string =~ s/_!\|$check\|!_/#!$check!#/g;
		
		# Die if I've looped too many times.
		if ($i > $conf->{sys}{error_limit})
		{
			hard_die($conf, $THIS_FILE, __LINE__, 9, "Infitie loop detected will restoring protected escape variables in the string: [$string]. If this is triggered erroneously, increase the 'sys::error_limit' value.\n");
		}
		$i++;
	}

	return($string);
}

# This reads in the strings XML file.
sub read_strings
{
	my ($conf, $file) = @_;
	
	my $string_ref = $conf;

	my $in_comment  = 0;	# Set to '1' when in a comment stanza that spans more than one line.
	my $in_data     = 0;	# Set to '1' when reading data that spans more than one line.
	my $closing_key = "";	# While in_data, look for this key to know when we're done.
	my $xml_version = "";	# The XML version of the strings file.
	my $encoding    = "";	# The encoding used in the strings file. Should only be UTF-8.
	my $data        = "";	# The data being read for the given key.
	my $key_name    = "";	# This is a double-colon list of hash keys used to build each hash element.
	
	my $read        = IO::Handle->new;
	my $shell_call  = "<$file";
	open ($read, $shell_call) or die hard_die($conf, $THIS_FILE, __LINE__, 1, "Failed to read: [$shell_call]. The error was: $!\n");
	if ($conf->{strings}{force_utf8})
	{
		binmode $read, "encoding(utf8)";
	}
	while(<$read>)
	{
		chomp;
		my $line=$_;

		### Deal with comments.
		# Look for a closing stanza if I am (still) in a comment.
		if (($in_comment) && ( $line =~ /-->/ ))
		{
			$line       =~ s/^(.*?)-->//;
			$in_comment =  0;
		}
		next if ($in_comment);

		# Strip out in-line comments.
		while ($line =~ /<!--(.*?)-->/)
		{
			$line =~ s/<!--(.*?)-->//;
		}

		# See if there is an comment opening stanza.
		if ($line =~ /<!--/)
		{
			$in_comment =  1;
			$line       =~ s/<!--(.*)$//;
		}
		### Comments dealt with.

		### Parse data
		# XML data
		if ($line =~ /<\?xml version="(.*?)" encoding="(.*?)"\?>/)
		{
			$conf->{strings}{xml_version} = $1;
			$conf->{strings}{encoding}    = $2;
			next;
		}

		# If I am not "in_data" (looking for more data for a currently in use key).
		if (not $in_data)
		{
			# Skip blank lines.
			next if $line =~ /^\s+$/;
			next if $line eq "";
			$line         =~ s/^\s+//;

			# Look for an inline data-structure.
			if (($line =~ /<(.*?) (.*?)>/) && ($line =~ /<\/$1>/))
			{
				# First, look for CDATA.
				my $cdata = "";
				if ($line =~ /<!\[CDATA\[(.*?)\]\]>/)
				{
					$cdata =  $1;
					$line  =~ s/<!\[CDATA\[$cdata\]\]>/$cdata/;
				}

				# Pull out the key and name.
				my ($key) = ($line =~ /^<(.*?) /);
				my ($name, $data) = ($line =~ /^<$key name="(.*?)">(.*?)<\/$key>/);
				$data =  $cdata if $cdata;
				_make_hash_reference($string_ref, "${key_name}::${key}::${name}::content", $data);
				next;
			}

			# Look for a self-contained unkeyed structure.
			if (($line =~ /<(.*?)>/) && ($line =~ /<\/$1>/))
			{
				my $key  =  $line;
				   $key  =~ s/<(.*?)>.*/$1/;
				   $data =  $line;
				   $data =~ s/<$key>(.*?)<\/$key>/$1/;
				_make_hash_reference($string_ref, "${key_name}::${key}", $data);
				next;
			}

			# Look for a line with a closing stanza.
			if ($line =~ /<\/(.*?)>/)
			{
				my $closing_key =  $line;
				   $closing_key =~ s/<\/(\w+)>/$1/;
				   $key_name    =~ s/(.*?)::$closing_key(.*)/$1/;
				next;
			}

			# Look for a key with an embedded value.
			if ($line =~ /^<(\w+) name="(.*?)" (\w+)="(.*?)">/)
			{
				my $key   =  $1;
				my $name  =  $2;
				my $key2  =  $3;
				my $data  =  $4;
				$key_name .= "::${key}::${name}";
				_make_hash_reference($string_ref, "${key_name}::${key}::${key2}", $data);
				next;
			}

			# Look for a contained value.
			if ($line =~ /^<(\w+) name="(.*?)">(.*)/)
			{
				my $key  = $1;
				my $name = $2;
				   $data = $3;	# Don't scope locally in case this data spans lines.

				if ($data =~ /<\/$key>/)
				{
					# Fully contained data.
					$data =~ s/<\/$key>(.*)$//;
					_make_hash_reference($string_ref, "${key_name}::${key}::${name}", $data);
				}
				else
				{
					# Element closes later.
					$in_data     =  1;
					$closing_key =  $key;
					$name        =~ s/^<$key name="(\w+).*/$1/;
					$key_name    .= "::${key}::${name}";
					$data        =~ s/^<$key name="$name">(.*)/$1/;
					$data        .= "\n";
				}
				next;
			}

			# Look for an opening data structure.
			if ($line =~ /<(.*?)>/)
			{
				my $key      =  $1;
				   $key_name .= "::$key";
				next;
			}
		}
		else
		{
			if ($line !~ /<\/$closing_key>/)
			{
				$data .= "$line\n";
			}
			else
			{
				$in_data =  0;
				$line    =~ s/(.*?)<\/$closing_key>/$1/;
				$data    .= "$line";

				# If there is CDATA, set it aside.
				my $save_data = "";
				my @lines     = split/\n/, $data;

				my $in_cdata  = 0;
				foreach my $line (@lines)
				{
					if (($in_cdata == 1) && ($line =~ /]]>$/))
					{
						# CDATA closes here.
						$line      =~ s/]]>$//;
						$save_data .= "\n$line";
						$in_cdata  =  0;
					}
					if (($line =~ /^<\!\[CDATA\[/) && ($line =~ /]]>$/))
					{
						# CDATA opens and closes in this line.
						$line      =~ s/^<\!\[CDATA\[//;
						$line      =~ s/]]>$//;
						$save_data .= "\n$line";
					}
					elsif ($line =~ /^<\!\[CDATA\[/)
					{
						$line     =~ s/^<\!\[CDATA\[//;
						$in_cdata =  1;
					}
					
					if ($in_cdata == 1)
					{
						# Don't analyze, just store.
						$save_data .= "\n$line";
					}
					else
					{
						# Not in CDATA, look for XML data.
						#print "Checking: [$line] for an XML item.\n";
						while (($line =~ /<(.*?)>/) && ($line =~ /<\/$1>/))
						{
							# Found a value.
							my $key  =  $line;
							   $key  =~ s/.*?<(.*?)>.*/$1/;
							   $data =  $line;
							   $data =~ s/.*?<$key>(.*?)<\/$key>/$1/;

							#print "Saving: key: [$key], [${key_name}::${key}] -> [$data]\n";
							_make_hash_reference($string_ref, "${key_name}::${key}", $data);
							$line =~ s/<$key>(.*?)<\/$key>//;
						}
						$save_data .= "\n$line";
					}
					#print "$THIS_FILE ".__LINE__."; [$in_cdata] Check: [$line]\n";
				}

				$save_data =~ s/^\n//;
				if ($save_data =~ /\S/s)
				{
					#print "$THIS_FILE ".__LINE__."; save_data: [$save_data]\n";
					_make_hash_reference($string_ref, "${key_name}::content", $save_data);
				}

				$key_name =~ s/(.*?)::$closing_key(.*)/$1/;
			}
		}
		next if $line eq "";
	}
	$read->close();
	#use Data::Dumper; print Dumper $conf;
	
	return(0);
}

# This wraps the passed screen to the current screen width. Assumes output of
# to text/command line.
sub wrap_string
{
	my ($conf, $string) = @_;
	
	my $wrap_to = get_screen_width($conf);
	
	# No sense proceeding if the string is empty.
	return ($string) if not $string;
	
	# No sense proceeding if there isn't a length to wrap to.
	return ($string) if not $wrap_to;

	# When the string starts with certain borders, try to make it look
	# better by indenting the wrapped portion(s) an appropriate number
	# of spaces and put in a border where it seems needed.
	my $prefix_spaces = "";
	if ( $string =~ /^\[ (.*?) \] - / )
	{
		my $prefix      = "[ $1 ] - ";
		my $wrap_spaces = length($prefix);
		for (1..$wrap_spaces)
		{
			$prefix_spaces .= " ";
		}
	}
	# If the line has spaces at the start, maintain those spaces for
	# wrapped lines.
	elsif ( $string =~/^(\s+)/ )
	{
		# We have some number of white spaces.
		my $prefix     =  $1;
		my $say_prefix =  $prefix;
		$say_prefix    =~ s/\t/\\t/g;
		my $wrap_spaces = length($prefix);
		for (1..$wrap_spaces)
		{
			$prefix_spaces.=" ";
		}
	}
	
	my @words          = split/ /, $string;
	my $wrapped_string = "";
	my $this_line;
	for (my $i=0; $i<@words; $i++)
	{
		# Store the line as it was before in case the next word pushes line line past the 'wrap_to' value.
		my $last_line =  $this_line;
		$this_line    .= $words[$i];
		my $length    =  0;
		if ($this_line)
		{
			$length = length($this_line);
		}
		if ((not $last_line) && ($length >= $wrap_to))
		{
			# This one 'word' is longer than the width of the screen so just pass it along.
			$wrapped_string .= $words[$i]."\n";
			$this_line      =  "";
		}
		elsif (length($this_line) > $wrap_to)
		{
			$last_line      =~ s/\s+$/\n/;
			$wrapped_string .= $last_line;
			$this_line      =  $prefix_spaces.$words[$i]." ";
		}
		else
		{
			$this_line.=" ";
		}
	}
	$wrapped_string .= $this_line;
	$wrapped_string =~ s/\s+$//;
	
	return($string);
}

# Get the current number of colums for the user's terminal.
sub get_screen_width
{
	my ($conf) = @_;
	
	my $cols = 0;
	open my $fh, '-|', "$conf->{path}{tput}", "cols" or die "Failed to call: [$conf->{path}{tput} cols]\n";
	while (<$fh>)
	{
		chomp;
		$cols = $_;
	}
	$fh->close();
	
	return($cols);
}

###############################################################################
### Private functions                                                       ###
###############################################################################

### Contributed by Shaun Fryer and Viktor Pavlenko by way of TPM.
# This is a helper to the below '_make_hash_reference' function. It is called
# each time a new string is to be created as a new hash key in the passed hash
# reference.
sub _add_hash_reference
{
	my ($href1, $href2) = @_;

	for my $key (keys %$href2)
	{
		if (ref $href1->{$key} eq 'HASH')
		{
			_add_hash_reference($href1->{$key}, $href2->{$key});
		}
		else
		{
			$href1->{$key} = $href2->{$key};
		}
	}
}

# This is the reverse of '_make_hash_reference()'. It takes a double-colon
# separated string, breaks it up and returns the value stored in the
# corosponding $conf hash.
sub _get_hash_value_from_string
{
	my ($conf, $key_string) = @_;
	
	my @keys      = split /::/, $key_string;
	my $last_key  = pop @keys;
	my $this_href = $conf;
	while (my $key = shift @keys)
	{
		$this_href = $this_href->{$key};
	}
	
	my $value = defined $this_href->{$last_key} ? $this_href->{$last_key} : "!!Undefined config variable: [$key_string]!!";
	
	return($value);
}

### Contributed by Shaun Fryer and Viktor Pavlenko by way of TPM.
# This takes a string with double-colon seperators and divides on those
# double-colons to create a hash reference where each element is a hash key.
sub _make_hash_reference
{
	my ($href, $key_string, $value) = @_;

	my @keys            = split /::/, $key_string;
	my $last_key        = pop @keys;
	my $_href           = {};
	$_href->{$last_key} = $value;
	while (my $key = pop @keys)
	{
		my $elem      = {};
		$elem->{$key} = $_href;
		$_href        = $elem;
	}
	_add_hash_reference($href, $_href);
}

1;