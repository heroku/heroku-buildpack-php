<?php

namespace Heroku\Buildpack\PHP;

use Composer\Composer;
use Composer\Factory;
use Composer\IO\{IOInterface, ConsoleIO, NullIO};
use Symfony\Component\Console\Helper\{HelperSet,ProgressBar};
use Symfony\Component\Console\Input\ArrayInput;
use Symfony\Component\Console\Output\StreamOutput;
use Composer\Plugin\{PluginEvents,PluginInterface,PreFileDownloadEvent,PostFileDownloadEvent,PrePoolCreateEvent};
use Composer\EventDispatcher\EventSubscriberInterface;
use Composer\Installer\{InstallerEvent,InstallerEvents,PackageEvent,PackageEvents};
use Composer\Package\PackageInterface;
use Composer\Util\Filesystem;

class ComposerInstallerPlugin implements PluginInterface, EventSubscriberInterface
{
	const CONF_D_PATHNAME = 'etc/php/conf.d';
	
	protected $composer;
	protected $io;
	protected $ops;
	
	// caller can pass us a file descriptor number for "human-readable" install info via PHP_PLATFORM_INSTALLER_DISPLAY_OUTPUT_FDNO
	// in that case, we make this a Composer ConsoleIO instance with a StreamOutput to that FD; otherwise, it'll be a NullIO
	protected $displayIo;
	
	// profile.d/ and etc/php/conf.d/ files are written with incrementing numeric prefixes by us
	// this ensures that the shell and PHP also load these files in the order we installed them
	protected $profileCounter = 10;
	protected $configCounter = 10;
	
	protected $requestedPackages = [];
	protected $allPlatformRequirements = null;
	
	protected $progressBar;
	
	public function activate(Composer $composer, IOInterface $io)
	{
		$this->composer = $composer;
		$this->io = $io;
		
		// we were supplied with a file descriptor to write "display output" to
		// this can be used by a calling buildpack to get a clean progress bar for downloads, followed by a list of package installs as they happen
		// for this, we make a ConsoleIO instance to be passed to the downloaders for install() output, and a progress bar for our download event listeners
		if($fdno = getenv("PHP_PLATFORM_INSTALLER_DISPLAY_OUTPUT_FDNO")) {
			// a new <indent> tag that can be used in output to prefix a line using the specified indentation
			// this way the progress bar, downloaders, etc, do not have to handle the indentation each
			$styles = [
				'indent' => new IndentedOutputFormatterStyle(intval(getenv('PHP_PLATFORM_INSTALLER_DISPLAY_OUTPUT_INDENT')))
			];
			// special formatter that ignores colors if false is passed as first arg, we want that initially
			$formatter = new NoColorsOutputFormatter(false, $styles);
			$input = new ArrayInput([]);
			$input->setInteractive(false);
			// obey NO_COLOR to control whether or not we want a progress bar
			// (unfortunately, we cannot get e.g. the --no-progress or --no-ansi options from the Composer command invocation)
			// (using $io->isDecorated() does not help either, as regular stdout/stderr might be redirected, but not our display output FD)
			$output = new StreamOutput(fopen("php://fd/{$fdno}", "w"), StreamOutput::VERBOSITY_NORMAL, !getenv('NO_COLOR'), $formatter);
			if($output->isDecorated()) {
				$this->progressBar = new ProgressBar($output);
				$progressBarFormat = ProgressBar::getFormatDefinition('normal');
				$this->progressBar->setFormat(sprintf("<indent>Downloaded%s</indent>", $progressBarFormat));
			}
			// we force ANSI output to on here for the indentation output formatter style to work
			$output->setDecorated(true);
			$this->displayIo = new ConsoleIO($input, $output, new HelperSet());
		} else {
			$this->displayIo = new NullIO();
		}
		
		// check if there already are scripts in .profile.d, or INI files (because we got invoked before, e.g. because this is a `composer require` to add another package after the main install), then calculate new starting point for file names
		foreach([
			'profileCounter' => (getenv('profile_dir_path')?:'/dev/null').'/[0-9][0-9][0-9]-*.sh',
			'configCounter' => self::CONF_D_PATHNAME.'/[0-9][0-9][0-9]-*.ini'
		] as $var => $glob) {
			if($matches = glob($glob)) {
				$this->$var = ceil(max(array_merge([$this->$var], array_map(function($e) { return explode('-', pathinfo($e, PATHINFO_FILENAME), 2)[0]; }, $matches)))/10)+1;
			}
		}
		
		$loop = $composer->getLoop();
		$process = $loop->getProcessExecutor();
		// our custom tar installer handles extraction into a shared base dir, and works around symlink troubles in PHAR
		$composer->getDownloadManager()->setDownloader(
			'heroku-sys-tar',
			new Downloader(
				$io,
				$this->displayIo,
				$composer->getConfig(),
				$loop->getHttpDownloader(),
				$composer->getEventDispatcher(),
				null, // no cache passed in as we explicitly don't want one; inside the slug it makes no sense, as slugs are immutable, and outside the slug (in the app's build cache), it makes little difference (packages are on S3, the cache is on S3) performance wise but would massively bloat the cache size and thus storage cost
				new Filesystem($process),
				$process
			)
		);
		// for packages that are bundled extensions of a "parent" PHP, the dist download points to PHP itself; we don't have to download anything, but just enable the extension via config using the same hooks as for "real" extension packages
		$composer->getDownloadManager()->setDownloader(
			'heroku-sys-php-bundled-extension',
			new NoopDownloader(
				$io,
				$this->displayIo,
				function($package, $path) { return sprintf('Enabling <info>%s</info> (bundled with <comment>php</comment>)', $package->getPrettyName()); }, // the Composer progress info output string we want for our bundled ext "install"
				function($package, $path) { return sprintf('<info>%s</info> (bundled with <comment>php</comment>)', ComposerInstaller::formatHerokuSysName($package->getPrettyName())); } // the human-readable message (printed by the buildpack) we want for our bundled ext "install"
			)
		);
		$composer->getInstallationManager()->addInstaller(new ComposerInstaller($io, $composer));
	}
	
