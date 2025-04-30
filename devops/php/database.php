<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

require_once 'config.php';
require_once 'common.php';

global $pdo;

if ($_SERVER['REQUEST_METHOD'] == 'POST') {

    $data = json_decode(file_get_contents("php://input"));

    if (isset($data->user_uid) && !empty($data->user_uid))
    {
        $user_uid = $data->user_uid;
        $query = $data->query ?? '';
        $user_status_id = check_user($user_uid);

        if ($user_status_id !== 0) {

            switch($query){

                case "takens":
                    $query = $pdo->prepare("SELECT 
                        items.uid,
                        items.code, 
                        items.status_id,
                        items.modified AS date 
                        FROM items 
                        WHERE user_uid = :user_uid AND (status_id = 2 OR status_id = 3)");
                    $query->bindParam(':user_uid', $user_uid, PDO::PARAM_STR);
                    $query->execute();
                    break;

                case "reservation":
                    $query = $pdo->prepare("SELECT 
                            items.uid, 
                            items.code, 
                            items.qr_code, 
                            items.status_id, 
                            users.name,
                            CONCAT('+', users.country_code, users.phone) AS user_phone
                        FROM items 
                        LEFT JOIN users ON items.user_uid = users.uid 
                        WHERE items.status_id IN (1, 2, 5) AND (items.user_uid IS NULL OR user_uid <> :user_uid)
                        ORDER BY items.status_id ASC, items.modified DESC");
                    $query->bindParam(':user_uid', $user_uid, PDO::PARAM_STR);
                    $query->execute();
                    break;

                case "warehouse":
                    $query = $pdo->query("SELECT 
                        items.uid, 
                        items.code, 
                        items.qr_code, 
                        items.status_id, 
                        items.damaged, 
                        users.name,
                        CONCAT('+', COALESCE(users.country_code, ''), COALESCE(users.phone, '')) AS user_phone
                    FROM items 
                    LEFT JOIN users ON items.user_uid = users.uid
                    ORDER BY items.status_id ASC, items.modified DESC;");
                break;

                case 'users':
                    $query = $pdo->query("SELECT 
                            uid, 
                            status_id, 
                            name, 
                            country_code, 
                            phone, 
                            created AS registered  
                            FROM users");
                    break;

                case "invent":
                    $query = $pdo->prepare("SELECT 
                        items.uid,
                        items.invent,
                        items.code, 
                        items.status_id,
                        items.modified AS date 
                        FROM items ORDER BY invent DESC, modified DESC ");
                    $query->execute();
                    break;

                case "requests":
                    $init_status_id = REQUEST_INIT_ID;
                    $accepted_status_id = REQUEST_ACCEPTED_ID;
                    $query = $pdo->prepare("
                        SELECT requests.item_uid,
                               requests.status_id,
                               requests.user_uid,
                               requests.current_user_uid,
                               requests.active,
                               items.code,
                               users.name
                        FROM requests
                        LEFT JOIN items ON items.uid = requests.item_uid
                        LEFT JOIN users ON users.uid = requests.user_uid                        
                        WHERE active = 1 AND ((requests.current_user_uid = :current_user_uid AND requests.status_id = :init_status_id) 
                           OR (requests.user_uid = :current_user_uid AND requests.status_id = :accepted_status_id))
                        ORDER BY requests.created ASC 
                        LIMIT 1");
                    $query->bindParam(':current_user_uid', $user_uid, PDO::PARAM_STR);
                    $query->bindParam(':init_status_id',  $init_status_id, PDO::PARAM_INT);
                    $query->bindParam(':accepted_status_id', $accepted_status_id, PDO::PARAM_INT);
                    $query->execute();
                    break;
                default:
            }
            $items = $query->fetchAll(PDO::FETCH_ASSOC);
            echo json_encode(["items" => json_encode($items), "user_status_id" => $user_status_id]);
        } else {
            echo json_encode(["command" => "logout"]);
        }
    }
}
