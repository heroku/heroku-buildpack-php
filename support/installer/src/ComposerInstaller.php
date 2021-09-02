<?php

namespace Heroku\Buildpack\PHP;

use Composer\Package\PackageInterface;
use Composer\Installer\LibraryInstaller;

class ComposerInstaller extends LibraryInstaller
{
	public function getInstallPath(PackageInterface $package)
	{
		// we do not want a separate install location per package, but instead merge all installs in the same location
		// we return the cwd here (sine we get invoked in the destination base directory); the Downloader takes care of the "merging" part by extracting packages into the existing structure
		return realpath('./');
	}

	/**
	 * {@inheritDoc}
	 */
	public function supports($packageType)
	{
		return in_array($packageType, [
			'heroku-sys-library',
			'heroku-sys-php',
			'heroku-sys-php-extension',
			'heroku-sys-program',
			'heroku-sys-webserver',
		]);
	}
}