	public function deactivate(Composer $composer, IOInterface $io)
	{
		// nothing to do in our plugin case
	}
	
	public function uninstall(Composer $composer, IOInterface $io)
	{
		// nothing to do in our plugin case
	}
	
	public static function getSubscribedEvents()
	{
		return [
			PluginEvents::PRE_POOL_CREATE => 'onPrePoolCreate',
			InstallerEvents::PRE_OPERATIONS_EXEC => 'onPreOperationsExec',
			PluginEvents::PRE_FILE_DOWNLOAD => 'onPreFileDownload',
			PluginEvents::POST_FILE_DOWNLOAD => 'onPostFileDownload',
			PackageEvents::PRE_PACKAGE_INSTALL => 'onPrePackageInstall',
			PackageEvents::POST_PACKAGE_INSTALL => 'onPostPackageInstall',
		];
	}
	
	// This does not fire on initial install, as the plugin gets installed as part of that, but the event fires before the plugin install.
	// Just what we want, since the logic in here is for the "ext-foobar.native" install attempts after the main packages installation.
	// For those invocations, the plugin is already enabled, and this event handler fires.
	public function onPrePoolCreate(PrePoolCreateEvent $event)
	{
		// the list of explicitly requested packages from e.g. a 'composer require ext-foobar.native:*'
		// we remember this for later, so we can output a message about already-enabled extensions
		// this will be e.g. ["heroku-sys/ext-mbstring.native"]
		$this->requestedPackages = $event->getRequest()->getUpdateAllowList();
	}
	
	// This does not fire on initial install, as the plugin gets installed as part of that, but the event fires before the plugin install.
	// Just what we want, since the logic in here is for the "ext-foobar.native" install attempts after the main packages installation.
	// For those invocations, the plugin is already enabled, and this event handler fires.
	public function onPreOperationsExec(InstallerEvent $event)
	{
		// From the list of operations, we are getting all packages due for install.
		// For each package, we check the "replaces" declarations.
		// For instance, "heroku-sys/ext-mbstring" will declare that it replaces "heroku-sys/ext-mbstring.native".
		// The "replaces" array is keyed by "replacement destination", so it's e.g.:
		//   {"heroku-sys/ext-mbstring.native": {Composer\Package\Link(source="heroku-sys/ext-mbstring",target="heroku-sys/ext-mbstring.native")}}
		// For any package found here that is in the requestAllowList made in onPrePoolCreate, this means a regular installation,
		// the Downloader will print install progress in this case.
		// What we are really looking for, though, is packages in requestAllowList that are not in our list of operations,
		// that means the extension is already enabled (either installed previously, or enabled in PHP by default).
		// Because no installer event will fire in that case (nothing gets installed, after all), we want to output a message here.
		$installs = [];
		foreach($event->getTransaction()->getOperations() as $operation) {
			// add the package itself, just for completeness
			if ($operation->getOperationType() == "install") {
				$installs[] = $operation->getPackage()->getPrettyName();
			}
			// add all "replace" declarations from the package
			$installs = array_merge($installs, array_keys($operation->getPackage()->getReplaces()));
		}
		foreach(array_diff($this->requestedPackages, $installs) as $requestedPackageNotInstalled) {
			$this->displayIo->write(sprintf('<indent>-</indent> <info>%s</info> (already enabled)', ComposerInstaller::formatHerokuSysName($requestedPackageNotInstalled)));
		}
	}
	
