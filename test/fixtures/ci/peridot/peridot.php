<?php

return function($emitter) {
	$emitter->on('peridot.start', function ($env) {
		$definition = $env->getDefinition();
		$definition->getArgument('path')->setDefault('specs');
	});
};
