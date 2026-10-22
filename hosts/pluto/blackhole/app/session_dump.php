<?php
declare(strict_types=1);
/**
 * Second-request probe: what does session_start() see after RFC1867 OOM on prior request?
 */
header('Content-Type: text/plain; charset=UTF-8');

$sid = 'abcdef0123456789abcdef0123456789';
if (isset($_COOKIE['PHPSESSID'])) {
    session_id($_COOKIE['PHPSESSID']);
} else {
    session_id($sid);
}

session_start();

echo 'php=' . PHP_VERSION . "\n";
echo 'sapi=' . php_sapi_name() . "\n";
echo 'pid=' . getmypid() . "\n";
echo 'session_id=' . session_id() . "\n";
echo 'session_status=' . session_status() . "\n";

$key = ini_get('session.upload_progress.prefix') . 'k';
echo 'progress_key=' . $key . "\n";

if (isset($_SESSION[$key])) {
    $p = $_SESSION[$key];
    echo "has_progress=1\n";
    if (is_array($p)) {
        echo 'done=' . var_export($p['done'] ?? null, true) . "\n";
        echo 'content_length=' . ($p['content_length'] ?? 'na') . "\n";
        echo 'files_count=' . (isset($p['files']) && is_array($p['files']) ? count($p['files']) : 'na') . "\n";
    } else {
        echo 'progress_type=' . gettype($p) . "\n";
    }
} else {
    echo "has_progress=0\n";
}

echo 'session_key_count=' . count($_SESSION) . "\n";
echo 'session_keys=' . implode(',', array_keys($_SESSION)) . "\n";