	// Because our plugin declares "plugin-modifies-downloads", Composer installs it first.
	// After that, all other package downloads trigger this event.
	public function onPreFileDownload(PreFileDownloadEvent $event)
	{
		$package = $event->getContext();
		if($event->getType() != 'package' || $package->getDistType() != 'heroku-sys-tar') {
			return;
		}
		// downloads happen in parallel, so marking progress here already would be useless
		// but we can update the number of expected downloads on the progress bar
		if($this->progressBar) {
			$downloadCount = $this->progressBar->getMaxSteps();
			if(!$downloadCount++) { // post-increment operator
				// first invocation, we want to initialize the progress bar with a start time
				$this->progressBar->start($downloadCount);
				// however, our maximum step count will now increase with each onPreFileDownload
				// that looks a little confusing if we print every time, so we clear the progress bar again immediately
				// also useful in case our caller printed something on the same line, before the install
				$this->progressBar->clear();
			} else {
				$this->progressBar->setMaxSteps($downloadCount);
			}
		}
	}
	
	// Because our plugin declares "plugin-modifies-downloads", Composer installs it first.
	// After that, all other package downloads trigger this event.
	// We use it to output progress info when a download finishes
	// (Downloader::download returns a promise for parallel downloads, so would be as useless as onPreFileDownload above)
	public function onPostFileDownload(PostFileDownloadEvent $event)
	{
		if($event->getType() != 'package' || $event->getContext()->getDistType() != 'heroku-sys-tar') {
			return;
		}
		if($this->progressBar) {
			$this->progressBar->advance(); // this will re-draw for us
		}
	}
	
	// Because our plugin declares "plugin-modifies-install-path", Composer installs it first.
	// After that, all other package installs trigger this event.
	// Nothing to do for us here except to clear a progress bar if it exists
	public function onPrePackageInstall(PackageEvent $event)
	{
		// clear our progress bar, since we're done with downloads
		// the actual package installs are printed via the Downloaders, just like Composer does it
		if($this->progressBar) {
			if($this->displayIo->isDecorated()) {
				// display output is ANSI capable, we can clear the progress bar
				$this->progressBar->clear();
			} else {
				// display output is not ANSI capable, we need a line break after the progress bar
				$this->displayIo->write("");
			}
			$this->progressBar = null;
		}
	}
	
