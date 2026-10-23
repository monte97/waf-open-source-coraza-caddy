<?php
// Un servizio PHP qualunque: una pagina con un modulo di caricamento.
// Serve solo a mettere PHP dietro al WAF. L'immagine e' gia' aggiornata
// (PHP 8.4.27, rilasciato il 21/10/2026 con le correzioni di PHP2Shell):
// le richieste di scripts/php2shell.sh hanno la forma dell'attacco, non il
// contenuto, e non possono fare danni.
session_start();
$messaggio = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['documento'])) {
    $messaggio = 'ricevuto: ' . htmlspecialchars($_FILES['documento']['name']) . ', ' . (int) $_FILES['documento']['size'] . ' byte';
}
?>
<!doctype html>
<meta charset="utf-8">
<title>Un servizio PHP</title>
<h1>Carica un documento</h1>
<form method="post" enctype="multipart/form-data">
  <input type="file" name="documento">
  <button>Carica</button>
</form>
<p><?= $messaggio ?></p>
