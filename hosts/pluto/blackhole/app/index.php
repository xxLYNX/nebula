<?php
declare(strict_types=1);

session_start();

if (!isset($_SESSION['tickets'])) {
    $_SESSION['tickets'] = [];
}

$message = null;
$error = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $subject = trim((string) ($_POST['subject'] ?? ''));
    $body = trim((string) ($_POST['body'] ?? ''));

    if ($subject === '' || $body === '') {
        $error = 'Subject and body are required.';
    } else {
        $attachment = null;
        if (isset($_FILES['attachment']) && is_array($_FILES['attachment'])) {
            $file = $_FILES['attachment'];
            if (($file['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_OK) {
                $attachment = [
                    'name' => (string) $file['name'],
                    'size' => (int) $file['size'],
                    'type' => (string) $file['type'],
                ];
            }
        }

        $_SESSION['tickets'][] = [
            'id' => count($_SESSION['tickets']) + 1,
            'subject' => $subject,
            'body' => $body,
            'attachment' => $attachment,
            'at' => date(DATE_ATOM),
        ];
        $message = 'Ticket saved in session.';
    }
}

$tickets = $_SESSION['tickets'];
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Support desk (lab)</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 2rem; max-width: 52rem; }
    .meta { color: #444; font-size: 0.9rem; margin-bottom: 1.5rem; }
    label { display: block; margin-top: 0.75rem; }
    input[type=text], textarea { width: 100%; }
    .flash { padding: 0.5rem 0.75rem; margin: 1rem 0; border-radius: 4px; }
    .ok { background: #e8f5e9; }
    .err { background: #ffebee; }
    table { border-collapse: collapse; width: 100%; margin-top: 1rem; }
    th, td { border: 1px solid #ccc; padding: 0.4rem 0.6rem; text-align: left; }
  </style>
</head>
<body>
  <h1>Support desk (lab)</h1>
  <p class="meta">
    PHP <?= htmlspecialchars(PHP_VERSION, ENT_QUOTES, 'UTF-8') ?>
    · SAPI <?= htmlspecialchars(php_sapi_name(), ENT_QUOTES, 'UTF-8') ?>
    · PID <?= (int) getmypid() ?>
    · Session <?= htmlspecialchars(session_id(), ENT_QUOTES, 'UTF-8') ?>
  </p>

  <?php if ($message !== null): ?>
    <div class="flash ok"><?= htmlspecialchars($message, ENT_QUOTES, 'UTF-8') ?></div>
  <?php endif; ?>
  <?php if ($error !== null): ?>
    <div class="flash err"><?= htmlspecialchars($error, ENT_QUOTES, 'UTF-8') ?></div>
  <?php endif; ?>

  <form method="post" enctype="multipart/form-data">
    <label>Subject
      <input type="text" name="subject" maxlength="200" required>
    </label>
    <label>Body
      <textarea name="body" rows="5" required></textarea>
    </label>
    <label>Attachment (optional)
      <input type="file" name="attachment">
    </label>
    <p><button type="submit">Submit ticket</button></p>
  </form>

  <h2>Session tickets</h2>
  <?php if ($tickets === []): ?>
    <p>No tickets yet.</p>
  <?php else: ?>
    <table>
      <thead>
        <tr><th>#</th><th>Subject</th><th>Attachment</th><th>When</th></tr>
      </thead>
      <tbody>
        <?php foreach ($tickets as $ticket): ?>
          <tr>
            <td><?= (int) $ticket['id'] ?></td>
            <td><?= htmlspecialchars($ticket['subject'], ENT_QUOTES, 'UTF-8') ?></td>
            <td>
              <?php if ($ticket['attachment'] !== null): ?>
                <?= htmlspecialchars($ticket['attachment']['name'], ENT_QUOTES, 'UTF-8') ?>
                (<?= (int) $ticket['attachment']['size'] ?> bytes)
              <?php else: ?>
                —
              <?php endif; ?>
            </td>
            <td><?= htmlspecialchars($ticket['at'], ENT_QUOTES, 'UTF-8') ?></td>
          </tr>
        <?php endforeach; ?>
      </tbody>
    </table>
  <?php endif; ?>
</body>
</html>
