SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

CREATE TABLE `history` (
  `id` int(11) NOT NULL,
  `type` varchar(50) NOT NULL,
  `user_uid` char(36) NOT NULL,
  `item_uid` char(36) NOT NULL,
  `latitude` varchar(50) DEFAULT NULL,
  `longitude` varchar(50) DEFAULT NULL,
  `created` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 C
OLLATE=utf8mb4_unicode_ci;


CREATE TABLE `items` (
  `id` int(11) NOT NULL,
  `invent` bit(1) NOT NULL,
  `uid` char(36) DEFAULT 'uuid()',
  `status_id` int(11) DEFAULT 1,
  `damaged` bit(1) NOT NULL DEFAULT b'0',
  `user_uid` char(36) DEFAULT NULL,
  `code` varchar(20) NOT NULL,
  `qr_code` char(6) NOT NULL,
  `notes` text NOT NULL,
  `modified` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `created` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE `reservations` (
  `id` int(11) NOT NULL,
  `item_uid` char(36) NOT NULL,
  `status_id` tinyint(4) NOT NULL,
  `user_uid` char(36) NOT NULL,
  `date_from` date NOT NULL,
  `date_to` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `uid` char(36) NOT NULL DEFAULT uuid(),
  `status_id` tinyint(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `country_code` varchar(3) NOT NULL,
  `phone` varchar(16) NOT NULL,
  `auth_code` varchar(20) NOT NULL,
  `failed` tinyint(4) DEFAULT 0,
  `modified` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `created` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `history`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `items`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uid` (`uid`);


ALTER TABLE `requests`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `reservations`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `users`
  ADD UNIQUE KEY `id_2` (`id`),
  ADD UNIQUE KEY `uid` (`uid`),
  ADD KEY `id` (`id`);

ALTER TABLE `history`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `items`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=944;

ALTER TABLE `requests`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=163;

ALTER TABLE `reservations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=44;
COMMIT;