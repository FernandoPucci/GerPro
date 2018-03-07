--
-- PostgreSQL database cluster dump
--

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Drop databases
--

DROP DATABASE gerpro_dev;




--
-- Drop roles
--

DROP ROLE postgres;


--
-- Roles
--

CREATE ROLE postgres;
ALTER ROLE postgres WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION BYPASSRLS PASSWORD 'md5a3556571e93b0d20722ba62be61e8c2d';
ALTER ROLE postgres SET "TimeZone" TO '+03:00';






--
-- Database creation
--

CREATE DATABASE gerpro_dev WITH TEMPLATE = template0 OWNER = postgres CONNECTION LIMIT = 25;
REVOKE CONNECT,TEMPORARY ON DATABASE template1 FROM PUBLIC;
GRANT CONNECT ON DATABASE template1 TO PUBLIC;


\connect gerpro_dev

SET default_transaction_read_only = off;

