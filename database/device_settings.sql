-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Jun 25, 2026 at 05:53 PM
-- Server version: 10.3.39-MariaDB-log-cll-lve
-- PHP Version: 8.1.34

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `canortxw_srm_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `device_settings`
--

CREATE TABLE `device_settings` (
  `id` int(11) NOT NULL,
  `device_id` varchar(50) NOT NULL,
  `wifi_ssid` varchar(50) DEFAULT NULL,
  `wifi_password` varchar(100) DEFAULT NULL,
  `temperature_threshold` float DEFAULT NULL,
  `humidity_threshold_low` float DEFAULT NULL,
  `humidity_threshold_high` float DEFAULT NULL,
  `gas_threshold_normal` int(11) DEFAULT NULL,
  `gas_threshold_warning` int(11) DEFAULT NULL,
  `upload_interval` int(11) DEFAULT NULL,
  `buzzer_enabled` tinyint(1) NOT NULL,
  `updated_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `device_settings`
--

INSERT INTO `device_settings` (`id`, `device_id`, `wifi_ssid`, `wifi_password`, `temperature_threshold`, `humidity_threshold_low`, `humidity_threshold_high`, `gas_threshold_normal`, `gas_threshold_warning`, `upload_interval`, `buzzer_enabled`, `updated_at`) VALUES
(1, 'SRM01', 'myUUM_Guest', '', 10, 50, 85, 150, 300, 5, 0, '2026-06-25 02:12:19');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `device_settings`
--
ALTER TABLE `device_settings`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `device_settings`
--
ALTER TABLE `device_settings`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
