<?php

namespace My;

use Composer\Composer;
use Composer\IO\IOInterface;
use Composer\Plugin\PluginInterface;

class FaultyPlugin implements PluginInterface
{
	public function activate(Composer $composer, IOInterface $io)
	{
		$io->write("Hello, I am FaultyPlugin, writing to stdout instead of stderr in PluginInterface::activate()");
	}

	public function deactivate(Composer $composer, IOInterface $io)
	{
	}
	
	public function uninstall(Composer $composer, IOInterface $io)
	{
	}
}
