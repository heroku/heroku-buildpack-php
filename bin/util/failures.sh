detect_platform_solving_failures() {
	# we can't use an associative array, as those are pure hashes in Bash 4+, so they don't preserve an order, but we need that
	local failures=()
	local regexes=()
	
	regexes+=("requires php \S+ -> no matching package found")
	failures+=("requirements.php")
	regexes+=("requires php-64bit \S+ -> no matching package found")
	failures+=("requirements.php-64bit")
	regexes+=("requires hhvm \S+ -> no matching package found")
	failures+=("requirements.hhvm")
	regexes+=("requires ext-\S+ \S+ -> no matching package found")
	failures+=("requirements.extension")
	
	regexes+=("requires ext-mcrypt \S+ -> satisfiable by php")
	failures+=("requirements.extension.mcrypt")
	regexes+=("requires ext-mongo \S+ -> satisfiable by ext-mongo")
	failures+=("requirements.extension.mongo")
	regexes+=("requires ext-mysql \S+ -> satisfiable by php")
	failures+=("requirements.extension.mysql")
	
	# FIXME: detect multiple conflicing requirements (e.g. from require and require-dev)?
	
	# regex_failures expects variable names, not values, as it dereferences the arrays
	regex_failures regexes failures || echo "unknown"
}

detect_platform_install_failures() {
	# we can't use an associative array, as those are pure hashes in Bash 4+, so they don't preserve an order, but we need that
	local failures=()
	local regexes=()
	
	regexes+=("Your configuration does not allow connections to")
	failures+=("download.insecure")
	regexes+=('.json" file could not be downloaded \(HTTP/\S+ 404')
	failures+=("download.not_found")
	regexes+=('Composer\\Downloader\\TransportException')
	failures+=("download.unknown")
	# FIXME: all these probably apply to repositories and file downloads, can we differentiate?
	# FIXME: repository errors occur right after "Loading repositories with available runtimes and extensions"
	# FIXME: package downloads have "Updating dependencies" and "Package operations: 33 installs, 0 updates, 0 removals" before
	
	# regex_failures expects variable names, not values, as it dereferences the arrays
	regex_failures regexes failures || echo "unknown"
}

detect_dependencies_solving_failures() {
	# we can't use an associative array, as those are pure hashes in Bash 4+, so they don't preserve an order, but we need that
	local failures=()
	local regexes=()
	
	regexes+=('overridden by "config.platform.[^"]+" version \([^)]+\) does not satisfy that requirement')
	failures+=("platform_override")
	
	# regex_failures expects variable names, not values, as it dereferences the arrays
	regex_failures regexes failures || echo "unknown"
}

detect_dependencies_install_failures() {
	# we can't use an associative array, as those are pure hashes in Bash 4+, so they don't preserve an order, but we need that
	local failures=()
	local regexes=()
	
	regexes+=("Your configuration does not allow connections to")
	failures+=("download.insecure")
	regexes+=("Failed to download \S+ from dist: Could not authenticate against")
	failures+=("download.authentication.failed")
	regexes+=("No bitbucket authentication configured")
	failures+=("download.authentication.bitbucket.missing")
	
	regexes+=('Failed to clone \S+ via \S+(, \S+)* protocols, aborting.')
	failures+=("download.clone")
	# FIXME: may be followed first by "remote: Invalid username or password" and then "Host key verification failed."
	regexes+=("Failed to execute git clone")
	failures+=("download.clone")
	# FIXME: "Host key verification failed." may show up a few lines later
	# FIXME: or "fatal: unable to access 'https://foo:***@bitbucket.org/foo/bar.git/': The requested URL returned error: 403"
	
	regexes+=('Failed to download \S+ from dist: The "[^"]+" file could not be downloaded \(HTTP/\S+ 404')
	failures+=("download.not_found")
	
	regexes+=("Parse error: syntax error")
	failures+=("scripts.any.parse_error")
	regexes+=("(ClassNotFoundException|Class '[^']+' not found)")
	failures+=("scripts.any.class_not_found")
	regexes+=('Symfony\\Component\\Process\\Exception\\ProcessTimedOutException')
	failures+=("scripts.any.timeout")
	regexes+=('(SQLSTATE|PDOException|Doctrine\\DBAL\\Exception)')
	failures+=("scripts.any.database")
	
	regexes+=("handling the post-install-cmd event terminated with an exception")
	failures+=("scripts.post-install-cmd.exception")
	regexes+=("handling the post-install-cmd event returned with error code")
	failures+=("scripts.post-install-cmd.error")
	regexes+=("handling the post-autoload-dump event terminated with an exception")
	failures+=("scripts.post-autoload-dump.exception")
	regexes+=("handling the post-autoload-dump event returned with error code")
	failures+=("scripts.post-autoload-dump.error")
	regexes+=("handling the \S+ event terminated with an exception")
	failures+=("scripts.unknown.exception")
	regexes+=("handling the \S+ event returned with error code")
	failures+=("scripts.unknown.error")
	
	regexes+=("(APP_ENV environment variable is not defined|Environment variable not found)")
	failures+=("symfony.env_var_missing")
	
	# regex_failures expects variable names, not values, as it dereferences the arrays
	regex_failures regexes failures || echo "unknown"
}

regex_failures() {
	# dereference argument names into variables
	local name=$1[@]
	local regexes=("${!name}")
	local name=$2[@]
	local failures=("${!name}")
	
	# buffer input, as we have to read it many times
	local input=$(</dev/stdin)
	
	# iterate over indexes in $regexes, which has the same indexes as $failures
	for i in "${!regexes[@]}"; do
		if grep -qE "${regexes[$i]}" <<< "$input"; then
			echo "${failures[$i]}"
			return 0;
		fi
	done
	
	return 1;
}
