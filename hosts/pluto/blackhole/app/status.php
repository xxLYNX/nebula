<?php
declare(strict_types=1);

/**
 * Early configuration / diagnostics surface (lab only).
 * Not linked from production-style hardening; reachable by URL for research.
 */
session_start();

$showPhpinfo = isset($_GET['phpinfo']) && $_GET['phpinfo'] === '1';

$iniKeys = [
    'memory_limit',
    'post_max_size',
    'upload_max_filesize',
    'max_file_uploads',
    'session.upload_progress.enabled',
    'session.upload_progress.name',
    'session.upload_progress.prefix',
    'session.save_handler',
    'display_errors',
];

$prefix = (string) ini_get('session.upload_progress.prefix');
$sessionProgress = [];
foreach ($_SESSION as $key => $value) {
    if (str_starts_with((string) $key, $prefix)) {
        $sessionProgress[$key] = $value;
    }
}

header('Content-Type: text/html; charset=utf-8');
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Lab status</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 2rem; max-width: 56rem; }
    code, pre { background: #f4f4f4; padding: 0.2rem 0.4rem; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ccc; padding: 0.35rem 0.5rem; text-align: left; }
    nav a { margin-right: 1rem; }
  </style>
</head>
<body>
  <nav>
    <a href="/">Tickets</a>
    <a href="/upload_progress.php">Upload progress</a>
    <a href="/memory_lab.php">Memory lab</a>
  </nav>
  <h1>Runtime status</h1>
  <p>
    PHP <?= htmlspecialchars(PHP_VERSION, ENT_QUOTES, 'UTF-8') ?>
    · <?= htmlspecialchars(php_sapi_name(), ENT_QUOTES, 'UTF-8') ?>
    · PID <?= (int) getmypid() ?>
    · Session <?= htmlspecialchars(session_id(), ENT_QUOTES, 'UTF-8') ?>
  </p>

  <h2>Selected INI (early diagnostics)</h2>
  <table>
    <thead><tr><th>Directive</th><th>Local value</th></tr></thead>
    <tbody>
      <?php foreach ($iniKeys as $key): ?>
        <tr>
          <td><code><?= htmlspecialchars($key, ENT_QUOTES, 'UTF-8') ?></code></td>
          <td><code><?= htmlspecialchars((string) ini_get($key), ENT_QUOTES, 'UTF-8') ?></code></td>
        </tr>
      <?php endforeach; ?>
    </tbody>
  </table>

  <h2>Session upload-progress keys</h2>
  <?php if ($sessionProgress === []): ?>
    <p>None in this session yet (submit a multipart upload from the ticket form).</p>
  <?php else: ?>
    <pre><?= htmlspecialchars(json_encode($sessionProgress, JSON_PRETTY_PRINT), ENT_QUOTES, 'UTF-8') ?></pre>
  <?php endif; ?>

  <p><a href="?phpinfo=1">Show phpinfo()</a> (full early-config dump; lab only)</p>
  <?php if ($showPhpinfo): ?>
    <?php phpinfo(); ?>
  <?php endif; ?>
</body>
</html>
