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
-- Table structure for table `stock_movements`
--

DROP TABLE IF EXISTS `stock_movements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stock_movements` (
  `id` int NOT NULL AUTO_INCREMENT,
  `product_id` int NOT NULL,
  `movement_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `quantity` int NOT NULL,
  `stock_before` int NOT NULL,
  `stock_after` int NOT NULL,
  `price` double DEFAULT NULL,
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `user_id` int DEFAULT NULL,
  `receipt_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_stock_movements_product` (`product_id`),
  KEY `idx_stock_movements_user` (`user_id`),
  KEY `idx_stock_movements_receipt` (`receipt_id`),
  KEY `idx_stock_movements_created_at` (`created_at`),
  CONSTRAINT `stock_movements_ibfk_1` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`),
  CONSTRAINT `stock_movements_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `stock_movements_ibfk_3` FOREIGN KEY (`receipt_id`) REFERENCES `receipts` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `stock_movements`
--

LOCK TABLES `stock_movements` WRITE;
/*!40000 ALTER TABLE `stock_movements` DISABLE KEYS */;
INSERT INTO `stock_movements` VALUES (1,3,'in',5,18,23,NULL,'Пополнение товара',7,NULL,'2025-11-18 01:53:31'),(2,5,'out',1,10,9,42,'Продажа. Чек №Ч-251118-385262',2,17,'2025-11-18 02:19:45'),(3,3,'out',1,23,22,7,'Продажа. Чек №Ч-251118-385262',2,17,'2025-11-18 02:19:45'),(4,4,'out',1,5,4,19,'Продажа. Чек №Ч-251118-385262',2,17,'2025-11-18 02:19:45'),(5,4,'out',4,4,0,19,'Продажа. Чек №Ч-251122-637629',2,18,'2025-11-22 13:53:57'),(6,5,'out',1,9,8,42,'Продажа. Чек №Ч-251123-396836',2,19,'2025-11-23 11:29:56'),(7,5,'out',1,8,7,42,'Продажа. Чек №Ч-251123-259986',2,20,'2025-11-23 16:27:40'),(8,6,'out',1,17,16,500,'Продажа. Чек №Ч-251123-259986',2,20,'2025-11-23 16:27:40'),(9,5,'out',1,7,6,42,'Продажа. Чек №Ч-251123-776092',2,21,'2025-11-23 19:22:56'),(10,5,'out',1,6,5,42,'Продажа. Чек №Ч-251123-973267',2,22,'2025-11-23 19:26:13'),(11,5,'out',1,5,4,42,'Продажа. Чек №Ч-251124-337099',2,23,'2025-11-24 00:48:57'),(12,1,'out',2,18,16,40,'Продажа. Чек №Ч-251124-337099',2,23,'2025-11-24 00:48:57'),(13,1,'out',2,16,14,40,'Продажа. Чек №Ч-251124-087559',2,24,'2025-11-24 01:01:27'),(14,5,'out',1,4,3,42,'Продажа. Чек №Ч-251124-017586. Продано: 20 таблетка. Остаток таблеток: 10/30',2,25,'2025-11-24 02:06:57'),(15,5,'out',1,3,2,42,'Продажа. Чек №Ч-251124-300720. Продано: 25 таблетка. Остаток таблеток: 15/30',2,26,'2025-11-24 13:51:40'),(16,4,'in',10,0,10,NULL,'Объединение с существующим товаром \"Снуп\". Добавлено: 10 упаковок',7,NULL,'2025-11-25 17:01:19'),(17,4,'out',1,10,9,19,'Продажа. Чек №Ч-260205-353751',8,27,'2026-02-05 01:19:14'),(18,5,'out',2,2,0,42,'Продажа. Чек №Ч-260205-647583',8,28,'2026-02-05 01:24:07'),(19,5,'in',1,0,1,NULL,'Срок годности: 06.02.2030',1,NULL,'2026-02-06 23:23:16'),(20,4,'out',1,9,8,19,'Продажа. Чек №Ч-260206-297004. Продано: 2 спрей. Остаток таблеток: 0/2',8,29,'2026-02-06 23:24:57'),(21,3,'out',4,22,18,7,'Продажа. Чек №Ч-260206-297004. Продано: 4 таблетка. Остаток таблеток: 0/1',8,29,'2026-02-06 23:24:57'),(22,5,'out',1,1,0,46,'Продажа. Чек №Ч-260206-297004. Продано: 30 таблетка. Остаток таблеток: 15/30',8,29,'2026-02-06 23:24:57');
/*!40000 ALTER TABLE `stock_movements` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-03-05 22:07:40
