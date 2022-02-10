<?php

namespace Heroku\Buildpack\PHP;

use Composer\Downloader\DownloaderInterface;
use Composer\IO\IOInterface;
use Composer\DependencyResolver\Operation\InstallOperation;
use Composer\Package\PackageInterface;

class NoopDownloader implements DownloaderInterface
{
	protected $io;
	protected $installMessageFormatter;
	
	public function __construct(IOInterface $io, $installMessageFormatter = null)
	{
		$this->io = $io;
		$this->installMessageFormatter = $installMessageFormatter ?? function(PackageInterface $package, $path) { return InstallOperation::format($package); };
	}
	
	public function getInstallationSource()
	{
		return "dist";
	}
	
	public function download(PackageInterface $package, $path, PackageInterface $prevPackage = null)
	{
	}
	
	public function prepare($type, PackageInterface $package, $path, PackageInterface $prevPackage = null)
	{
	}
	
	public function install(PackageInterface $package, $path)
	{
		$this->io->writeError("  - " . $this->formatInstallMessage($package, $path));
	}
	
	public function update(PackageInterface $initial, PackageInterface $target, $path)
	{
	}
	
	public function remove(PackageInterface $package, $path)
	{
	}
	
	public function cleanup($type, PackageInterface $package, $path, PackageInterface $prevPackage = null)
	{
	}
	
	protected function formatInstallMessage(PackageInterface $package, $path)
	{
		return $this->installMessageFormatter->__invoke($package, $path);
	}
}
