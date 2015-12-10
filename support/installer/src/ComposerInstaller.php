<?php

namespace Heroku\Buildpack\PHP;

use Composer\Package\PackageInterface;
use Composer\Installer\LibraryInstaller;

class ComposerInstaller extends LibraryInstaller
{
	public function getInstallPath(PackageInterface $package)
	{
		return realpath('./');
	}

	/**
	 * {@inheritDoc}
	 */
	public function supports($packageType)
	{
		return in_array($packageType, [
			'heroku-sys-php',
			'heroku-sys-php-extension',
			'heroku-sys-hhvm',
		]);
	}

	protected function installCode(PackageInterface $package)
	{
		$downloadPath = $this->getInstallPath($package);
		$this->downloadManager->download($package, $downloadPath);
	}
}
