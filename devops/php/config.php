<?php
$host = '***';
$dbname = '***';
$username = '***';
$password = '***';

define('SMS_GATEWAY_API_KEY', '***');
define('SMS_SENDER', 'StBVerif');
define('SMS_GATEWAY_CALLBACK_URL', '***');
define('ITEM_WAREHOUSE_STATUS_ID', 1);
define('ITEM_RESERVED_STATUS_ID', 2);
define('ITEM_TAKEN_STATUS_ID', 3);
define('ITEM_TAKE_OVER_STATUS_ID', 2);
define('USER_BLOCKED_STATUS_ID', 3);
define('RESERVE_STATUS_ID', 1);
define('REQUEST_INIT_ID', 1);
define('REQUEST_ACCEPTED_ID', 2);
define('REQUEST_DECLINED_ID', 3);
define('MAX_AUTHORIZATION_ATTEMPTS', 10);
define('ANDROID_APK_URL', '***');
define('IPHONE_IPA_URL', '***');

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die(json_encode(["error" => "Savienojuma kļūda: " . $e->getMessage()]));
}
