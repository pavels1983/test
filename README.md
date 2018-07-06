# Greenplum-DB 5.9 Dockerfile

For build:
* Download GP binaries from https://network.pivotal.io/products/pivotal-gpdb#/releases/118471/file_groups/1013
* cd [docker working directory]
* docker build -t gp59-image .

For start:
* docker run -i -p 5432:5432 gpdb-image
* su - gpadmin
* psql
* \list
