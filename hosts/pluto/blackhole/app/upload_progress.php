<?php
declare(strict_types=1);

session_start();

$progressName = (string) ini_get('session.upload_progress.name');
$prefix = (string) ini_get('session.upload_progress.prefix');

$entries = [];
foreach ($_SESSION as $key => $value) {
    if (str_starts_with((string) $key, $prefix)) {
        $entries[$key] = $value;
    }
}

header('Content-Type: application/json');
echo json_encode([
    'php_version' => PHP_VERSION,
    'sapi' => php_sapi_name(),
    'pid' => getmypid(),
    'session_id' => session_id(),
    'upload_progress_field' => $progressName,
    'prefix' => $prefix,
    'entries' => $entries,
], JSON_PRETTY_PRINT);
