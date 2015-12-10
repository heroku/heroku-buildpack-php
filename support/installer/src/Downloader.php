<?php

namespace Heroku\Buildpack\PHP;

use Composer\Downloader\ArchiveDownloader;
use Composer\IO\IOInterface;
use Composer\Config;
use Composer\EventDispatcher\EventDispatcher;
use Composer\Cache;
use Composer\Util\ProcessExecutor;
use Composer\Package\PackageInterface;

class Downloader extends ArchiveDownloader
{
	protected $process;

	public function __construct(IOInterface $io, Config $config, EventDispatcher $eventDispatcher = null, Cache $cache = null, ProcessExecutor $process = null)
	{
		$this->process = $process ?: new ProcessExecutor($io);

		parent::__construct($io, $config, $eventDispatcher, $cache);
	}

	protected function extract($file, $path)
	{
		// we must use cmdline tar, as PharData::extract() messes up symlinks
		$command = 'tar -xzf ' . ProcessExecutor::escape($file) . ' -C ' . ProcessExecutor::escape($path);

		if (0 === $this->process->execute($command, $ignoredOutput)) {
			return;
		}

		throw new \RuntimeException("Failed to execute '$command'\n\n" . $this->process->getErrorOutput());
	}

	public function download(PackageInterface $package, $path)
	{
		$temporaryDir = $this->config->get('vendor-dir').'/composer/'.substr(md5(uniqid('', true)), 0, 8);
		$this->filesystem->ensureDirectoryExists($temporaryDir);

		// START: from FileDownloader::download()

		if (!$package->getDistUrl()) {
			throw new \InvalidArgumentException('The given package is missing url information');
		}

		$this->io->writeError("  - Installing <info>" . $package->getName() . "</info> (<comment>" . $package->getFullPrettyVersion() . "</comment>)");

		$urls = $package->getDistUrls();
		while ($url = array_shift($urls)) {
			try {
				$fileName = $this->doDownload($package, $temporaryDir, $url);
			} catch (\Exception $e) {
				if ($this->io->isDebug()) {
					$this->io->writeError('');
					$this->io->writeError('Failed: ['.get_class($e).'] '.$e->getCode().': '.$e->getMessage());
				} elseif (count($urls)) {
					$this->io->writeError('');
					$this->io->writeError('    Failed, trying the next URL ('.$e->getCode().': '.$e->getMessage().')');
				}

				if (!count($urls)) {
					throw $e;
				}
			}
		}

		// END: from FileDownloader::download()
		
		if ($this->io->isVerbose()) {
			$this->io->writeError('    Extracting archive');
		}

		try {
			$this->extract($fileName, $path);
		} catch (\Exception $e) {
			// remove cache if the file was corrupted
			parent::clearCache($package, $path);
			throw $e;
		}

		$this->filesystem->unlink($fileName);

		if ($this->filesystem->isDirEmpty($this->config->get('vendor-dir').'/composer/')) {
			$this->filesystem->removeDirectory($this->config->get('vendor-dir').'/composer/');
		}
		if ($this->filesystem->isDirEmpty($this->config->get('vendor-dir'))) {
			$this->filesystem->removeDirectory($this->config->get('vendor-dir'));
		}

		$this->io->writeError('');
	}
}
