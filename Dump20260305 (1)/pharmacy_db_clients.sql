-- MySQL dump 10.13  Distrib 8.0.44, for Win64 (x86_64)
--
-- Host: localhost    Database: pharmacy_db
-- ------------------------------------------------------
-- Server version	8.0.44

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `clients`
--

DROP TABLE IF EXISTS `clients`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `clients` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `qr_code` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bonuses` double NOT NULL DEFAULT '0',
  `discount_percent` double NOT NULL DEFAULT '0',
  `created_by_user_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `card_number` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Номер карты клиента (уникальный)',
  `barcode` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Штрихкод клиента (уникальный)',
  `pharmacy_id` int DEFAULT NULL COMMENT 'ID аптеки (для мульти-аптечной системы)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_clients_qr_code_unique` (`qr_code`),
  UNIQUE KEY `idx_clients_card_number_unique` (`card_number`),
  UNIQUE KEY `idx_clients_barcode_unique` (`barcode`),
  KEY `created_by_user_id` (`created_by_user_id`),
  KEY `idx_clients_phone` (`phone`(20)),
  KEY `idx_clients_pharmacy_id` (`pharmacy_id`),
  CONSTRAINT `clients_ibfk_1` FOREIGN KEY (`created_by_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `clients`
--

LOCK TABLES `clients` WRITE;
/*!40000 ALTER TABLE `clients` DISABLE KEYS */;
INSERT INTO `clients` VALUES (1,'Новый клиент','927781020','CLIENT-НК781020',49.64333333333332,1,NULL,'2025-11-13 01:59:58','2026-02-06 23:24:57',NULL,NULL,1),(3,'Новый клиент','977781020','CLIENT-1763094603876-5794',6.859999999999999,2,NULL,'2025-11-14 09:30:03','2025-11-22 17:31:07',NULL,NULL,1),(4,'Новый клиент','999999999','CLIENT-НК999999',52.303,2,4,'2025-11-17 12:38:48','2025-11-22 17:31:07',NULL,NULL,1),(5,'Новый клиент','7687777','CLIENT-НК687777',0,2,6,'2025-11-17 17:04:55','2025-11-22 17:31:07',NULL,NULL,1),(6,'Новый клиент','927777777','CLIENT-НК777777',0,0,6,'2025-11-17 18:28:23','2025-11-22 17:31:07',NULL,NULL,1),(7,'Новый клиент','9005555555','CLIENT-НК555555',0,0,2,'2025-11-18 02:08:14','2025-11-22 17:31:07',NULL,NULL,1),(8,'Новый клиент','123456789','CLIENT-НК456789',11.845999999999998,0,2,'2025-11-18 02:12:50','2025-11-23 16:27:40',NULL,NULL,1),(9,'Новый клиент','921234567','CLIENT-НК234567',0.7000000000000001,0,2,'2025-11-24 13:51:33','2025-11-24 13:51:40','112233445566',NULL,1),(10,'мухаммад','927781020','CLIENT-М781020',10,0,8,'2026-02-05 01:07:25','2026-02-05 01:07:25',NULL,NULL,NULL),(11,'mish','9999999999','CLIENT-M999999',11.68,0,8,'2026-02-05 01:22:59','2026-02-05 01:24:07',NULL,NULL,NULL),(12,'man','7777777','CLIENT-M777777',10,0,8,'2026-02-05 01:53:33','2026-02-05 01:53:33',NULL,NULL,NULL),(13,'msm','123132123','CLIENT-M132123',10,0,8,'2026-02-05 02:37:26','2026-02-05 02:37:26',NULL,NULL,NULL),(14,'ммм','89899988888','CLIENT-М988888',10,0,8,'2026-02-06 22:47:41','2026-02-06 22:47:41',NULL,NULL,1),(15,'vsvs','555555556','CLIENT-V555556',10,0,8,'2026-02-06 22:52:49','2026-02-06 22:52:49',NULL,NULL,1),(16,'vvbvb','54354375437543','CLIENT-V437543',10,0,8,'2026-02-06 23:01:57','2026-02-06 23:01:57','6542365427274',NULL,1);
/*!40000 ALTER TABLE `clients` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-03-05 22:07:39
