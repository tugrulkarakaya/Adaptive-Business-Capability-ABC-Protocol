-- SQL Developer / F5. Export one batched source, in ten sequential parts.
-- Set these three values, create the output folder, and select the intended connection.
-- Use forward slashes and paths without spaces. Use the mapped drive when required.
SET DEFINE ON
DEFINE single_export_root = Y:/work/your-checkout/icms/scripts/data-export
DEFINE single_export_dir = Y:/exports
DEFINE single_export_query = exports/01-contact-person.sql

SET TERMOUT ON
SET VERIFY OFF
SET FEEDBACK OFF
SET SQLFORMAT default
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
WHENEVER OSERROR EXIT FAILURE ROLLBACK

BEGIN
    IF '&single_export_query' NOT IN (
        'exports/01-contact-person.sql',
        'exports/02-eplatform.sql',
        'exports/03-ep-auth-cp.sql',
        'exports/04-account-code-on-ep.sql',
        'exports/05-confirmation-routing.sql',
        'exports/06-booking-code.sql',
        'exports/07-settlement-routing.sql',
        'exports/08-account.sql',
        'lookups/04-ep-auth-venue-code.sql'
    ) THEN
        RAISE_APPLICATION_ERROR(-20003,
            'Select a batch-enabled source script. Small lookup tables use the single-batch example with 1 0.');
    END IF;
END;
/

COLUMN single_export_prefix NEW_VALUE single_export_prefix NOPRINT
SELECT TO_CHAR(SYSTIMESTAMP, 'YYYYMMDD_HH24MISS_FF6') || '_'
       || SYS_CONTEXT('USERENV', 'SESSIONID') || '_'
       || REPLACE(REGEXP_SUBSTR('&single_export_query', '/[0-9]+-([a-z0-9-]+)\.sql$', 1, 1, NULL, 1), '-', '_')
       AS single_export_prefix
FROM dual;
COLUMN single_export_prefix CLEAR

cd &single_export_root
PROMPT [SINGLE-TABLE] Exporting &single_export_query in parts 0 through 9.
PROMPT [SINGLE-TABLE] CSVs and per-batch logs use prefix &single_export_dir/&single_export_prefix
@csv/export-sql-only.sql "&single_export_dir/&single_export_prefix._part_0.csv" &single_export_query 10 0
@csv/export-sql-only.sql "&single_export_dir/&single_export_prefix._part_1.csv" &single_export_query 10 1
@csv/export-sql-only.sql "&single_export_dir/&single_export_prefix._part_2.csv" &single_export_query 10 2
@csv/export-sql-only.sql "&single_export_dir/&single_export_prefix._part_3.csv" &single_export_query 10 3
@csv/export-sql-only.sql "&single_export_dir/&single_export_prefix._part_4.csv" &single_export_query 10 4
@csv/export-sql-only.sql "&single_export_dir/&single_export_prefix._part_5.csv" &single_export_query 10 5
@csv/export-sql-only.sql "&single_export_dir/&single_export_prefix._part_6.csv" &single_export_query 10 6
@csv/export-sql-only.sql "&single_export_dir/&single_export_prefix._part_7.csv" &single_export_query 10 7
@csv/export-sql-only.sql "&single_export_dir/&single_export_prefix._part_8.csv" &single_export_query 10 8
@csv/export-sql-only.sql "&single_export_dir/&single_export_prefix._part_9.csv" &single_export_query 10 9
PROMPT [SINGLE-TABLE] Check Script Output and all ten CSV/log pairs before using the data.
