<?php
declare(strict_types=1);
header('Content-Type: text/plain; charset=utf-8');
printf("pid=%d\n", getmypid());
printf("sapi=%s\n", php_sapi_name());
printf("version=%s\n", PHP_VERSION);