	// Because our plugin declares "plugin-modifies-install-path", Composer installs it first.
	// After that, all other package installs trigger this event.
	// Here we do a lot of the "heavy lifting"
	public function onPostPackageInstall(PackageEvent $event)
	{
		// first, load all platform requirements from all operations
		// this is because if a package requires `ext-bcmath`, which is `replace`d by `php`, no install event is generated for `ext-bcmath`, but we still need to enable it
		// we cannot do this via InstallerEvents::PRE_OPERATIONS_EXEC, as that fires before this plugin is even installed
		$this->initAllPlatformRequirements($event->getOperations());
		
		if($event->getOperation()->getPackage()->getType() == "metapackage") {
			// a package representing a userland package (might even be "composer.json/composer.lock") that triggered an install event; this may mean it contains a "provide" declaration we need to remember for later
			$this->recordUserlandProvides($event->getOperation()->getPackage());
		}
		
		if(!in_array($event->getOperation()->getPackage()->getType(), ['heroku-sys-php', 'heroku-sys-php-extension', 'heroku-sys-webserver', 'heroku-sys-library', 'heroku-sys-program'])) return;
		
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
	
	// this is for legacy packages/repos, targeting installer v1.5 or earlier, where PHP's own extensions were not written out as separate packages like it will (likely) be the case in v1.6
	// since this is, realistically, only used by PHP (for its bundled shared extensions), we can probably remove this in the future; however, doing this without a BC break would require bumping the installer version to 2.0, which (even if we fully re-built our own repositories) would break third-party repositories
	// the alternative will be to remove this in e.g. v1.7 or v1.8, and adding deprecation warnings beforehand, in order to warn the (few, if any) users that have custom repositories with their own builds of PHP
	// TODO: potentially remove this in a future version, but recordUserlandProvides() now uses this as well to speed up ".native" extension variant installs (by skipping unnecessary attempts)
	protected function initAllPlatformRequirements(array $operations)
	{
		if($this->allPlatformRequirements !== null) return;
		
		// if a package requires `ext-bcmath`, which is `replace`d by `php`, no install event is generated for `ext-bcmath`, but we still need to enable it
		// to do this, we first collect all requirements in a list, then later check a package's `replace` declarations against this list (in enableReplaces())
		// PHP packages built for v1.6 or later of the installer no longer need this, as they cause generating of "dummy" extension packages in the repository; for those, enableExtension() below will not be called, because the shared extensions are no longer listed in the package's `replace` section.
		
		$this->allPlatformRequirements = [];
		foreach($operations as $operation) {
			foreach($operation->getPackage()->getRequires() as $require) {
				if(strpos($require->getTarget(), 'heroku-sys/') === 0) {
					$this->allPlatformRequirements[$require->getTarget()] = $require->getSource();
				}
			}
		}
	}
	
	public function recordUserlandProvides(PackageInterface $package)
	{
		if(!($dest = getenv('providedextensionslog_file_path'))) return;
		// for every heroku-sys/ext-… package this package declares as "provide"d, we record an entry in a job file
		// once the install here succeeds, the buildpack will perform an install attempt for the ".native" variant of each of them
		// a beneficial side-effect is that the installation attempts for these native exts will occur in the same order as the install here, meaning packages listed earlier, or depended upon by many others, will take precedence in the install order
		$providedExtensions = [];
		foreach($package->getProvides() as $provide) {
			// but we only do that for extensions that any other package even requires!
			// no need to attempt installs for extensions provided by polyfills if the extension isn't required anywhere
			if(strpos($provide->getTarget(), "heroku-sys/ext-") === 0 && isset($this->allPlatformRequirements[$provide->getTarget()])) {
				$providedExtensions[] = sprintf("%s:%s", $provide->getTarget(), $provide->getPrettyConstraint()); 
			}
		}
		if($providedExtensions) file_put_contents($dest, sprintf("%s %s\n", $package->getPrettyName(), implode(" ", $providedExtensions)), FILE_APPEND);
	}
	
	protected function configurePackage(PackageInterface $package)
	{
		if($package->getType() == 'heroku-sys-php-extension') {
			$this->enableExtension($package->getPrettyName(), $package);
		}
	}
	
	// this is part of the "shared extensions bundled with PHP" functionality described in the comments for initAllPlatformRequirements
	// TODO: potentially remove this in a future version
	protected function enableReplaces(PackageInterface $package)
	{
		// the current package may be "replace"ing any of the packages (e.g. ext-bcmath is bundled with PHP) that are required by another package
		// we need to figure out which those are so enableExtension() can decide if they need enabling (because they're built shared)
		// PHP packages built for installer v1.6 or later no longer list shared extensions in `replace`
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
			// this is part of the "shared extensions bundled with PHP" functionality described in the comments for initAllPlatformRequirements
			// TODO: potentially remove this in a future version, as PHP packages for installer v1.6 and later no longer use this
			// we're enabling another extension that this package `replace`s - e.g. we are PHP, and we bundle an extension another package has declared as a dependency
			// in this case, a package lists all those `replace`d extensions that are built as a shared library (as opposed to compiled into PHP) in a hash named `shared` in the package metadata's `extra` section
			// this way we can know whether an extension is compiled into PHP, or compiled as a shared library, in which case we need to write an "extension=extname.so" entry into an INI file
			$shared = isset($extra['shared']) ? array_change_key_case($extra['shared'], CASE_LOWER) : [];
			if(!isset($shared[$packageName])) {
				// that ext is on by default or whatever
				return;
			}
			$this->displayIo->write(sprintf('- <info>%s</info> (bundled with <comment>%s</comment>)', ComposerInstaller::formatHerokuSysName($prettyName), $parent->getPrettyName()));
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
