<?php

namespace Heroku\Buildpack\PHP;

use Composer\Downloader\TarDownloader;
use Composer\IO\IOInterface;
use Composer\Config;
use Composer\EventDispatcher\EventDispatcher;
use Composer\Cache;
use Composer\Util\ProcessExecutor;
use Composer\Package\PackageInterface;
use React\Promise\PromiseInterface;

class Downloader extends TarDownloader
{
	// extract using workarounds for TarDownloader and ArchiveDownloader behavior
	protected function extract(PackageInterface $package, string $file, string $path): PromiseInterface
	{
		// we must use cmdline tar, as PharData::extract() messes up symlinks
		$command = 'tar -xzf ' . ProcessExecutor::escape($file) . ' -C ' . ProcessExecutor::escape($path);
		
		if (0 === $this->process->execute($command, $ignoredOutput)) {
			// ArchiveDownloader, when encountering a single extracted top level directory, will move contents from that directory up one level
			// this is done for e.g. GitHub archive downloads, where the top level dir of a tarball is the name of the repo, and the contents are inside
			// the trouble with that is that we have some packages (e.g. Composer) that only have a `bin/` dir with contents inside
			// ArchiveDownloader::install() would unpack that subdir to the root dir
			// the workaround, which saves us copy/pasting the whole install() routine, is to place a little marker file in the top level of the temp extraction dir, which prevents that behavior
			// the marker file will be removed during cleanup, for which install() registers a location (we in this routine don't know the destination path; the $path argument above is the temporary extraction dir)
			$fn = str_replace('/', '$', $package->getPrettyName());
			$marker = "$path/$fn.extracted";
			touch($marker);
			
			return \React\Promise\resolve(null);
		}
		
		throw new \RuntimeException("Failed to execute '$command'\n\n" . $this->process->getErrorOutput());
	}
	
	protected function getInstallOperationAppendix(PackageInterface $package, string $path): string
	{
		return ''; # we do not want ArchiveDownloader's ": Extracting archive" suffix in our output
	}
	
	public function install(PackageInterface $package, string $path, bool $output = true): PromiseInterface
	{
		// this "marker" file, preventing specific ArchiveDownloader behavior (see docs for extract()), will be placed into the temp extraction dir by extract(), from where it is moved to the destination install dir by ArchiveDownloader::install()'s copying logic
		// extract() can't know the destination path name, so we have to put the path onto the cleanup() list instead
		$fn = str_replace('/', '$', $package->getPrettyName());
		$marker = "$path/$fn.extracted";
		$this->addCleanupPath($package, $marker);
		return parent::install($package, $path, $output);
	}
}
