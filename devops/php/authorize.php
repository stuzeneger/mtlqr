<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

require_once 'config.php';
require_once 'common.php';

/*ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);*/

global $pdo;

if ($_SERVER['REQUEST_METHOD'] == 'POST') {

    $data = json_decode(file_get_contents("php://input"));

    $country_code = isset($data->country_code) ? strval($data->country_code) : '';
    $phone = isset($data->phone) ? strval($data->phone) : '';
    $max_authorization_attempts = MAX_AUTHORIZATION_ATTEMPTS;

    if ($phone != '') {
        $status_id = USER_BLOCKED_STATUS_ID;
        $query = $pdo->prepare("SELECT uid FROM users WHERE status_id <> :status_id AND country_code = :country_code AND phone = :phone AND failed < :max_authorization_attempts");
        $query->bindParam(':country_code', $country_code, PDO::PARAM_STR);
        $query->bindParam(':phone', $phone, PDO::PARAM_STR);
        $query->bindParam(':status_id', $status_id, PDO::PARAM_INT);
        $query->bindParam(':max_authorization_attempts',  $max_authorization_attempts, PDO::PARAM_INT);


        if ($query->execute()) {
           $userData = $query->fetch();
            if ($userData) {
                $auth_code = random_int(100000, 999999);
                $query = $pdo->prepare("UPDATE users SET auth_code = :auth_code WHERE country_code = :country_code AND phone = :phone");
                $query->bindParam(':auth_code', $auth_code, PDO::PARAM_STR);
                $query->bindParam(':country_code', $country_code, PDO::PARAM_STR);
                $query->bindParam(':phone', $phone, PDO::PARAM_STR);

                if ($query->execute()) {
                    sendAuthorization($country_code . $phone, $auth_code);
                    echo json_encode(["success" => true, "message" => "Autozizācija apstiprināta"]);
                } else {
                    echo json_encode(["success" => false, "message" => "Kļūda saglabājot autorizācijas datus"]);
                }
            } else {
                echo json_encode(["success" => false, "message" => "Lietotājs neeksistē"]);
            }
        }
        else {
            echo json_encode(array("message" => "Error!"));
        }
    } else {
        echo json_encode(["success" => false, "message" => "Nepareizs tālruņa numura formāts"]);
    }
}



