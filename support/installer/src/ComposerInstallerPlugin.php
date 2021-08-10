<?php

namespace Heroku\Buildpack\PHP;

use Composer\Composer;
use Composer\IO\IOInterface;
use Composer\Plugin\PluginInterface;
use Composer\EventDispatcher\EventSubscriberInterface;
use Composer\Installer\PackageEvent;
use Composer\Installer\PackageEvents;
use Composer\Package\PackageInterface;

class ComposerInstallerPlugin implements PluginInterface, EventSubscriberInterface
{
	const CONF_D_PATHNAME = 'etc/php/conf.d';
	
	protected $composer;
	protected $io;
	protected $ops;
	
	// profile.d/ and etc/php/conf.d/ files are written with incrementing numeric prefixes by us
	// this ensures that the shell and PHP also load these files in the order we installed them
	protected $profileCounter = 10;
	protected $configCounter = 10;
	
	protected $allPlatformRequirements = null;
	
	public function activate(Composer $composer, IOInterface $io)
	{
		$this->composer = $composer;
		$this->io = $io;
		
		// check if there already are scripts in .profile.d, or INI files (because we got invoked before, e.g. because this is a `composer require` to add another package after the main install), then calculate new starting point for file names
		foreach([
			'profileCounter' => (getenv('profile_dir_path')?:'/dev/null').'/[0-9][0-9][0-9]-*.sh',
			'configCounter' => self::CONF_D_PATHNAME.'/[0-9][0-9][0-9]-*.ini'
		] as $var => $glob) {
			if($matches = glob($glob)) {
				$this->$var = ceil(max(array_merge([$this->$var], array_map(function($e) { return explode('-', pathinfo($e, PATHINFO_FILENAME), 2)[0]; }, $matches)))/10)+1;
			}
		}
		
		$composer->getDownloadManager()->setDownloader(
			'heroku-sys-tar',
			new Downloader(
				$io,
				$composer->getConfig(),
				$composer->getEventDispatcher()
				// no cache passed in as we explicitly don't want one; inside the slug it makes no sense, as slugs are immutable, and outside the slug (in the app's build cache), it makes little difference (packages are on S3, the cache is on S3) performance wise but would massively bloat the cache size and thus storage cost
			)
		);
		$composer->getInstallationManager()->addInstaller(new ComposerInstaller($io, $composer));
	}
	
	public static function getSubscribedEvents()
	{
		return [PackageEvents::POST_PACKAGE_INSTALL => 'onPostPackageInstall'];
	}

	public function onPostPackageInstall(PackageEvent $event)
	{
		if(!in_array($event->getOperation()->getPackage()->getType(), ['heroku-sys-php', 'heroku-sys-php-extension', 'heroku-sys-webserver', 'heroku-sys-library', 'heroku-sys-program'])) return;
		
		// first, load all platform requirements from all operations
		// this is because if a package requires `ext-bcmath`, which is `replace`d by `php`, no install event is generated for `ext-bcmath`, but we still need to enable it
		$this->initAllPlatformRequirements($event->getOperations());
		
		try {
			// configure the package if needed (currently only applies to extensions)
			$this->configurePackage($event->getOperation()->getPackage());
			// enable any packages this package claims to "replace"
			$this->enableReplaces($event->getOperation()->getPackage());
			// write package's runtime init logic to a `profile.d/` script, sourced at dyno boot by the shell to e.g. put binaries on $PATH
			$this->writeProfile($event->getOperation()->getPackage());
			// append package's build-time init logic to `export` script, sourced by the build system before invoking following buildpacks to e.g. put binaries on $PATH
			$this->writeExport($event->getOperation()->getPackage());
		} catch(\Exception $e) {
			$this->io->writeError(sprintf('<error>Failed to activate package %s</error>', $event->getOperation()->getPackage()->getName()));
			$this->io->writeError('');
			throw $e;
		}
	}
	
	protected function initAllPlatformRequirements(array $operations)
	{
		if($this->allPlatformRequirements !== null) return;
		
		// if a package requires `ext-bcmath`, which is `replace`d by `php`, no install event is generated for `ext-bcmath`, but we still need to enable it
		// to do this, we first collect all requirements in a list, then later check a package's `replace` declarations against this list (in enableReplaces())
		
		$this->allPlatformRequirements = [];
		foreach($operations as $operation) {
			foreach($operation->getPackage()->getRequires() as $require) {
				if(strpos($require->getTarget(), 'heroku-sys/') === 0) {
					$this->allPlatformRequirements[$require->getTarget()] = $require->getSource();
				}
			}
		}
	}
	
	protected function configurePackage(PackageInterface $package)
	{
		if($package->getType() == 'heroku-sys-php-extension') {
			$this->enableExtension($package->getPrettyName(), $package);
		}
	}
	
	protected function enableReplaces(PackageInterface $package)
	{
		// the current package may be "replace"ing any of the packages (e.g. ext-bcmath is bundled with PHP) that are required by another package
		// we need to figure out which those are so enableExtension() can decide if they need enabling (because they're built shared)
		$enable = array_intersect_key($package->getReplaces(), $this->allPlatformRequirements);
		
		foreach(array_keys($enable) as $extension) {
			$this->enableExtension($extension, $package);
		}
	}
	
