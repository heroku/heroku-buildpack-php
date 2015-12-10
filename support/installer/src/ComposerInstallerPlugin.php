<?php

namespace Heroku\Buildpack\PHP;

use Composer\Composer;
use Composer\IO\IOInterface;
use Composer\Plugin\PluginInterface;

class ComposerInstallerPlugin implements PluginInterface
{
	public function activate(Composer $composer, IOInterface $io)
	{
		$composer->getDownloadManager()->setDownloader(
			'heroku-sys-tar',
			new Downloader(
				$io,
				$composer->getConfig(),
				$composer->getEventDispatcher()
				// $cache
			)
		);
		$composer->getInstallationManager()->addInstaller(new ComposerInstaller($io, $composer));
	}
}
