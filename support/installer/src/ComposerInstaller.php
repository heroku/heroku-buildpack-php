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
	
	public static function formatHerokuSysName(string $name): string
	{
		// strip a "heroku-sys/" prefix if it exists, and in that case, also a ".native" postfix
		// this turns our internal "heroku-sys/ext-foobar.native" or "heroku-sys/php" names into "ext-foobar" or "php" for display output
		return preg_replace('#^(heroku-sys/)(.+?)(?(1).native)?$#', '$2', $name);
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
