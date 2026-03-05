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
-- Table structure for table `products`
--

DROP TABLE IF EXISTS `products`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `products` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `barcode` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `qr_code` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `price` double NOT NULL,
  `stock` int NOT NULL DEFAULT '0',
  `unit` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `units_per_package` int NOT NULL DEFAULT '1',
  `unit_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'шт',
  `inventory_code` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `organization` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `shelf_location` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `manufacturer_id` int DEFAULT NULL,
  `composition` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `indications` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `preparation_method` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `requires_prescription` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `partial_units` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `barcode` (`barcode`),
  KEY `idx_products_barcode` (`barcode`),
  KEY `idx_products_manufacturer` (`manufacturer_id`),
  CONSTRAINT `products_ibfk_1` FOREIGN KEY (`manufacturer_id`) REFERENCES `manufacturers` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `products`
--

LOCK TABLES `products` WRITE;
/*!40000 ALTER TABLE `products` DISABLE KEYS */;
INSERT INTO `products` VALUES (1,'нурофен','5000158105317',NULL,40,14,'упаковка',15,'таблетка',NULL,NULL,NULL,1,'лывлаорлыфоаи 0.5г,фыловаилоыиа 1г, лыоварлоиа 0.5г','ывдарфыдраидор.ыварфыдоаридо,офыривадордгндгф.фывларщгфынпа дгрфиуда.фывлагп фщгуанмид','лганпфывщгарищгнфпуца. дышвпащгфы лгнфыпващгн лгныпващг гыпващгнп лгфынпваг гнпыащгн гфынвпащг гныпва гныфпващгнп щгнпыфв пгм пщгнпыва гнпыва',0,'2025-11-13 01:38:08','2025-11-24 02:05:21',0),(2,'но-шпа','3582910065449',NULL,20,0,'упаковка',10,'таблетка',NULL,NULL,NULL,2,'ывларлыов 0.5гж лыфоврали фылвао','лроыват щшоыварфы  щшывоащ шы шырв ашр фзыары вол зы врашзгрыв а шзгр зшрафывра зшрзшыгвра','фдыловардшфгукра ышвр ащшгфры  шыга шгрышга фыгшгар щшрыфызвшагр  фызвшагар зшгыуаршпишкрщш  кпашфщщывагр',0,'2025-11-13 01:40:52','2025-11-24 02:05:21',0),(3,'влажная салфетка','4884000060327',NULL,7,18,'упаковка',1,'таблетка','10','Бозор','С-01',3,NULL,NULL,NULL,0,'2025-11-15 01:32:36','2026-02-06 23:24:57',0),(4,'Снуп','4011548045435','010401154804543521АП5400Ц2ВЧВЗЬ91УУ1092я8йАшоВтФ2тНЗщЩ0рВОл5ыЦншЩ6.ОШмЬЗ7виК+ЦДт7Й=',19,8,'упаковка',2,'спрей','102','Азия фарм','A-06',4,NULL,NULL,NULL,0,'2025-11-17 10:58:52','2026-02-06 23:24:57',0),(5,'диабетон','4607159864963','010460715986496321ФЬУ19ЦР0ЯП2П591УУ1092Нс7аШ6цЯЙрЕВ860ч0йЦрП2+КтачиТшИДгДуАвкТО4уУ=',46,0,'упаковка',30,'таблетка','111','Азия фарм','A-01',5,NULL,NULL,NULL,1,'2025-11-17 12:01:23','2026-02-06 23:24:57',15),(6,'парапара','123456789',NULL,500,16,'упаковка',10,'таблетка','INV-81423','Азия фарм','A-01',2,NULL,NULL,NULL,0,'2025-11-17 17:52:25','2025-11-24 02:05:21',0);
/*!40000 ALTER TABLE `products` ENABLE KEYS */;
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
