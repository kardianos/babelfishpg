#!/bin/sh
cd ${BABELFISH_HOME}/bin

USERNAME="${USERNAME:-bfu}"
PASSWORD="${PASSWORD:-5588BOX}"
DATABASE="${DATABASE:-bf}"
MIGRATION_MODE="${MIGRATION_MODE:-single-db}"

# Run if new.
if [ ! -f ${BABELFISH_DATA}/postgresql.conf ]; then
	./initdb -D ${BABELFISH_DATA}/ -E "UTF8"
	cat <<- EOF >> ${BABELFISH_DATA}/pg_hba.conf
		# Allow all connections
		host	all	all	0.0.0.0/0	md5
		host	all	all	::0/0	md5
	EOF
	cat <<- EOF >> ${BABELFISH_DATA}/postgresql.conf
		# BABELFISH OPTIONS
		listen_addresses = '*'
		allow_system_table_mods = on
		shared_preload_libraries = 'babelfishpg_tds'
		babelfishpg_tds.listen_addresses = '*'

		# General Options
		max_connections = 303
		superuser_reserved_connections = 3
		effective_io_concurrency = 16 # 1-1000
		shared_buffers = 1024MB # (start with 25% of ram)
		work_mem = 512MB # Used for ORDER BY, sort, and distinct. Increase for more connections.
		maintenance_work_mem = 256MB # (start with 5% of ram)
	EOF
	./pg_ctl -D ${BABELFISH_DATA}/ start
	./psql -c "CREATE USER ${USERNAME} WITH SUPERUSER CREATEDB CREATEROLE PASSWORD '${PASSWORD}' INHERIT;" \
		-c "DROP DATABASE IF EXISTS ${DATABASE};" \
		-c "CREATE DATABASE ${DATABASE} OWNER ${USERNAME};" \
		-c "\c ${DATABASE}" \
		-c "CREATE EXTENSION IF NOT EXISTS \"babelfishpg_tds\" CASCADE;" \
		-c "GRANT ALL ON SCHEMA sys to ${USERNAME};" \
		-c "ALTER USER ${USERNAME} CREATEDB;" \
		-c "ALTER SYSTEM SET babelfishpg_tsql.database_name = '${DATABASE}';" \
		-c "SELECT pg_reload_conf();" \
		-c "ALTER DATABASE ${DATABASE} SET babelfishpg_tsql.migration_mode = '${MIGRATION_MODE}';" \
		-c "SELECT pg_reload_conf();" \
		-c "CALL SYS.INITIALIZE_BABELFISH('${USERNAME}');"
	./pg_ctl -D ${BABELFISH_DATA}/ stop
fi

./postgres -D ${BABELFISH_DATA}/ -i
