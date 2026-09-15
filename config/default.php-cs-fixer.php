<?php

/*
 * Bundled default php-cs-fixer configuration.
 *
 * Applied only when the project has neither .php-cs-fixer.php nor
 * .php-cs-fixer.dist.php at its root. This file is bind-mounted READ-ONLY
 * at a fixed path outside the project, so it must never assume it lives
 * inside the project: use getcwd() (the project root, set as the container
 * working directory), never __DIR__.
 */

return (new PhpCsFixer\Config())
    ->setRiskyAllowed(false)
    ->setRules([
        '@Symfony' => true,
        'array_syntax' => ['syntax' => 'short'],
    ])
    ->setFinder(
        PhpCsFixer\Finder::create()
            ->in(getcwd())
            ->exclude(['vendor', 'var', 'node_modules'])
    );
