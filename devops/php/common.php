<?php
require_once 'config.php';

function sendAuthorization(string $phone, string $auth_code): void
{
    $message = $auth_code;
    sendSMS($phone, $message);
}

function sendInvitation(string $phone): void
{
    $message = "MTLQR aplikācijas lejuplāde:" . PHP_EOL .
        "Android ierīcēm: ".ANDROID_APK_URL . PHP_EOL .
        "iPhone ierīcēm: ".IPHONE_IPA_URL;
    sendSMS($phone, $message);
}

function write_logs($type, $user_uid, $item_uid, $latitude = null, $longitude = null)
{
    global $pdo;

    $insertQuery = "INSERT INTO history (type, user_uid, item_uid, latitude, longitude) 
                    VALUES (:type, :user_uid, :item_uid, :latitude, :longitude)";
    $insertStmt = $pdo->prepare($insertQuery);
    $insertStmt->bindParam(':type', $type, PDO::PARAM_STR);
    $insertStmt->bindParam(':user_uid', $user_uid, PDO::PARAM_STR);
    $insertStmt->bindParam(':item_uid', $item_uid, PDO::PARAM_STR);
    $insertStmt->bindParam(':latitude', $latitude, PDO::PARAM_STR);
    $insertStmt->bindParam(':longitude', $longitude, PDO::PARAM_STR);
    $insertStmt->execute();
}

function check_user($user_uid)
{
    global $pdo;

    $result = 0;
    $max_authorization_attempts = MAX_AUTHORIZATION_ATTEMPTS;

    $query = $pdo->prepare("SELECT status_id FROM users WHERE uid = :user_uid AND (status_id = 1 OR status_id = 2) AND failed < :max_authorization_attempts");
    $query->bindParam(':user_uid', $user_uid, PDO::PARAM_STR);
    $query->bindParam(':max_authorization_attempts',  $max_authorization_attempts, PDO::PARAM_INT);

    if ($query->execute()) {
        $row = $query->fetch(PDO::FETCH_ASSOC);
        if (is_array($row) && isset($row['status_id'])) {
            $result = $row['status_id'];
        }
    }

    return $result;
}

function check_duplicate_user($country_code, $phone)
{
    global $pdo;

    $result = 0;
    $query = $pdo->prepare("SELECT status_id FROM users WHERE country_code=:country_code AND phone = :phone");
    $query->bindParam(':country_code', $country_code, PDO::PARAM_STR);
    $query->bindParam(':phone', $phone, PDO::PARAM_STR);

    if ($query->execute()) {
        $row = $query->fetch(PDO::FETCH_ASSOC);
        if (is_array($row) && isset($row['status_id'])) {
            $result = $row['status_id'];
        }
    }

    return $result;
}

function sendSMS($phone, $message): void
{
    $apiKey = SMS_GATEWAY_API_KEY;
    $requestData = [
        "from" => SMS_SENDER,
        "to" => $phone,
        "message" => $message,
        "callback" => SMS_GATEWAY_CALLBACK_URL
    ];
    $url = "***?" . http_build_query($requestData);
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "Authorization: Bearer $apiKey",
        "Content-Type: application/json"
    ]);
    $response = curl_exec($ch);
    if ($response === false) {
        echo "cURL Error: " . curl_error($ch);
    } else {
        echo "Response: " . $response;
    }
    curl_close($ch);
}
