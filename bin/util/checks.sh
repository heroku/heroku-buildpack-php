#!/usr/bin/env bash

checks::ensure_supported_stack() {
	local stack="$1"

	case "$stack" in
		heroku-22 | heroku-24 | heroku-26)
			return 0
			;;
		cedar* | heroku-16 | heroku-18 | heroku-20)
			# This error will only ever be seen on non-Heroku environments, since the
			# Heroku build system rejects builds using EOL stacks.
			build_report::set_string failure_reason stack.eol
			build_report::set_string failure_detail "$stack"
			error <<-EOF
				The '$stack' stack is no longer supported!

				This buildpack no longer supports the '$stack' stack since it
				has reached its end-of-life:
				https://devcenter.heroku.com/articles/stack#stack-support-details

				Upgrade to a newer stack to continue using this buildpack.
			EOF
			;;
		*)
			build_report::set_string failure_reason stack.unknown
			build_report::set_string failure_detail "$stack"
			error <<-EOF
				The '$stack' stack isn't recognised!

				This buildpack doesn't recognise or support the '$stack' stack.

				If '$stack' is a valid stack, make sure that you are using the latest
				version of this buildpack and haven't pinned to an older release:
				https://devcenter.heroku.com/articles/managing-buildpacks#view-your-buildpacks
				https://devcenter.heroku.com/articles/managing-buildpacks#classic-buildpacks-references
			EOF
			;;
	esac
}
