<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

require_once 'config.php';
require_once 'common.php';

global $pdo;

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $result = false;
    $data = json_decode(file_get_contents("php://input"));

    if (isset($data->user_uid) && !empty($data->user_uid)) {
        $user_uid = $data->user_uid;
        $latitude = isset($data->latitude) ? trim($data->latitude) : null;
        $longitude = isset($data->longitude) ? trim($data->longitude) : null;
        $user_status_id = check_user($user_uid);

        if ($user_status_id !== 0) {
            $event = $data->event ?? '';
            switch ($event) {
                case "check_item":
                    $qr_code = $data->qr_code;
                    $query = $pdo->prepare("SELECT 
                                                    items.uid,
                                                    items.user_uid, 
                                                    items.status_id,
                                                    items.damaged
                                                FROM items                                               
                                                WHERE items.qr_code = :qr_code AND items.status_id IN (1,2,3)");
                    $query->bindParam(':qr_code', $qr_code, PDO::PARAM_STR);
                    break;

                case "take_item":
                    $taken_status_id = ITEM_TAKEN_STATUS_ID;
                    $item_uid = $data->item_uid ?? '';
                    $query = $pdo->prepare("UPDATE items SET user_uid = :user_uid, status_id = :status_id WHERE uid = :item_uid");
                    $query->bindParam(':item_uid', $item_uid, PDO::PARAM_STR);
                    $query->bindParam(':user_uid', $user_uid, PDO::PARAM_STR);
                    $query->bindParam(':status_id', $taken_status_id, PDO::PARAM_INT);
                    $result = true;
                    write_logs('TAKE_ITEM', $user_uid, $item_uid, $latitude, $longitude);
                    break;

                case "return_item":
                    $warehouse_status_id = ITEM_WAREHOUSE_STATUS_ID;
                    $item_uid = $data->item_uid ?? '';
                    $query = $pdo->prepare("UPDATE items SET status_id = :status_id WHERE uid = :item_uid");
                    $query->bindParam(':item_uid', $item_uid, PDO::PARAM_STR);
                    $query->bindParam(':status_id', $warehouse_status_id, PDO::PARAM_INT);
                    $result = true;
                    write_logs('RETURN_ITEM', $user_uid, $item_uid, $latitude, $longitude);
                    break;

                case "confirm_takeover":
                    $init_status_id = REQUEST_INIT_ID;
                    $item_uid = $data->item_uid ?? '';
                    $current_user_uid = $data->current_user_uid ?? '';
                    $notes = $data->notes ?? '';
                    $query = $pdo->prepare("INSERT INTO requests SET 
                                                    user_uid = :user_uid,
                                                    current_user_uid = :current_user_uid,                                                    
                                                    item_uid = :item_uid,
                                                    status_id = :status_id,
                                                    notes = :notes");
                    $query->bindParam(':user_uid', $user_uid, PDO::PARAM_STR);
                    $query->bindParam(':current_user_uid', $current_user_uid, PDO::PARAM_STR);
                    $query->bindParam(':item_uid', $item_uid, PDO::PARAM_STR);
                    $query->bindParam(':status_id', $init_status_id, PDO::PARAM_INT);
                    $query->bindParam(':notes', $notes, PDO::PARAM_STR);
                    $result = true;
                    write_logs('TAKE_OVER_REQUEST', $user_uid, $item_uid, $latitude, $longitude);
                    break;

                case "accept_request":
                    $item_uid = $data->item_uid ?? '';
                    $accepted_status_id = REQUEST_ACCEPTED_ID;
                    $request_init_status_id = REQUEST_INIT_ID;
                    $query = $pdo->prepare("UPDATE requests SET 
                                                        status_id = :accepted_status_id,
                                                        active = 1
                                                  WHERE current_user_uid = :user_uid AND item_uid = :item_uid AND status_id = :request_init_status_id");
                    $query->bindParam(':user_uid', $user_uid, PDO::PARAM_STR);
                    $query->bindParam(':accepted_status_id', $accepted_status_id, PDO::PARAM_INT);
                    $query->bindParam(':item_uid', $item_uid, PDO::PARAM_STR);
                    $query->bindParam(':request_init_status_id', $request_init_status_id, PDO::PARAM_INT);
                    $query->execute();
                    $taken_status_id = ITEM_TAKEN_STATUS_ID;
                    $request_user_uid = $data->request_user_uid ?? '';
                    $is_damaged = $data->is_damaged ?? false;
                    $notes = $data->notes ?? '';
                    $query = $pdo->prepare("UPDATE items SET user_uid = :request_user_uid, damaged = :is_damaged, notes = :notes, status_id = :taken_status_id WHERE uid = :item_uid AND user_uid = :user_uid");
                    $query->bindParam(':item_uid', $item_uid, PDO::PARAM_STR);
                    $query->bindParam(':request_user_uid', $request_user_uid, PDO::PARAM_STR);
                    $query->bindParam(':user_uid', $user_uid, PDO::PARAM_STR);
                    $query->bindParam(':is_damaged', $is_damaged, PDO::PARAM_BOOL);
                    $query->bindParam(':notes', $notes, PDO::PARAM_STR);
                    $query->bindParam(':taken_status_id', $taken_status_id, PDO::PARAM_INT);
                    write_logs('ACCEPT_REQUEST', $user_uid, $item_uid, $latitude, $longitude);
                    break;

                case "decline_request":
                    $status_id = REQUEST_DECLINED_ID;
                    $request_init_status_id = REQUEST_INIT_ID;
                    $item_uid = $data->item_uid ?? '';
                    $query = $pdo->prepare("UPDATE requests SET status_id = :status_id WHERE current_user_uid = :user_uid AND item_uid = :item_uid AND status_id = :request_init_status_id");
                    $query->bindParam(':status_id', $status_id, PDO::PARAM_INT);
                    $query->bindParam(':user_uid', $user_uid, PDO::PARAM_STR);
                    $query->bindParam(':item_uid', $item_uid, PDO::PARAM_STR);
                    $query->bindParam(':request_init_status_id', $request_init_status_id, PDO::PARAM_INT);
                    write_logs('DECLINE_REQUEST', $user_uid, $item_uid, $latitude, $longitude);
                    break;

                case "deactivate_request":
                    $item_uid = $data->item_uid ?? '';
                    $accepted_status_id = REQUEST_ACCEPTED_ID;
                    $query = $pdo->prepare("UPDATE requests SET active = 0 WHERE user_uid = :user_uid AND item_uid = :item_uid AND status_id = :status_id");
                    $query->bindParam(':user_uid', $user_uid, PDO::PARAM_STR);
                    $query->bindParam(':item_uid', $item_uid, PDO::PARAM_STR);
                    $query->bindParam(':status_id', $accepted_status_id, PDO::PARAM_INT);
                    break;

                case "update_item":
                    $itemData = json_decode($data->item_data, true);
                    $item_uid = $itemData['uid'] ?? '';
                    $code = $itemData['code'];
                    $qr_code = $itemData['qr_code'];
                    $status_id = $itemData['status_id'];
                    if (!empty($item_uid)) {
                        $query = $pdo->prepare("UPDATE items SET code = :code, qr_code = :qr_code, status_id = :status_id, user_uid = :user_uid WHERE uid = :item_uid");
                        /*                        if ($status_id === 1) {
                                                    $user_uid = null;
                                                }*/
                        $query->bindParam(':user_uid', $user_uid, PDO::PARAM_STR);
                        $query->bindParam(':item_uid', $item_uid, PDO::PARAM_STR);
                        $query->bindParam(':code', $code, PDO::PARAM_STR);
                        $query->bindParam(':qr_code', $qr_code, PDO::PARAM_STR);
                        $query->bindParam(':status_id', $status_id, PDO::PARAM_INT);
                        $result = true;
                        write_logs('UPDATE_ITEM', $user_uid, $item_uid, $latitude, $longitude);
                    } else {
                        $query = $pdo->prepare("INSERT INTO items SET code = :code, qr_code = :qr_code, status_id = :status_id");
                        $query->bindParam(':code', $code, PDO::PARAM_STR);
                        $query->bindParam(':qr_code', $qr_code, PDO::PARAM_STR);
                        $query->bindParam(':status_id', $status_id, PDO::PARAM_INT);
                        $result = true;
                    }
                    break;

                case "invent_item":
                    $item_uid = $data->item_uid ?? '';
                    $query = $pdo->prepare("UPDATE items SET invent = 1, modified = NOW() WHERE uid = :uid");
                    $query->bindParam(':uid', $item_uid, PDO::PARAM_STR);
                    $result = true;
                    write_logs('INVENT_ITEM', $user_uid, $item_uid, $latitude, $longitude);
                    break;

                case "get_user":
                    $query = $pdo->prepare("SELECT users.uid,
                            users.status_id, 
                            users.name, 
                            users.country_code, 
                            users.phone,
                            created AS registered  FROM users 
                            WHERE users.uid = :uid AND users.status_id <> 3");
                    $query->bindParam(':uid', $user_uid, PDO::PARAM_STR);
                    break;

                case "update_user":
                    $userData = json_decode($data->user_data, true);
                    $uid = $userData['uid'] ?? '';
                    $name = trim($userData['name']);
                    $country_code = trim($userData['country_code']);
                    $phone = trim($userData['phone']);
                    $status_id = intval($userData['status_id']);
                    // Pārbaudām, vai lietotāja UID ir norādīts (rediģēšana)
                    if (!empty($uid)) {
                        $query = $pdo->prepare("UPDATE users SET name = :name, country_code = :country_code, phone = :phone, status_id = :status_id WHERE uid = :uid");
                        $query->bindParam(':uid', $uid, PDO::PARAM_STR);
                        $query->bindParam(':name', $name, PDO::PARAM_STR);
                        $query->bindParam(':country_code', $country_code, PDO::PARAM_STR);
                        $query->bindParam(':phone', $phone, PDO::PARAM_STR);
                        $query->bindParam(':status_id', $status_id, PDO::PARAM_INT);
                        $result = true;
                        write_logs('UPDATE_USER', $user_uid, $uid, $latitude, $longitude);
                    } else {
                        $is_duplicate_user = check_duplicate_user($country_code, $phone);
                        if ($is_duplicate_user === 0) {
                            // Pievienojam jaunu lietotāju
                            $query = $pdo->prepare("INSERT INTO users (name, country_code, phone, status_id) VALUES (:name, :country_code, :phone, :status_id)");
                            $query->bindParam(':name', $name, PDO::PARAM_STR);
                            $query->bindParam(':country_code', $country_code, PDO::PARAM_STR);
                            $query->bindParam(':phone', $phone, PDO::PARAM_STR);
                            $query->bindParam(':status_id', $status_id, PDO::PARAM_INT);
                            $result = true;
                            sendInvitation($country_code . $phone);
                            write_logs('ADD_USER', $user_uid, $uid, $latitude, $longitude);
                        }
                    }

                    break;

                case "reserve_item":
                    $status_id = RESERVE_STATUS_ID;
                    $item_uid = $data->item_uid;
                    $date_from = $data->date_from;
                    $date_to = $data->date_to;
                    $query = $pdo->prepare("INSERT reservations SET 
                     user_uid = :user_uid,
                     item_uid = :item_uid, 
                     status_id = :status_id,
                     date_from = :date_from,
                     date_to = :date_to");
                    $query->bindParam(':user_uid', $user_uid, PDO::PARAM_STR);
                    $query->bindParam(':status_id', $status_id, PDO::PARAM_INT);
                    $query->bindParam(':item_uid', $item_uid, PDO::PARAM_STR);
                    $query->bindParam(':date_from', $date_from, PDO::PARAM_STR);
                    $query->bindParam(':date_to', $date_to, PDO::PARAM_STR);
                    $query->execute();
                    $query = $pdo->prepare("UPDATE items SET user_uid = :user_uid, status_id = :status_id WHERE uid = :item_uid AND status_id = :warehouse_status_id");
                    $status_id = ITEM_RESERVED_STATUS_ID;
                    $warehouse_status_id = ITEM_WAREHOUSE_STATUS_ID;
                    $query->bindParam(':status_id', $status_id, PDO::PARAM_INT);
                    $query->bindParam(':user_uid', $user_uid, PDO::PARAM_STR);
                    $query->bindParam(':item_uid', $item_uid, PDO::PARAM_STR);
                    $query->bindParam(':warehouse_status_id', $warehouse_status_id, PDO::PARAM_INT);
                    write_logs('RESERVE_ITEM', $user_uid, $item_uid, $latitude, $longitude);
                    break;

                case "cancel_reservation":
                    $status_id = ITEM_WAREHOUSE_STATUS_ID;
                    $item_uid = $data->item_uid;
                    $query = $pdo->prepare("UPDATE items SET status_id = :status_id, user_uid = NULL WHERE uid = :item_uid");
                    $query->bindParam(':status_id', $status_id, PDO::PARAM_INT);
                    $query->bindParam(':item_uid', $item_uid, PDO::PARAM_STR);
                    write_logs('CANCEL_ITEM_RESERVATION', $user_uid, $item_uid, $latitude, $longitude);
                    break;

                default:
                    break;
            }

            if ($query->execute()) {
                if (!$result) {
                    $result = $query->fetch(PDO::FETCH_ASSOC);
                }
                echo json_encode(['status' => 'success', 'message' => 'Done!', 'result' => $result]);
            } else {
                echo json_encode(array("message" => "Error!"));
            }
        } else {
            echo json_encode(["command" => "logout"]);
        }
    }
}