	protected function enableExtension($prettyName, PackageInterface $parent)
	{
		// for comparison etc
		$packageName = strtolower($prettyName);
		// strip "heroku-sys/ext-"
		$extName = substr($packageName, 15);
		
		// check if it's an extension
		if(strpos($packageName, 'heroku-sys/ext-') !== 0) return;
		
		$extra = $parent->getExtra();
		
		if($parent->getName() == $packageName) {
			// we're enabling this current package itself (meaning it's an extension package)
			$config = isset($extra['config']) ? $extra['config'] : true;
		} else {
			// we're enabling another extension that this package `replace`s - e.g. we are PHP, and we bundle an extension another package has declared as a dependency
			// in this case, a package lists all those `replace`d extensions that are built as a shared library (as opposed to compiled into PHP) in a hash named `shared` in the package metadata's `extra` section
			// this way we can know whether an extension is compiled into PHP, or compiled as a shared library, in which case we need to write an "extension=extname.so" entry into an INI file
			$shared = isset($extra['shared']) ? array_change_key_case($extra['shared'], CASE_LOWER) : [];
			if(!isset($shared[$packageName])) {
				// that ext is on by default or whatever
				return;
			}
			
			$this->io->writeError(sprintf('  - Enabling <info>%s</info> (bundled with <comment>%s</comment>)', $prettyName, $parent->getPrettyName()));
			$this->io->writeError('');
			
			$config = $shared[$packageName];
		}
		
		// compute a filename for this config file - if we already have "100-something.ini", we'll get "110-ourname.ini"
		$ini = sprintf('%s/%03u-%%s.ini', self::CONF_D_PATHNAME, $this->configCounter++*10);
		@mkdir(dirname($ini), 0777, true);
		
		// check if the `config` entry in the package metadata's `extra` section simply refers to the `.so` name of the extension, or if it points to an actual INI file (with the extension loading directive as well as other config settings) that we have to copy over
		if($config === true || (is_string($config) && substr($config, -3) === '.so' && is_readable($config))) {
			// simple case: just enable that ext using the given (or auto-determined) `.so` filename
			file_put_contents(sprintf($ini, "ext-$extName"), sprintf("extension=%s\n", $config === true ? "$extName.so" : $config));
		} elseif(is_string($config) && is_readable($config)) {
			// entry points to an actual ini file, maybe with special contents like extra config or different .so name (think "zend-opcache" vs "opcache.so")
			// FIXMEMAYBE: consider ignoring/overriding the numeric prefix and re-using the original file name for "replace"d extensions, which may deliberately be different to ensure a certain loading order?
			// FIXMEMAYBE: example: some rare extensions (e.g. recode: http://php.net/manual/en/recode.installation.php) need to be loaded in a specific order (https://www.pingle.org/2006/10/18/php-crashes-extensions)
			// FIXMEMAYBE: this can only happen if several extensions, built as shared, are included in a package and will be activated (so typically just PHP with its shared exts); for real dependencies (ext-apc needs ext-apcu, ext-foobar needs ext-mysql), Composer already does that ordering for us
			rename($config, sprintf($ini, "ext-$extName"));
		} elseif (!$config) {
			return;
		} else {
			throw new \RuntimeException('Package declares invalid or missing "config" in "extra"');
		}
	}
	
	protected function writeExport(PackageInterface $package)
	{
		// destination file path is given via environment
		if(!($fn = getenv('export_file_path'))) return;
		
		// does this package even have an export script declared?
		$extra = $package->getExtra();
		if(!isset($extra['export']) || !$extra['export']) return;
		
		if(is_string($extra['export']) && is_readable($extra['export'])) {
			// given value points to a file inside the package, read it
			$export = file_get_contents($extra['export']);
			@unlink($extra['export']);
		} elseif(is_array($extra['export'])) {
			// given value is not a file name, but a hash of env vars for the next buildpack, e.g. "PATH": "$HOME/.heroku/php/bin:$PATH", so we generate that
			$export = implode("\n", array_map(function($v, $k) { return sprintf('export %s="%s"', $k, $v); }, $extra['export'], array_keys($extra['export'])));
		} else {
			throw new \RuntimeException('Package declares invalid or missing "export" in "extra"');
		}
		
		// append our contents to the export script file
		file_put_contents($fn, "\n$export\n", FILE_APPEND);
	}
	
	protected function writeProfile(PackageInterface $package)
	{
		// destination file path is given via environment
		if(!getenv('profile_dir_path')) return;
		
		// does this package even have a `profile.d/` script declared?
		$profile = $package->getExtra();
		if(!isset($profile['profile']) || !$profile['profile']) return;
		$profile = $profile['profile'];
		
		// compute a filename for this profile script file - if we already have "100-something.sh", we'll get "110-ourname.sh"
		$fn = sprintf("%s/%03u-%s.sh", getenv('profile_dir_path'), $this->profileCounter++*10, str_replace('heroku-sys/', '', $package->getName()));
		@mkdir(dirname($fn), 0777, true);
		
		if(is_string($profile) && is_readable($profile)) {
			// given value points to a file inside the package, move it to ~/.profile.d/
			rename($profile, $fn);
		} elseif(is_array($profile)) {
			// given value is not a file name, but a simple hash of env vars for startup, e.g. "PATH": "$HOME/.heroku/php/bin:$PATH", so we write those to a file
			file_put_contents(
				$fn,
				implode("\n", array_map(function($v, $k) { return sprintf('export %s="%s"', $k, $v); }, $profile, array_keys($profile)))
			);
		} else {
			throw new \RuntimeException('Package declares invalid or missing "profile" in "extra"');
		}
	}
}
