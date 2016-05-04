source rubis.sql;
source categories.sql;
source regions.sql;
GRANT ALL ON rubis.* TO 'rubis'@'%' IDENTIFIED BY 'rubis';
GRANT ALL ON rubis.* TO 'rubis'@'localhost' IDENTIFIED BY 'rubis';
