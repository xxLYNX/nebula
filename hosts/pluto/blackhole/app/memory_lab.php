<?php
declare(strict_types=1);

/**
 * Controlled allocation helper for OOM / allocator experiments (VM only).
 * Does not bypass memory_limit; triggers normal PHP OOM handling when exceeded.
 */
session_start();

$mb = isset($_GET['mb']) ? (int) $_GET['mb'] : 0;
$mb = max(0, min($mb, 512));

$held = [];
if ($mb > 0) {
    try {
        $held[] = str_repeat('x', $mb * 1024 * 1024);
    } catch (Throwable $e) {
        http_response_code(500);
        echo 'Allocation failed: ', htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8');
        exit;
    }
}

header('Content-Type: text/html; charset=utf-8');
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Memory lab</title>
</head>
<body>
  <nav>
    <a href="/">Tickets</a>
    <a href="/status.php">Status</a>
  </nav>
  <h1>Memory lab</h1>
  <p>
    PID <?= (int) getmypid() ?>
    · memory_limit <?= htmlspecialchars((string) ini_get('memory_limit'), ENT_QUOTES, 'UTF-8') ?>
    · held <?= $mb ?> MiB this request
  </p>
  <p>Query: <code>?mb=64</code> (capped at 512). Use alongside large multipart uploads.</p>
</body>
</html>
