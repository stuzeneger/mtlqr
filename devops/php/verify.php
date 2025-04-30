<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json; charset=UTF-8");

global $pdo;

require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $country_code = isset($_POST['country_code']) ? strval($_POST['country_code']) : '';
    $phone = isset($_POST['phone']) ? strval($_POST['phone']) : '';
    $auth_code = isset($_POST['auth_code']) ? strval($_POST['auth_code']) : '';

    if ($country_code !== '' && $phone !== '' && $auth_code !== '') {
        $query = $pdo->prepare("SELECT uid, status_id FROM users WHERE status_id <> 3 AND country_code=:country_code AND phone = :phone AND auth_code = :auth_code");
        $query->bindParam(':country_code', $country_code, PDO::PARAM_STR);
        $query->bindParam(':phone', $phone, PDO::PARAM_STR);
        $query->bindParam(':auth_code', $auth_code, PDO::PARAM_STR);
        $query->execute();

        $user = $query->fetch();

        if ($user) {
            // Lietotājs atrasts, tagad izdzēšam auth_code
            $query = $pdo->prepare("UPDATE users SET auth_code = NULL, failed = 0 WHERE uid = :uid");
            $query->bindParam(':uid', $user['uid'], PDO::PARAM_STR);
            $query->execute();
            echo json_encode(['status' => 'success', 'uid' => $user['uid'], 'status_id' => $user['status_id']]);
        } else {
            //Neveiksmīgs autorizācijas mēģinājums
            $query = $pdo->prepare("UPDATE users SET failed = failed + 1 WHERE country_code = :country_code AND phone = :phone");
            $query->bindParam(':country_code', $country_code, PDO::PARAM_STR);
            $query->bindParam(':phone', $phone, PDO::PARAM_STR);
            $query->execute();
            echo json_encode(["error" => "Neveiksmīgs autorizācijas mēģinājums!"]);
        }
    } else {
        echo json_encode(["error" => "Nepareizs tālruņa numura vai koda formāts!"]);
    }
}
