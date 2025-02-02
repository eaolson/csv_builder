/*
Install script for csv_builder. Run in sqlcl or similar
*/

set define on;
accept csv_schema char prompt 'Schema to install CSV_BUILDER in: '
grant execute on sys.dbms_sql to &&csv_schema;
alter session set current_schema=&&csv_schema;
@src/csv_builder.pks
@src/csv_builder.pkb
