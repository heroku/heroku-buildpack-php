<?php

namespace Heroku\Buildpack\PHP;

use \Symfony\Component\Console\Formatter\{NullOutputFormatterStyle,OutputFormatter,OutputFormatterStyle,OutputFormatterStyleStack};

class NoColorsOutputFormatter extends OutputFormatter
{
	public function __construct(bool $decorated = false, array $styles = [])
	{
		// this will set up the default styles below
		parent::__construct($decorated, $styles);
		
		if(!$decorated) {
			// no "decoration", i.e. no ANSI stuff, so we reset the defaults
			$this->setStyle('error', new NullOutputFormatterStyle());
			$this->setStyle('info', new NullOutputFormatterStyle());
			$this->setStyle('comment', new NullOutputFormatterStyle());
			$this->setStyle('question', new NullOutputFormatterStyle());
		}
	}
}
