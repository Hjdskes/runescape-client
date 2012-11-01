# This modules deals with finding the Java binary to run the client
package rsu_java;

	sub findjavabin
	{
		# Get the data container
		my $rsu_data = shift;
		
		# Print debug info
		print "I will now check what platform you are using\nand use the correct Java path for that platform\n\n";
		
		# Define the variable for javabin
		my $javabin;
		
		# Define a variable to contain a boolean (true/false) to see if OpenJDK exists
		my $openjdk;
		
		# We are on Linux
		# Print debug info
		print "You are running ".$rsu_data->OS.", I will probe for OpenJDK6 or newer\nand use the newest version if possible.\n\n";
			
		# Make a variable to contain the preferredjava so we can use it in the command
		my $preferredjava = $rsu_data->preferredjava;
			
		# run "find /usr/lib/jvm/ -name java" to see if we can find OpenJDK by using grep
		$openjdk = `find -L /usr/lib/jvm/ -name "java" |grep -P "$preferredjava(|-amd64|-i386|-\$\(uname -i\))/bin"`;
			
		# if $openjdk is found (hurray!)
		if ($openjdk =~ /java-\d{1,1}-openjdk(|-\$\(uname -p\)|-i386|-amd64)/)
		{
			# Print debug info
			print "Found OpenJDK files, now checking for the newest installed one.\n";
			
			# Split the string by newline incase OpenJDK-7 was found
			my @openjdkbin = split /\n/, $openjdk;
			
			# Print debug info
			print "Checking which OpenJDK versions are installed...\n\n";
			
			# Run a check to see if we detected OpenJDK7
			my $detectedopenjdk7 = grep { $openjdkbin[$_] =~ /java-\d{1,1}-openjdk-(\$\(uname -p\)|i386|amd64)/ } 0..$#openjdkbin;
			
			# If OpenJDK7 was not found
			#if ($openjdkbin[$index] !~ /java-\d{1,1}-openjdk-(\$\(uname -p\)|i386|amd64)/)
			if($detectedopenjdk7 =~ /0/)
			{
				# Print debug info
				print "OpenJDK6 detected!, I will use this to run the client!\n";
				
				# we will use OpenJDK6 to launch it (OpenJDK does not have SFX problems like Sun-Java)
				$javabin = "$openjdkbin[0] ";
			}
			else
			{
				# Print debug info
				print "OpenJDK7 detected!, I will use this to run the client!\n";
			
				# Find the index of OpenJDK7
				my @openjdk7index = grep { $openjdkbin[$_] =~ /java-\d{1,1}-openjdk-(\$\(uname -p\)|i386|amd64)/ } 0..$#openjdkbin;
				
				# We will use OpenJDK7 to launch it (OpenJDK does not have SFX problems like Sun-Java)
				$javabin = "$openjdkbin[$openjdk7index[0]] ";
			}
		}		
		else
		{
			# Print debug info
			print "I did not find any version of OpenJDK in /usr/lib/jvm\nI will instead use the default Java in \$PATH\n";
			
			# if OpenJDK is not found then we will use default Java (lets pray it is in the $PATH)
			$javabin = "java";
		}
		
		# Return to call with the Java executable
		return $javabin;
	}

	#
	#---------------------------------------- *** ----------------------------------------
	#

	sub check_for_java_client_mode
	{
		# Gets passed data from the function call
		my $rsu_data = shift;
		
		# Pass the binary to a variable so we can use it in commands
		my $java_binary = $rsu_data->javabin;
		
		# Execute java -help and see if this Java have the -client parameter available
		my $results = `$java_binary -help 2>&1`;
		
		# If the -client parameter is an option
		if ($results =~ /-client/)
		{
			# Tell Java to execute in client mode
			$java_binary = "$java_binary -client";
		}
		
		# Return the results
		return "$java_binary";
	}

	#
	#---------------------------------------- *** ----------------------------------------
	#

	sub unix_find_default_java_binary
	{
		# Get the data container
		my $rsu_data = shift;
		
		# Make a variable for the location of the Java in path
		my $whereisjava;
		
		# If our os is linux or freebsd
		if ($rsu_data->OS =~ /(linux|freebsd)/)
		{
			# Ask where the Java executable is
			$whereisjava = `whereis java | sed s/java:\\ // | sed s/\\ .*//`;
		}
		# Else if we are on solaris
		elsif($rsu_data->OS =~ /(solaris)/)
		{
			# Return the default symlink location (since solaris have the libjli.so linked properly)
			return "/usr/bin/java";
		}
		
		# Make a variable to contain the testing results
		my $test_exec;
		
		# Make a for loop which follows symlinks up to 10 times in order to find the Java binary
		# (you must be really silly if you have 10 symlinks together to point to it!)
		my $counter;
		for ($counter = 0; $counter < 10; $counter++)
		{
			# Check if this is the true binary
			$test_exec = `ls -la $whereisjava`;
			
			# If the result contains "java -> /" then
			if ($test_exec =~ /java\ -.\ \//)
			{
				# Split the result by whitespace
				my @newtest = split(/\ /, $test_exec);
				
				# Replace $whereisjava with the new location to test
				$whereisjava = $newtest[-1];
			}
			else
			{
				# Split the result by whitespace
				my @truebinary = split(/\ /, $test_exec);
				
				# Replace $whereisjava with the new location to test
				$whereisjava = $truebinary[-1];
				
				# Remove the newline from the output
				$whereisjava =~ s/\n//;
				
				# Make sure we end this loop (no point to continue checking)
				$counter = 11;
			}
		}
		
		# Do a final check to see if the Java binary is found...
		# If $whereisjava do not end with /bin/java then
		if ($whereisjava !~ /\/bin\/java$/)
		{
			# Run a function which will tell the user what to do in order to fix this issue
			$whereisjava = rsu_java::unix_default_java_is_a_script($rsu_data);
		}
		
		# Return the true default Java binary
		return "$whereisjava";
	}

	#
	#---------------------------------------- *** ----------------------------------------
	#

	sub unix_default_java_is_a_script
	{	
		# This function depends on rsu_IO.pm
		require rsu_IO;
		
		# Get the data container
		my $rsu_data = shift;
		
		# Pass the current directory to a variable for use in a message
		my $cwd = $rsu_data->cwd;
		
		# Define any large messages we will need in the script
		# Message if Java in $PATH is not a binary
		my $java_not_bin = << "java_not_binary_message";
It looks like your default Java is not a binary file!
This script requires direct use of the Java BINARY file
in order to make sure all the Java library files gets loaded properly.
Please edit $cwd/share/settings.conf
and add the path to the Java BINARY as the value for preferredjava.

You can use the command (You can find this text inside /tmp/java_notice.txt):
sudo find / -name "libjli.so" | sed "s/\\/lib\\/\\(i386\\|amd64\\)\\/jli\\/libjli.so/\\/bin\\/java/g"

In order to get a list of possible paths you can use as the preferredjava value.
Also please look at $cwd/share/settings.conf.example
for examples on the setting values.

Please press ENTER/RETURN to continue running the script 
after you added the path to the binary into the 
$cwd/share/settings.conf file.

java_not_binary_message
		
		# Make a variable to contain the new Java path
		my $newjavapath;
		
		# if we are inside an interactive shell then
		if (-t STDOUT)
		{
			# Write the Java notice to a file
			rsu_IO::WriteFile($java_not_bin, ">", "/tmp/java_notice.txt");
			
			# Display the message
			print $java_not_bin;
			
			# Wait for user to press ENTER/RETURN
			my $continue = <STDIN>;
			
			# remove the notice
			system "rm /tmp/java_notice.txt";
			
			# Read the preferred Java in the config file, if nothing is found then say JAVA NOT SET
			$newjavapath = readconf("preferredjava", "JAVA NOT SET");		
		}
		else
		{
			# Write the Java notice to a file
			WriteFile($java_not_bin, ">", "/tmp/java_notice.txt");
			
			# run script in xterm so we can get input from user and with right permissions
			system "xterm -e \"cat /tmp/java_notice.txt && read i\"";
			
			# remove the notice
			system "rm /tmp/java_notice.txt";
			
			# Read the preferred Java in the config file, if nothing is found then say JAVA NOT SET
			$newjavapath = readconf("preferredjava", "JAVA NOT SET");
		}
		
		# If Java is still not set
		if ($newjavapath =~ /JAVA NOT SET/)
		{
			# Tell user whats wrong and then exit
			print "You did not set the path to Java in the preferredjava setting\ninside ".$rsu_data->cwd."/share/settings.conf\nThe client will not work for you without this setting... EXITING!\n";
			exit
		}
		
		# return the new javapath
		return "$newjavapath";
	}

1;
