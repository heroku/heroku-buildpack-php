<?php

namespace Heroku\Buildpack\PHP;

use Symfony\Component\Console\Formatter\OutputFormatterStyle;

class IndentedOutputFormatterStyle extends OutputFormatterStyle
{
    private $prefix;

    public function __construct(int $indent = 0, ?string $foreground = null, ?string $background = null, array $options = [])
    {
        $this->prefix = str_repeat(" ", $indent);
        parent::__construct($foreground, $background, $options);
    }

    public function apply(string $text)
    {
        return sprintf("%s%s", $this->prefix, $text);
    }
}
