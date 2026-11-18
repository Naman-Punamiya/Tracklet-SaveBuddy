-- ============================================================================
-- Tracklet SaveBuddy: Production Pre-Deployment Read-Only Inspection Script
-- Target: Supabase PostgreSQL Database (SQL Editor)
-- Purpose: Verify production schema, casing, foreign keys, indexes, data counts,
--          type compatibility, target uniqueness, and orphan integrity before
--          running V20261117_1__cascade_delete_book_expenses.sql
-- SAFETY: STRICTLY READ-ONLY (SELECT ONLY, NO DDL, NO DML, NO TEMP TABLES, NO WRITE PROCEDURES)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- SECTION 1: Database Environment, Current Schema, and Search Path
-- ----------------------------------------------------------------------------
SELECT
    current_database() AS current_database,
    current_schema() AS current_schema,
    current_user AS connected_user,
    current_setting('search_path') AS search_path,
    version() AS postgres_version;

-- ----------------------------------------------------------------------------
-- SECTION 2: Table Existence, Exact Casing, and Ambiguity Detection
-- Identifies whether tables are lowercase (expenses) or mixed-case ("Expenses").
-- Explicitly flags ambiguity if multiple case variants exist in CURRENT_SCHEMA.
-- ----------------------------------------------------------------------------
SELECT
    CURRENT_SCHEMA AS current_schema,
    t.target_name,
    COUNT(c.relname) AS match_count,
    COALESCE(string_agg(quote_ident(c.relname), ', ' ORDER BY c.relname), '[None]') AS matching_tables,
    CASE 
        WHEN COUNT(c.relname) = 1 THEN 'OK: Uniquely resolved to ' || quote_ident(MAX(c.relname))
        WHEN COUNT(c.relname) = 0 THEN 'FAIL: Table not found in current schema'
        ELSE 'FAIL: Ambiguity detected (' || COUNT(c.relname) || ' variants: ' || string_agg(quote_ident(c.relname), ', ' ORDER BY c.relname) || ')'
    END AS resolution_status,
    CASE
        WHEN COUNT(c.relname) = 1 AND MAX(c.relname) = lower(MAX(c.relname)) THEN 'Lowercase (' || MAX(c.relname) || ')'
        WHEN COUNT(c.relname) = 1 THEN 'Quoted / Mixed-Case ("' || MAX(c.relname) || '")'
        WHEN COUNT(c.relname) > 1 THEN 'Multiple Casing Variants'
        ELSE 'None'
    END AS casing_format
FROM (
    SELECT 'books' AS target_name
    UNION ALL
    SELECT 'expenses' AS target_name
) t
LEFT JOIN (
    pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = CURRENT_SCHEMA AND c.relkind IN ('r', 'p')
) ON lower(c.relname) = t.target_name
GROUP BY t.target_name
ORDER BY t.target_name;

-- ----------------------------------------------------------------------------
-- SECTION 3: Exact Columns and Data Types for Resolved Tables
-- Only queries columns for uniquely resolved tables. If a table is missing or
-- ambiguous, reports the resolution status clearly without failing.
-- ----------------------------------------------------------------------------
WITH table_targets AS (
    SELECT 'books' AS target_name
    UNION ALL
    SELECT 'expenses' AS target_name
),
table_resolution AS (
    SELECT
        t.target_name,
        count(c.relname) AS match_count,
        CASE WHEN count(c.relname) = 1 THEN max(c.relname) ELSE NULL END AS resolved_name,
        CASE WHEN count(c.relname) = 1 THEN max(c.oid) ELSE NULL END AS resolved_oid,
        CASE
            WHEN count(c.relname) = 0 THEN 'FAIL: Table not found in current schema'
            WHEN count(c.relname) > 1 THEN 'FAIL: Ambiguous table name (' || count(c.relname) || ' variants: ' || string_agg(quote_ident(c.relname), ', ') || ')'
            ELSE 'OK: Resolved to ' || quote_ident(max(c.relname))
        END AS resolution_status
    FROM table_targets t
    LEFT JOIN (
        pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = CURRENT_SCHEMA AND c.relkind IN ('r', 'p')
    ) ON lower(c.relname) = t.target_name
    GROUP BY t.target_name
)
SELECT
    tr.target_name,
    tr.resolved_name AS table_name,
    a.attnum AS ordinal_position,
    a.attname AS column_name,
    pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
    a.attnotnull AS is_not_null,
    pg_catalog.pg_get_expr(ad.adbin, ad.adrelid) AS column_default,
    tr.resolution_status
FROM table_resolution tr
LEFT JOIN pg_attribute a ON a.attrelid = tr.resolved_oid AND a.attnum > 0 AND NOT a.attisdropped
LEFT JOIN pg_attrdef ad ON ad.adrelid = a.attrelid AND ad.adnum = a.attnum
ORDER BY tr.target_name, a.attnum;

-- ----------------------------------------------------------------------------
-- SECTION 4: All Foreign Keys on Expenses Table
-- Inspects constraint names, referencing/referenced columns, ordinal positions,
-- composite FK detection, and ON DELETE / ON UPDATE actions.
-- Distinguishes exact target FK (Expenses.book_id -> Books.id) from composite or unrelated FKs.
-- ----------------------------------------------------------------------------
WITH table_targets AS (
    SELECT 'books' AS target_name
    UNION ALL
    SELECT 'expenses' AS target_name
),
table_resolution AS (
    SELECT
        t.target_name,
        count(c.relname) AS match_count,
        CASE WHEN count(c.relname) = 1 THEN max(c.relname) ELSE NULL END AS resolved_name,
        CASE WHEN count(c.relname) = 1 THEN max(c.oid) ELSE NULL END AS resolved_oid,
        CASE
            WHEN count(c.relname) = 0 THEN 'FAIL: Table not found in current schema'
            WHEN count(c.relname) > 1 THEN 'FAIL: Ambiguous table name (' || count(c.relname) || ' variants)'
            ELSE 'OK'
        END AS resolution_status
    FROM table_targets t
    LEFT JOIN (
        pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = CURRENT_SCHEMA AND c.relkind IN ('r', 'p')
    ) ON lower(c.relname) = t.target_name
    GROUP BY t.target_name
),
resolved AS (
    SELECT
        max(CASE WHEN target_name = 'books' THEN resolved_name END) AS book_table,
        max(CASE WHEN target_name = 'books' THEN resolved_oid END) AS book_oid,
        max(CASE WHEN target_name = 'expenses' THEN resolved_name END) AS expense_table,
        max(CASE WHEN target_name = 'expenses' THEN resolved_oid END) AS expense_oid
    FROM table_resolution
)
SELECT
    c.conname AS constraint_name,
    t1.relname AS referencing_table,
    a1.attname AS referencing_column,
    t2.relname AS referenced_table,
    a2.attname AS referenced_column,
    s.i AS column_position,
    array_length(c.conkey, 1) AS total_columns_in_fk,
    CASE 
        WHEN array_length(c.conkey, 1) > 1 THEN 'YES (Composite FK: ' || array_length(c.conkey, 1) || ' cols)'
        ELSE 'NO (Single-Column FK)'
    END AS is_composite,
    CASE c.confdeltype
        WHEN 'c' THEN 'CASCADE'
        WHEN 'n' THEN 'SET NULL'
        WHEN 'd' THEN 'SET DEFAULT'
        WHEN 'r' THEN 'RESTRICT'
        WHEN 'a' THEN 'NO ACTION'
        ELSE c.confdeltype::text
    END AS on_delete_rule,
    CASE c.confupdtype
        WHEN 'c' THEN 'CASCADE'
        WHEN 'n' THEN 'SET NULL'
        WHEN 'd' THEN 'SET DEFAULT'
        WHEN 'r' THEN 'RESTRICT'
        WHEN 'a' THEN 'NO ACTION'
        ELSE c.confupdtype::text
    END AS on_update_rule,
    CASE
        WHEN r.book_oid IS NOT NULL AND c.confrelid = r.book_oid AND array_length(c.conkey, 1) = 1
             AND a1.attname = 'book_id' AND a2.attname = 'id'
        THEN 'EXACT TARGET FK (Expenses.book_id -> Books.id)'
        WHEN r.book_oid IS NOT NULL AND c.confrelid = r.book_oid AND array_length(c.conkey, 1) > 1
             AND a1.attname = 'book_id'
        THEN 'COMPOSITE FK to Books (involves book_id)'
        WHEN a1.attname = 'book_id' AND (r.book_oid IS NULL OR c.confrelid <> r.book_oid)
        THEN 'UNRELATED FK on book_id (references table other than Books: ' || quote_ident(t2.relname) || ')'
        WHEN a1.attname = 'book_id' AND r.book_oid IS NOT NULL AND c.confrelid = r.book_oid AND a2.attname <> 'id'
        THEN 'MISMATCHED FK on book_id (references Books.' || quote_ident(a2.attname) || ' instead of id)'
        ELSE 'OTHER FK on Expenses'
    END AS target_fk_assessment
FROM resolved r
JOIN pg_constraint c ON c.conrelid = r.expense_oid AND c.contype = 'f'
JOIN pg_class t1 ON t1.oid = c.conrelid
JOIN pg_class t2 ON t2.oid = c.confrelid
CROSS JOIN LATERAL generate_subscripts(c.conkey, 1) s(i)
JOIN pg_attribute a1 ON a1.attrelid = c.conrelid AND a1.attnum = c.conkey[s.i]
JOIN pg_attribute a2 ON a2.attrelid = c.confrelid AND a2.attnum = c.confkey[s.i]
ORDER BY c.conname, s.i;

-- ----------------------------------------------------------------------------
-- SECTION 5: All Indexes on Expenses Table
-- Accurately identifies the indexed table, evaluates validity (indisvalid/indisready),
-- detects partial predicates (indpred), and distinguishes leading index keys,
-- non-leading index keys, and INCLUDE-only columns.
-- ----------------------------------------------------------------------------
WITH table_targets AS (
    SELECT 'expenses' AS target_name
),
table_resolution AS (
    SELECT
        t.target_name,
        count(c.relname) AS match_count,
        CASE WHEN count(c.relname) = 1 THEN max(c.relname) ELSE NULL END AS resolved_name,
        CASE WHEN count(c.relname) = 1 THEN max(c.oid) ELSE NULL END AS resolved_oid
    FROM table_targets t
    LEFT JOIN (
        pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = CURRENT_SCHEMA AND c.relkind IN ('r', 'p')
    ) ON lower(c.relname) = t.target_name
    GROUP BY t.target_name
),
resolved AS (
    SELECT
        max(resolved_name) AS expense_table,
        max(resolved_oid) AS expense_oid
    FROM table_resolution
)
SELECT
    i.relname AS index_name,
    t.relname AS table_name,
    k.n + 1 AS column_position,
    COALESCE(a.attname, pg_get_indexdef(ix.indexrelid, k.n + 1, false)) AS column_or_expression,
    CASE
        WHEN k.n < ix.indnkeyatts THEN 'KEY'
        ELSE 'INCLUDE'
    END AS column_type,
    CASE
        WHEN a.attname = 'book_id' AND k.n = 0 AND k.n < ix.indnkeyatts 
             THEN 'Leading index key'
        WHEN a.attname = 'book_id' AND k.n > 0 AND k.n < ix.indnkeyatts 
             THEN 'Non-leading index key'
        WHEN a.attname = 'book_id' AND k.n >= ix.indnkeyatts 
             THEN 'Included column only'
        ELSE 'Not book_id'
    END AS book_id_role,
    ix.indisvalid AS is_valid,
    ix.indisready AS is_ready,
    ix.indislive AS is_live,
    (ix.indpred IS NOT NULL) AS is_partial,
    pg_get_expr(ix.indpred, ix.indrelid) AS partial_predicate,
    CASE
        WHEN a.attname = 'book_id' THEN
            CASE
                WHEN NOT ix.indislive THEN 'UNSUITABLE: Index not live (indislive=false)'
                WHEN NOT ix.indisvalid THEN 'UNSUITABLE: Invalid index (indisvalid=false)'
                WHEN NOT ix.indisready THEN 'UNSUITABLE: Index not ready (indisready=false)'
                WHEN am.amname <> 'btree' THEN 'UNSUITABLE: Non-B-tree index access method (' || am.amname || '; B-tree required for FK lookup)'
                WHEN ix.indpred IS NOT NULL THEN 'PARTIAL: Has predicate (WHERE ...) - NOT universally sufficient for FK delete lookups'
                WHEN k.n >= ix.indnkeyatts THEN 'UNSUITABLE: Included column only (NO FK lookup support; payload only)'
                WHEN k.n > 0 THEN 'PARTIAL SUPPORT: Non-leading key column (requires leading columns)'
                WHEN k.n = 0 THEN 'SUITABLE: Full leading index key (Optimal FK lookup / delete support)'
            END
        ELSE 'N/A (Not book_id)'
    END AS fk_suitability,
    ix.indnatts AS total_columns,
    ix.indnkeyatts AS key_columns,
    ix.indisunique AS is_unique,
    ix.indisprimary AS is_primary,
    am.amname AS index_type,
    pg_get_indexdef(ix.indexrelid) AS index_definition
FROM resolved r
JOIN pg_index ix ON ix.indrelid = r.expense_oid
JOIN pg_class t ON t.oid = ix.indrelid
JOIN pg_class i ON i.oid = ix.indexrelid
JOIN pg_am am ON am.oid = i.relam
CROSS JOIN LATERAL generate_subscripts(ix.indkey, 1) k(n)
LEFT JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ix.indkey[k.n]
ORDER BY i.relname, k.n;

-- ----------------------------------------------------------------------------
-- SECTION 6: Total Book and Expense Counts & Orphaned References
-- Dynamically evaluates record counts only if tables are uniquely resolved.
-- Orphan count is guarded to ensure both tables, required columns, and compatible
-- types exist before executing dynamic SQL.
-- ----------------------------------------------------------------------------
WITH table_targets AS (
    SELECT 'books' AS target_name
    UNION ALL
    SELECT 'expenses' AS target_name
),
table_resolution AS (
    SELECT
        t.target_name,
        count(c.relname) AS match_count,
        CASE WHEN count(c.relname) = 1 THEN max(c.relname) ELSE NULL END AS resolved_name,
        CASE WHEN count(c.relname) = 1 THEN max(c.oid) ELSE NULL END AS resolved_oid,
        CASE
            WHEN count(c.relname) = 0 THEN 'Table not found'
            WHEN count(c.relname) > 1 THEN 'Ambiguous (' || count(c.relname) || ' variants)'
            ELSE 'OK'
        END AS status
    FROM table_targets t
    LEFT JOIN (
        pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = CURRENT_SCHEMA AND c.relkind IN ('r', 'p')
    ) ON lower(c.relname) = t.target_name
    GROUP BY t.target_name
),
resolved AS (
    SELECT
        max(CASE WHEN target_name = 'books' THEN resolved_name END) AS book_table,
        max(CASE WHEN target_name = 'books' THEN resolved_oid END) AS book_oid,
        max(CASE WHEN target_name = 'books' THEN match_count END) AS book_match_count,
        max(CASE WHEN target_name = 'books' THEN status END) AS book_status,

        max(CASE WHEN target_name = 'expenses' THEN resolved_name END) AS expense_table,
        max(CASE WHEN target_name = 'expenses' THEN resolved_oid END) AS expense_oid,
        max(CASE WHEN target_name = 'expenses' THEN match_count END) AS expense_match_count,
        max(CASE WHEN target_name = 'expenses' THEN status END) AS expense_status
    FROM table_resolution
),
cols AS (
    SELECT
        r.*,
        EXISTS (
            SELECT 1 FROM pg_attribute a 
            WHERE a.attrelid = r.book_oid AND a.attname = 'id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS book_id_exists,
        EXISTS (
            SELECT 1 FROM pg_attribute a 
            WHERE a.attrelid = r.expense_oid AND a.attname = 'book_id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS expense_book_id_exists,
        EXISTS (
            SELECT 1 FROM pg_attribute a 
            WHERE a.attrelid = r.expense_oid AND a.attname = 'id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS expense_id_exists,
        (
            SELECT pg_catalog.format_type(a.atttypid, a.atttypmod)
            FROM pg_attribute a
            WHERE a.attrelid = r.expense_oid AND a.attname = 'book_id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS expense_book_id_type,
        (
            SELECT pg_catalog.format_type(a.atttypid, a.atttypmod)
            FROM pg_attribute a
            WHERE a.attrelid = r.book_oid AND a.attname = 'id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS book_id_type,
        EXISTS (
            SELECT 1
            FROM pg_attribute a_exp
            JOIN pg_attribute a_book ON a_book.attrelid = r.book_oid AND a_book.attname = 'id' AND a_book.attnum > 0 AND NOT a_book.attisdropped
            JOIN pg_operator o ON o.oprname = '=' AND o.oprleft = a_exp.atttypid AND o.oprright = a_book.atttypid
            JOIN pg_amop am ON am.amopopr = o.oid
            JOIN pg_am a ON a.oid = am.amopmethod AND a.amname = 'btree'
            WHERE a_exp.attrelid = r.expense_oid AND a_exp.attname = 'book_id' AND a_exp.attnum > 0 AND NOT a_exp.attisdropped
        ) AS types_are_fk_compatible
    FROM resolved r
),
queries AS (
    SELECT
        c.*,
        CASE
            WHEN c.book_match_count = 1 
            THEN format('SELECT count(*) AS count FROM %I.%I', CURRENT_SCHEMA, c.book_table)
            ELSE NULL
        END AS q_books,
        CASE
            WHEN c.expense_match_count = 1 
            THEN format('SELECT count(*) AS count FROM %I.%I', CURRENT_SCHEMA, c.expense_table)
            ELSE NULL
        END AS q_expenses,
        CASE
            WHEN c.book_match_count = 1 AND c.expense_match_count = 1 
                 AND c.book_id_exists AND c.expense_book_id_exists AND c.types_are_fk_compatible
            THEN format(
                'SELECT count(*) AS count FROM %I.%I e WHERE e.book_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM %I.%I b WHERE b.id = e.book_id)',
                CURRENT_SCHEMA, c.expense_table, CURRENT_SCHEMA, c.book_table
            )
            ELSE NULL
        END AS q_orphans
    FROM cols c
)
SELECT
    COALESCE(q.book_table, 'UNRESOLVED (' || q.book_status || ')') AS book_table,
    COALESCE(q.expense_table, 'UNRESOLVED (' || q.expense_status || ')') AS expense_table,
    (xpath('/table/row/count/text()', query_to_xml(q.q_books, true, false, '')))[1]::text::bigint AS total_books,
    (xpath('/table/row/count/text()', query_to_xml(q.q_expenses, true, false, '')))[1]::text::bigint AS total_expenses,
    (xpath('/table/row/count/text()', query_to_xml(q.q_orphans, true, false, '')))[1]::text::bigint AS orphaned_expenses_count,
    CASE
        WHEN q.q_orphans IS NULL THEN
            'SKIPPED orphan check: ' || 
            CASE 
                WHEN q.book_match_count <> 1 THEN 'Books table unresolved (' || q.book_status || '). '
                WHEN NOT q.book_id_exists THEN 'Books.id column missing. '
                ELSE ''
            END ||
            CASE 
                WHEN q.expense_match_count <> 1 THEN 'Expenses table unresolved (' || q.expense_status || '). '
                WHEN NOT q.expense_book_id_exists THEN 'Expenses.book_id column missing. '
                ELSE ''
            END ||
            CASE
                WHEN q.book_id_exists AND q.expense_book_id_exists AND NOT q.types_are_fk_compatible
                THEN 'Incompatible column types (Expenses.book_id [' || q.expense_book_id_type || '] vs Books.id [' || q.book_id_type || ']). '
                ELSE ''
            END
        WHEN (xpath('/table/row/count/text()', query_to_xml(q.q_orphans, true, false, '')))[1]::text::bigint = 0
            THEN 'OK: Referential integrity clean (0 orphans)'
        ELSE 'FAIL: Orphaned expenses detected! Clean up invalid book_ids before applying cascade FK.'
    END AS orphan_status_diagnostic
FROM queries q;

-- ----------------------------------------------------------------------------
-- SECTION 7: Expense Count Grouped by Book (Including Books with Zero Expenses)
-- Only runs dynamic query if both tables, required columns (Expenses.id, Expenses.book_id,
-- Books.id), and compatible types are confirmed.
-- ----------------------------------------------------------------------------
WITH table_targets AS (
    SELECT 'books' AS target_name
    UNION ALL
    SELECT 'expenses' AS target_name
),
table_resolution AS (
    SELECT
        t.target_name,
        count(c.relname) AS match_count,
        CASE WHEN count(c.relname) = 1 THEN max(c.relname) ELSE NULL END AS resolved_name,
        CASE WHEN count(c.relname) = 1 THEN max(c.oid) ELSE NULL END AS resolved_oid
    FROM table_targets t
    LEFT JOIN (
        pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = CURRENT_SCHEMA AND c.relkind IN ('r', 'p')
    ) ON lower(c.relname) = t.target_name
    GROUP BY t.target_name
),
resolved AS (
    SELECT
        max(CASE WHEN target_name = 'books' THEN resolved_name END) AS book_table,
        max(CASE WHEN target_name = 'books' THEN resolved_oid END) AS book_oid,
        max(CASE WHEN target_name = 'books' THEN match_count END) AS book_match_count,

        max(CASE WHEN target_name = 'expenses' THEN resolved_name END) AS expense_table,
        max(CASE WHEN target_name = 'expenses' THEN resolved_oid END) AS expense_oid,
        max(CASE WHEN target_name = 'expenses' THEN match_count END) AS expense_match_count
    FROM table_resolution
),
cols AS (
    SELECT
        r.*,
        EXISTS (
            SELECT 1 FROM pg_attribute a 
            WHERE a.attrelid = r.book_oid AND a.attname = 'id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS book_id_exists,
        EXISTS (
            SELECT 1 FROM pg_attribute a 
            WHERE a.attrelid = r.expense_oid AND a.attname = 'book_id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS expense_book_id_exists,
        EXISTS (
            SELECT 1 FROM pg_attribute a 
            WHERE a.attrelid = r.expense_oid AND a.attname = 'id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS expense_id_exists,
        EXISTS (
            SELECT 1 FROM pg_attribute a 
            WHERE a.attrelid = r.book_oid AND a.attname = 'name' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS book_name_exists,
        EXISTS (
            SELECT 1
            FROM pg_attribute a_exp
            JOIN pg_attribute a_book ON a_book.attrelid = r.book_oid AND a_book.attname = 'id' AND a_book.attnum > 0 AND NOT a_book.attisdropped
            JOIN pg_operator o ON o.oprname = '=' AND o.oprleft = a_exp.atttypid AND o.oprright = a_book.atttypid
            JOIN pg_amop am ON am.amopopr = o.oid
            JOIN pg_am a ON a.oid = am.amopmethod AND a.amname = 'btree'
            WHERE a_exp.attrelid = r.expense_oid AND a_exp.attname = 'book_id' AND a_exp.attnum > 0 AND NOT a_exp.attisdropped
        ) AS types_are_fk_compatible
    FROM resolved r
),
xml_data AS (
    SELECT
        CASE
            WHEN c.book_match_count = 1 AND c.expense_match_count = 1 
                 AND c.book_id_exists AND c.expense_book_id_exists AND c.expense_id_exists
                 AND c.types_are_fk_compatible
            THEN query_to_xml(
                CASE 
                    WHEN c.book_name_exists THEN
                        format('SELECT b.id AS book_id, b.name::text AS book_name, count(e.id) AS expense_count FROM %I.%I b LEFT JOIN %I.%I e ON e.book_id = b.id GROUP BY b.id, b.name ORDER BY b.id',
                               CURRENT_SCHEMA, c.book_table, CURRENT_SCHEMA, c.expense_table)
                    ELSE
                        format('SELECT b.id AS book_id, ''[No name column]''::text AS book_name, count(e.id) AS expense_count FROM %I.%I b LEFT JOIN %I.%I e ON e.book_id = b.id GROUP BY b.id ORDER BY b.id',
                               CURRENT_SCHEMA, c.book_table, CURRENT_SCHEMA, c.expense_table)
                END,
                true, false, ''
            )
            ELSE NULL
        END AS xml
    FROM cols c
)
SELECT
    (xpath('/row/book_id/text()', r.x))[1]::text::bigint AS book_id,
    (xpath('/row/book_name/text()', r.x))[1]::text AS book_name,
    (xpath('/row/expense_count/text()', r.x))[1]::text::bigint AS expense_count
FROM xml_data xd,
LATERAL unnest(xpath('/table/row', xd.xml)) AS r(x);

-- ----------------------------------------------------------------------------
-- SECTION 8: Orphaned Expense Details (If Any Exist)
-- Returns empty result (0 rows) when database integrity is clean.
-- Does not execute if tables, required columns, or types are unresolved.
-- ----------------------------------------------------------------------------
WITH table_targets AS (
    SELECT 'books' AS target_name
    UNION ALL
    SELECT 'expenses' AS target_name
),
table_resolution AS (
    SELECT
        t.target_name,
        count(c.relname) AS match_count,
        CASE WHEN count(c.relname) = 1 THEN max(c.relname) ELSE NULL END AS resolved_name,
        CASE WHEN count(c.relname) = 1 THEN max(c.oid) ELSE NULL END AS resolved_oid
    FROM table_targets t
    LEFT JOIN (
        pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = CURRENT_SCHEMA AND c.relkind IN ('r', 'p')
    ) ON lower(c.relname) = t.target_name
    GROUP BY t.target_name
),
resolved AS (
    SELECT
        max(CASE WHEN target_name = 'books' THEN resolved_name END) AS book_table,
        max(CASE WHEN target_name = 'books' THEN resolved_oid END) AS book_oid,
        max(CASE WHEN target_name = 'books' THEN match_count END) AS book_match_count,

        max(CASE WHEN target_name = 'expenses' THEN resolved_name END) AS expense_table,
        max(CASE WHEN target_name = 'expenses' THEN resolved_oid END) AS expense_oid,
        max(CASE WHEN target_name = 'expenses' THEN match_count END) AS expense_match_count
    FROM table_resolution
),
cols AS (
    SELECT
        r.*,
        EXISTS (
            SELECT 1 FROM pg_attribute a 
            WHERE a.attrelid = r.book_oid AND a.attname = 'id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS book_id_exists,
        EXISTS (
            SELECT 1 FROM pg_attribute a 
            WHERE a.attrelid = r.expense_oid AND a.attname = 'book_id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS expense_book_id_exists,
        EXISTS (
            SELECT 1 FROM pg_attribute a 
            WHERE a.attrelid = r.expense_oid AND a.attname = 'id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS expense_id_exists,
        EXISTS (
            SELECT 1
            FROM pg_attribute a_exp
            JOIN pg_attribute a_book ON a_book.attrelid = r.book_oid AND a_book.attname = 'id' AND a_book.attnum > 0 AND NOT a_book.attisdropped
            JOIN pg_operator o ON o.oprname = '=' AND o.oprleft = a_exp.atttypid AND o.oprright = a_book.atttypid
            JOIN pg_amop am ON am.amopopr = o.oid
            JOIN pg_am a ON a.oid = am.amopmethod AND a.amname = 'btree'
            WHERE a_exp.attrelid = r.expense_oid AND a_exp.attname = 'book_id' AND a_exp.attnum > 0 AND NOT a_exp.attisdropped
        ) AS types_are_fk_compatible
    FROM resolved r
),
xml_data AS (
    SELECT
        CASE
            WHEN c.book_match_count = 1 AND c.expense_match_count = 1 
                 AND c.book_id_exists AND c.expense_book_id_exists AND c.expense_id_exists
                 AND c.types_are_fk_compatible
            THEN query_to_xml(
                format('SELECT e.id AS expense_id, e.book_id::text AS invalid_book_id FROM %I.%I e WHERE e.book_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM %I.%I b WHERE b.id = e.book_id) LIMIT 100',
                       CURRENT_SCHEMA, c.expense_table, CURRENT_SCHEMA, c.book_table),
                true, false, ''
            )
            ELSE NULL
        END AS xml
    FROM cols c
)
SELECT
    (xpath('/row/expense_id/text()', r.x))[1]::text::bigint AS orphaned_expense_id,
    (xpath('/row/invalid_book_id/text()', r.x))[1]::text AS unreferenced_book_id
FROM xml_data xd,
LATERAL unnest(xpath('/table/row', xd.xml)) AS r(x);

-- ----------------------------------------------------------------------------
-- SECTION 9: Check If idx_expenses_book_id Already Exists (Schema-Wide Collision Check)
-- Checks whether relation idx_expenses_book_id exists anywhere in CURRENT_SCHEMA.
-- Explicitly flags collisions on other tables or non-index relations to prevent silent skips by IF NOT EXISTS.
-- Validates exact index suitability if idx_expenses_book_id exists on Expenses.
-- ----------------------------------------------------------------------------
WITH table_targets AS (
    SELECT 'expenses' AS target_name
),
table_resolution AS (
    SELECT
        t.target_name,
        count(c.relname) AS match_count,
        CASE WHEN count(c.relname) = 1 THEN max(c.relname) ELSE NULL END AS resolved_name,
        CASE WHEN count(c.relname) = 1 THEN max(c.oid) ELSE NULL END AS resolved_oid,
        CASE
            WHEN count(c.relname) = 0 THEN 'Table not found'
            WHEN count(c.relname) > 1 THEN 'Ambiguous'
            ELSE 'OK'
        END AS status
    FROM table_targets t
    LEFT JOIN (
        pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = CURRENT_SCHEMA AND c.relkind IN ('r', 'p')
    ) ON lower(c.relname) = t.target_name
    GROUP BY t.target_name
),
resolved AS (
    SELECT
        max(resolved_name) AS expense_table,
        max(resolved_oid) AS expense_oid,
        max(match_count) AS expense_match_count,
        max(status) AS expense_status
    FROM table_resolution
),
existing_name_relations AS (
    SELECT
        c.oid AS rel_oid,
        c.relname AS relation_name,
        c.relkind::text AS relkind_text,
        n.nspname AS schema_name,
        am.amname AS access_method,
        t.relname AS indexed_table_name,
        ix.indrelid AS indexed_table_oid,
        ix.indisvalid,
        ix.indisready,
        ix.indislive,
        (ix.indpred IS NOT NULL) AS is_partial,
        ix.indnkeyatts,
        ix.indkey[0] AS first_key_attnum,
        a_first.attname AS first_key_attname,
        pg_get_indexdef(c.oid) AS index_def
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = CURRENT_SCHEMA
    LEFT JOIN pg_am am ON am.oid = c.relam
    LEFT JOIN pg_index ix ON ix.indexrelid = c.oid
    LEFT JOIN pg_class t ON t.oid = ix.indrelid
    LEFT JOIN pg_attribute a_first ON a_first.attrelid = ix.indrelid 
                                  AND a_first.attnum = ix.indkey[0] 
                                  AND ix.indkey[0] > 0 
                                  AND NOT a_first.attisdropped
    WHERE c.relname = 'idx_expenses_book_id'
)
SELECT
    CURRENT_SCHEMA AS current_schema,
    COALESCE(r.expense_table, 'UNRESOLVED (' || r.expense_status || ')') AS expense_table,
    'idx_expenses_book_id' AS checked_relation_name,
    CASE 
        WHEN enr.rel_oid IS NULL THEN 
            'DOES NOT EXIST anywhere in schema: Name is available (Migration will create it on Expenses)'
        WHEN enr.relkind_text NOT IN ('i', 'I') THEN
            'COLLISION CONFLICT: Relation "idx_expenses_book_id" exists as non-index relation (relkind=' || enr.relkind_text || ') in current schema! CREATE INDEX will fail!'
        WHEN r.expense_oid IS NULL OR enr.indexed_table_oid <> r.expense_oid THEN
            'COLLISION CONFLICT: ' || CASE WHEN enr.relkind_text = 'I' THEN 'Partitioned index' ELSE 'Index' END || 
            ' named "idx_expenses_book_id" exists on ANOTHER table: ' || quote_ident(COALESCE(enr.indexed_table_name, 'unknown')) || '! CREATE INDEX IF NOT EXISTS will skip creating the index on Expenses!'
        WHEN enr.indislive = false THEN
            'BLOCKER: Index named "idx_expenses_book_id" exists on Expenses (' || quote_ident(enr.indexed_table_name) || ') but is NOT LIVE (indislive=false)! CREATE INDEX IF NOT EXISTS will skip creation!'
        WHEN enr.indisvalid = false THEN
            'BLOCKER: Index named "idx_expenses_book_id" exists on Expenses (' || quote_ident(enr.indexed_table_name) || ') but is INVALID (indisvalid=false)! CREATE INDEX IF NOT EXISTS will skip creation!'
        WHEN enr.indisready = false THEN
            'BLOCKER: Index named "idx_expenses_book_id" exists on Expenses (' || quote_ident(enr.indexed_table_name) || ') but is NOT READY (indisready=false)! CREATE INDEX IF NOT EXISTS will skip creation!'
        WHEN enr.access_method <> 'btree' THEN
            'BLOCKER: Index named "idx_expenses_book_id" exists on Expenses (' || quote_ident(enr.indexed_table_name) || ') but is NON-B-TREE access method (' || enr.access_method || ')! CREATE INDEX IF NOT EXISTS will skip creation!'
        WHEN enr.is_partial THEN
            'BLOCKER: Index named "idx_expenses_book_id" exists on Expenses (' || quote_ident(enr.indexed_table_name) || ') but is PARTIAL (has WHERE predicate)! CREATE INDEX IF NOT EXISTS will skip creation!'
        WHEN enr.indnkeyatts < 1 OR enr.first_key_attname IS NULL OR enr.first_key_attname <> 'book_id' THEN
            'BLOCKER: Index named "idx_expenses_book_id" exists on Expenses (' || quote_ident(enr.indexed_table_name) || ') but first key column is ' || 
            CASE 
                WHEN enr.first_key_attnum = 0 THEN 'an expression'
                WHEN enr.first_key_attname IS NOT NULL THEN quote_ident(enr.first_key_attname) || ' (not book_id)'
                ELSE 'unresolved or INCLUDE-only'
            END || '! CREATE INDEX IF NOT EXISTS will skip creation!'
        ELSE
            'EXISTS on Expenses (' || quote_ident(enr.indexed_table_name) || '): SUITABLE (Valid, Ready, Live, Non-partial B-tree index on book_id' || 
            CASE WHEN enr.relkind_text = 'I' THEN ', partitioned' ELSE '' END || '). Def: ' || enr.index_def
    END AS collision_status,
    CASE
        WHEN enr.rel_oid IS NULL THEN 
            'Migration will execute: CREATE INDEX IF NOT EXISTS idx_expenses_book_id ON Expenses(book_id)'
        WHEN enr.relkind_text IN ('i', 'I') AND r.expense_oid IS NOT NULL AND enr.indexed_table_oid = r.expense_oid
             AND enr.indislive AND enr.indisvalid AND enr.indisready AND NOT enr.is_partial 
             AND enr.access_method = 'btree' AND enr.indnkeyatts >= 1 AND enr.first_key_attname = 'book_id' THEN
            'Migration IF NOT EXISTS will safely skip creation (already suitably indexed on Expenses)'
        ELSE
            'BLOCKER: Do not migrate until name collision or unsuitable index is resolved! Drop, rename, or rebuild the relation.'
    END AS migration_action
FROM resolved r
LEFT JOIN existing_name_relations enr ON true;

-- ----------------------------------------------------------------------------
-- SECTION 10: Migration Pre-Flight Compatibility Checklist
-- Evaluates all safety conditions required by V20261117_1.
-- Safe OID matching: No unsafe regclass casts, no arbitrary LIMIT 1 selections.
-- ----------------------------------------------------------------------------
WITH table_targets AS (
    SELECT 'books' AS target_name
    UNION ALL
    SELECT 'expenses' AS target_name
),
table_resolution AS (
    SELECT
        t.target_name,
        count(c.relname) AS match_count,
        CASE WHEN count(c.relname) = 1 THEN max(c.relname) ELSE NULL END AS resolved_name,
        CASE WHEN count(c.relname) = 1 THEN max(c.oid) ELSE NULL END AS resolved_oid,
        CASE
            WHEN count(c.relname) = 0 THEN 'FAIL: Table not found in current schema'
            WHEN count(c.relname) > 1 THEN 'FAIL: Ambiguous table name (' || count(c.relname) || ' variants: ' || string_agg(quote_ident(c.relname), ', ') || ')'
            ELSE 'OK: Resolved to ' || quote_ident(max(c.relname))
        END AS resolution_status
    FROM table_targets t
    LEFT JOIN (
        pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = CURRENT_SCHEMA AND c.relkind IN ('r', 'p')
    ) ON lower(c.relname) = t.target_name
    GROUP BY t.target_name
),
resolved AS (
    SELECT
        max(CASE WHEN target_name = 'books' THEN resolved_name END) AS book_table,
        max(CASE WHEN target_name = 'books' THEN resolved_oid END) AS book_oid,
        max(CASE WHEN target_name = 'books' THEN match_count END) AS book_match_count,
        max(CASE WHEN target_name = 'books' THEN resolution_status END) AS book_status,

        max(CASE WHEN target_name = 'expenses' THEN resolved_name END) AS expense_table,
        max(CASE WHEN target_name = 'expenses' THEN resolved_oid END) AS expense_oid,
        max(CASE WHEN target_name = 'expenses' THEN match_count END) AS expense_match_count,
        max(CASE WHEN target_name = 'expenses' THEN resolution_status END) AS expense_status
    FROM table_resolution
),
cols AS (
    SELECT
        r.*,
        -- Check column existence
        EXISTS (
            SELECT 1 FROM pg_attribute a 
            WHERE a.attrelid = r.book_oid AND a.attname = 'id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS book_id_exists,
        EXISTS (
            SELECT 1 FROM pg_attribute a 
            WHERE a.attrelid = r.expense_oid AND a.attname = 'book_id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS expense_book_id_exists,
        EXISTS (
            SELECT 1 FROM pg_attribute a 
            WHERE a.attrelid = r.expense_oid AND a.attname = 'id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS expense_id_exists,

        -- Column data types
        (
            SELECT pg_catalog.format_type(a.atttypid, a.atttypmod)
            FROM pg_attribute a
            WHERE a.attrelid = r.expense_oid AND a.attname = 'book_id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS expense_book_id_type,
        (
            SELECT pg_catalog.format_type(a.atttypid, a.atttypmod)
            FROM pg_attribute a
            WHERE a.attrelid = r.book_oid AND a.attname = 'id' AND a.attnum > 0 AND NOT a.attisdropped
        ) AS book_id_type,

        -- Check type compatibility for PostgreSQL foreign key (equality operator in btree)
        EXISTS (
            SELECT 1
            FROM pg_attribute a_exp
            JOIN pg_attribute a_book ON a_book.attrelid = r.book_oid AND a_book.attname = 'id' AND a_book.attnum > 0 AND NOT a_book.attisdropped
            JOIN pg_operator o ON o.oprname = '=' AND o.oprleft = a_exp.atttypid AND o.oprright = a_book.atttypid
            JOIN pg_amop am ON am.amopopr = o.oid
            JOIN pg_am a ON a.oid = am.amopmethod AND a.amname = 'btree'
            WHERE a_exp.attrelid = r.expense_oid AND a_exp.attname = 'book_id' AND a_exp.attnum > 0 AND NOT a_exp.attisdropped
        ) AS types_are_fk_compatible,

        -- Check Books.id uniqueness & FK target suitability
        (
            SELECT
                CASE
                    WHEN ix.indislive = false THEN 'NOT_LIVE'
                    WHEN ix.indisvalid = false THEN 'INVALID'
                    WHEN ix.indisready = false THEN 'NOT_READY'
                    WHEN COALESCE(c_pk.condeferrable, false) = true THEN 'DEFERRABLE:' || COALESCE(c_pk.conname, i.relname)
                    WHEN ix.indimmediate = false THEN 'NOT_IMMEDIATE:' || COALESCE(c_pk.conname, i.relname)
                    WHEN ix.indpred IS NOT NULL THEN 'PARTIAL'
                    WHEN c_pk.contype = 'p' THEN 'PRIMARY_KEY:' || c_pk.conname
                    WHEN c_pk.contype = 'u' THEN 'UNIQUE_CONSTRAINT:' || c_pk.conname
                    ELSE 'UNIQUE_INDEX:' || i.relname
                END
            FROM pg_index ix
            JOIN pg_class i ON i.oid = ix.indexrelid
            LEFT JOIN pg_constraint c_pk ON c_pk.conindid = ix.indexrelid AND c_pk.contype IN ('p', 'u')
            WHERE ix.indrelid = r.book_oid
              AND ix.indisunique = true
              AND ix.indnkeyatts = 1
              AND ix.indkey[0] = (
                  SELECT a.attnum FROM pg_attribute a
                  WHERE a.attrelid = r.book_oid AND a.attname = 'id' AND a.attnum > 0 AND NOT a.attisdropped
              )
            ORDER BY 
                (
                    ix.indisvalid = true
                    AND ix.indisready = true
                    AND ix.indislive = true
                    AND ix.indimmediate = true
                    AND ix.indpred IS NULL
                    AND COALESCE(c_pk.condeferrable, false) = false
                ) DESC,
                (COALESCE(c_pk.contype, '') = 'p') DESC,
                (COALESCE(c_pk.contype, '') = 'u') DESC,
                (COALESCE(c_pk.condeferrable, false) = false) DESC,
                ix.indimmediate DESC,
                ix.indisvalid DESC,
                ix.indisready DESC,
                ix.indislive DESC,
                (ix.indpred IS NULL) DESC,
                i.relname ASC
            FETCH FIRST 1 ROWS ONLY
        ) AS book_id_uniqueness_status
    FROM resolved r
),
index_analysis AS (
    SELECT
        c.expense_oid,
        -- Leading key index on book_id (optimal lookup support for FK operations)
        (
            SELECT i.relname || '|' || ix.indisvalid::text || '|' || ix.indisready::text || '|' || ix.indislive::text || '|' || (ix.indpred IS NOT NULL)::text || '|' || am.amname
            FROM pg_index ix
            JOIN pg_class i ON i.oid = ix.indexrelid
            JOIN pg_am am ON am.oid = i.relam
            CROSS JOIN LATERAL generate_subscripts(ix.indkey, 1) k(n)
            JOIN pg_attribute a ON a.attrelid = ix.indrelid AND a.attnum = ix.indkey[k.n]
            WHERE ix.indrelid = c.expense_oid
              AND a.attname = 'book_id'
              AND k.n = 0
              AND k.n < ix.indnkeyatts
            ORDER BY 
              (am.amname = 'btree' AND ix.indisvalid AND ix.indisready AND ix.indislive AND ix.indpred IS NULL) DESC,
              (am.amname = 'btree') DESC,
              ix.indisvalid DESC,
              (ix.indpred IS NULL) DESC
            FETCH FIRST 1 ROWS ONLY
        ) AS leading_index_info,
        -- Non-leading key index on book_id (composite/partial support only)
        (
            SELECT i.relname || '|' || ix.indisvalid::text || '|' || ix.indisready::text || '|' || ix.indislive::text || '|' || (ix.indpred IS NOT NULL)::text || '|' || am.amname
            FROM pg_index ix
            JOIN pg_class i ON i.oid = ix.indexrelid
            JOIN pg_am am ON am.oid = i.relam
            CROSS JOIN LATERAL generate_subscripts(ix.indkey, 1) k(n)
            JOIN pg_attribute a ON a.attrelid = ix.indrelid AND a.attnum = ix.indkey[k.n]
            WHERE ix.indrelid = c.expense_oid
              AND a.attname = 'book_id'
              AND k.n > 0
              AND k.n < ix.indnkeyatts
            ORDER BY 
              (am.amname = 'btree' AND ix.indisvalid AND ix.indisready AND ix.indislive AND ix.indpred IS NULL) DESC,
              (am.amname = 'btree') DESC,
              ix.indisvalid DESC,
              (ix.indpred IS NULL) DESC
            FETCH FIRST 1 ROWS ONLY
        ) AS nonleading_index_info,
        -- Include-only index on book_id (does NOT support index lookups)
        (
            SELECT i.relname
            FROM pg_index ix
            JOIN pg_class i ON i.oid = ix.indexrelid
            CROSS JOIN LATERAL generate_subscripts(ix.indkey, 1) k(n)
            JOIN pg_attribute a ON a.attrelid = ix.indrelid AND a.attnum = ix.indkey[k.n]
            WHERE ix.indrelid = c.expense_oid
              AND a.attname = 'book_id'
              AND k.n >= ix.indnkeyatts
            FETCH FIRST 1 ROWS ONLY
        ) AS included_index_name
    FROM cols c
),
named_index_analysis AS (
    SELECT
        c_idx.oid AS rel_oid,
        c_idx.relname AS relname,
        c_idx.relkind::text AS relkind_text,
        am.amname AS access_method,
        t.relname AS indexed_table_name,
        ix.indrelid AS indexed_table_oid,
        ix.indisvalid,
        ix.indisready,
        ix.indislive,
        (ix.indpred IS NOT NULL) AS is_partial,
        ix.indnkeyatts,
        ix.indkey[0] AS first_key_attnum,
        a_first.attname AS first_key_attname,
        -- Classification of named relation idx_expenses_book_id
        CASE
            WHEN c_idx.oid IS NULL THEN 'AVAILABLE'
            WHEN c_idx.relkind::text NOT IN ('i', 'I') THEN 'COLLISION_NON_INDEX'
            WHEN c.expense_oid IS NULL OR ix.indrelid <> c.expense_oid THEN 'COLLISION_OTHER_TABLE'
            WHEN ix.indislive = false THEN 'NOT_LIVE'
            WHEN ix.indisvalid = false THEN 'INVALID'
            WHEN ix.indisready = false THEN 'NOT_READY'
            WHEN am.amname <> 'btree' THEN 'NON_BTREE'
            WHEN ix.indpred IS NOT NULL THEN 'PARTIAL'
            WHEN ix.indnkeyatts < 1 OR a_first.attname IS NULL OR a_first.attname <> 'book_id' THEN
                CASE
                    WHEN ix.indkey[0] = 0 THEN 'EXPRESSION'
                    WHEN a_first.attname IS NOT NULL THEN 'WRONG_COLUMN'
                    ELSE 'NOT_BOOK_ID'
                END
            ELSE 'SUITABLE_ON_EXPENSES'
        END AS named_idx_status,
        -- Diagnostic text
        CASE
            WHEN c_idx.oid IS NULL THEN 'Name is available'
            WHEN c_idx.relkind::text NOT IN ('i', 'I') THEN 'Relation exists as non-index (relkind=' || c_idx.relkind::text || ')'
            WHEN c.expense_oid IS NULL OR ix.indrelid <> c.expense_oid THEN
                CASE WHEN c_idx.relkind::text = 'I' THEN 'Partitioned index' ELSE 'Index' END ||
                ' exists on another table (' || quote_ident(COALESCE(t.relname, 'unknown')) || ')'
            WHEN ix.indislive = false THEN 'Index on Expenses is not live (indislive=false)'
            WHEN ix.indisvalid = false THEN 'Index on Expenses is invalid (indisvalid=false)'
            WHEN ix.indisready = false THEN 'Index on Expenses is not ready (indisready=false)'
            WHEN am.amname <> 'btree' THEN 'Index on Expenses is non-B-tree (' || am.amname || ')'
            WHEN ix.indpred IS NOT NULL THEN 'Index on Expenses is partial (has WHERE predicate)'
            WHEN ix.indkey[0] = 0 THEN 'Index on Expenses leading key is an expression'
            WHEN a_first.attname IS NOT NULL THEN 'Index on Expenses indexes ' || quote_ident(a_first.attname) || ' instead of book_id'
            ELSE 'Index on Expenses does not have book_id as leading key'
        END AS named_idx_detail
    FROM cols c
    LEFT JOIN pg_class c_idx ON c_idx.relname = 'idx_expenses_book_id'
                            AND c_idx.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = CURRENT_SCHEMA)
    LEFT JOIN pg_am am ON am.oid = c_idx.relam
    LEFT JOIN pg_index ix ON ix.indexrelid = c_idx.oid
    LEFT JOIN pg_class t ON t.oid = ix.indrelid
    LEFT JOIN pg_attribute a_first ON a_first.attrelid = ix.indrelid 
                                  AND a_first.attnum = ix.indkey[0] 
                                  AND ix.indkey[0] > 0 
                                  AND NOT a_first.attisdropped
),
fk_analysis AS (
    SELECT
        c.expense_oid,
        c.book_oid,
        -- Check constraint named 'fk_expenses_book' across Expenses and its partition hierarchy
        (
            SELECT
                CASE
                    WHEN bool_or(con.contype <> 'f') THEN
                        'NON_FK:' || min(CASE WHEN con.contype <> 'f' THEN con.contype::text END)
                    WHEN bool_or(c.book_oid IS NULL OR con.confrelid <> c.book_oid) THEN
                        'WRONG_TABLE:' || min(CASE WHEN c.book_oid IS NULL OR con.confrelid <> c.book_oid THEN quote_ident(COALESCE(t_ref.relname, 'unknown')) END)
                    WHEN bool_or(array_length(con.conkey, 1) <> 1 OR array_length(con.confkey, 1) <> 1) THEN
                        'COMPOSITE:' || min(CASE WHEN array_length(con.conkey, 1) <> 1 OR array_length(con.confkey, 1) <> 1 THEN array_length(con.conkey, 1)::text END)
                    WHEN bool_or(a1.attname <> 'book_id' OR a2.attname <> 'id') THEN
                        'WRONG_COLS:' || min(CASE WHEN a1.attname <> 'book_id' OR a2.attname <> 'id' THEN quote_ident(COALESCE(a1.attname, '?')) || '->' || quote_ident(COALESCE(a2.attname, '?')) END)
                    WHEN count(*) > 0 THEN 'TARGET_MATCH'
                    ELSE NULL
                END
            FROM pg_constraint con
            LEFT JOIN pg_class t_ref ON t_ref.oid = con.confrelid
            LEFT JOIN pg_attribute a1 ON a1.attrelid = con.conrelid AND a1.attnum = con.conkey[1]
            LEFT JOIN pg_attribute a2 ON a2.attrelid = con.confrelid AND a2.attnum = con.confkey[1]
            WHERE (
                con.conrelid = c.expense_oid
                OR con.conrelid IN (SELECT inhrelid FROM pg_inherits WHERE inhparent = c.expense_oid)
                OR con.conrelid IN (SELECT inhparent FROM pg_inherits WHERE inhrelid = c.expense_oid)
            )
              AND con.conname = 'fk_expenses_book'
        ) AS fk_expenses_book_conflict_status,
        -- Count of exact single-column FKs connecting Expenses.book_id -> Books.id
        (
            SELECT count(DISTINCT con.oid)
            FROM pg_constraint con
            JOIN pg_attribute a1 ON a1.attrelid = con.conrelid AND a1.attnum = con.conkey[1]
            JOIN pg_attribute a2 ON a2.attrelid = con.confrelid AND a2.attnum = con.confkey[1]
            WHERE con.conrelid = c.expense_oid
              AND con.confrelid = c.book_oid
              AND con.contype = 'f'
              AND array_length(con.conkey, 1) = 1
              AND array_length(con.confkey, 1) = 1
              AND a1.attname = 'book_id'
              AND a2.attname = 'id'
        ) AS exact_target_fk_count,
        -- Deterministic primary exact target FK (prioritizing fk_expenses_book, then CASCADE, then name)
        (
            SELECT con.conname || '|' || con.confdeltype::text
            FROM pg_constraint con
            JOIN pg_attribute a1 ON a1.attrelid = con.conrelid AND a1.attnum = con.conkey[1]
            JOIN pg_attribute a2 ON a2.attrelid = con.confrelid AND a2.attnum = con.confkey[1]
            WHERE con.conrelid = c.expense_oid
              AND con.confrelid = c.book_oid
              AND con.contype = 'f'
              AND array_length(con.conkey, 1) = 1
              AND array_length(con.confkey, 1) = 1
              AND a1.attname = 'book_id'
              AND a2.attname = 'id'
            ORDER BY (con.conname = 'fk_expenses_book') DESC, (con.confdeltype = 'c') DESC, con.conname ASC
            FETCH FIRST 1 ROWS ONLY
        ) AS exact_target_fk_primary,
        -- Formatted summary of all exact target FKs
        (
            SELECT string_agg(
                quote_ident(con.conname) || ' (ON DELETE ' ||
                CASE con.confdeltype
                    WHEN 'c' THEN 'CASCADE'
                    WHEN 'a' THEN 'NO ACTION'
                    WHEN 'r' THEN 'RESTRICT'
                    WHEN 'n' THEN 'SET NULL'
                    WHEN 'd' THEN 'SET DEFAULT'
                    ELSE con.confdeltype::text
                END || ')',
                ', ' ORDER BY con.conname
            )
            FROM pg_constraint con
            JOIN pg_attribute a1 ON a1.attrelid = con.conrelid AND a1.attnum = con.conkey[1]
            JOIN pg_attribute a2 ON a2.attrelid = con.confrelid AND a2.attnum = con.confkey[1]
            WHERE con.conrelid = c.expense_oid
              AND con.confrelid = c.book_oid
              AND con.contype = 'f'
              AND array_length(con.conkey, 1) = 1
              AND array_length(con.confkey, 1) = 1
              AND a1.attname = 'book_id'
              AND a2.attname = 'id'
        ) AS exact_target_fk_details,
        -- Check if any exact target FK has non-cascade delete rule
        (
            SELECT bool_or(con.confdeltype <> 'c')
            FROM pg_constraint con
            JOIN pg_attribute a1 ON a1.attrelid = con.conrelid AND a1.attnum = con.conkey[1]
            JOIN pg_attribute a2 ON a2.attrelid = con.confrelid AND a2.attnum = con.confkey[1]
            WHERE con.conrelid = c.expense_oid
              AND con.confrelid = c.book_oid
              AND con.contype = 'f'
              AND array_length(con.conkey, 1) = 1
              AND array_length(con.confkey, 1) = 1
              AND a1.attname = 'book_id'
              AND a2.attname = 'id'
        ) AS exact_target_has_non_cascade,
        -- Count of other FKs (composite or referencing another table) on book_id
        (
            SELECT count(DISTINCT con.oid)
            FROM pg_constraint con
            CROSS JOIN LATERAL generate_subscripts(con.conkey, 1) s(i)
            JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = con.conkey[s.i]
            WHERE con.conrelid = c.expense_oid
              AND con.contype = 'f'
              AND a.attname = 'book_id'
              AND (
                  c.book_oid IS NULL
                  OR con.confrelid <> c.book_oid
                  OR array_length(con.conkey, 1) > 1
              )
        ) AS other_fk_count,
        -- Summary of all other FKs on book_id
        (
            SELECT string_agg(
                quote_ident(con.conname) || ' (ref: ' || quote_ident(COALESCE(t_ref.relname, 'unknown')) || ', ' || array_length(con.conkey, 1)::text || ' cols)',
                ', ' ORDER BY con.conname
            )
            FROM (
                SELECT DISTINCT con.oid, con.conname, con.confrelid, con.conkey
                FROM pg_constraint con
                CROSS JOIN LATERAL generate_subscripts(con.conkey, 1) s(i)
                JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = con.conkey[s.i]
                WHERE con.conrelid = c.expense_oid
                  AND con.contype = 'f'
                  AND a.attname = 'book_id'
                  AND (
                      c.book_oid IS NULL
                      OR con.confrelid <> c.book_oid
                      OR array_length(con.conkey, 1) > 1
                  )
            ) con
            LEFT JOIN pg_class t_ref ON t_ref.oid = con.confrelid
        ) AS other_fk_summary,
        -- Deterministic primary other FK for backwards-compatible single-FK reporting
        (
            SELECT con.conname || '|' || COALESCE(t_ref.relname, 'unknown') || '|' || array_length(con.conkey, 1)::text
            FROM pg_constraint con
            LEFT JOIN pg_class t_ref ON t_ref.oid = con.confrelid
            CROSS JOIN LATERAL generate_subscripts(con.conkey, 1) s(i)
            JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = con.conkey[s.i]
            WHERE con.conrelid = c.expense_oid
              AND con.contype = 'f'
              AND a.attname = 'book_id'
              AND (
                  c.book_oid IS NULL
                  OR con.confrelid <> c.book_oid
                  OR array_length(con.conkey, 1) > 1
              )
            ORDER BY con.conname ASC
            FETCH FIRST 1 ROWS ONLY
        ) AS other_fk_primary
    FROM cols c
),
orphan_eval AS (
    SELECT
        c.*,
        CASE
            WHEN c.book_match_count = 1 AND c.expense_match_count = 1 
                 AND c.book_id_exists AND c.expense_book_id_exists AND c.expense_id_exists
                 AND c.types_are_fk_compatible
            THEN (xpath('/table/row/count/text()', query_to_xml(
                format('SELECT count(*) AS count FROM %I.%I e WHERE e.book_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM %I.%I b WHERE b.id = e.book_id)',
                       CURRENT_SCHEMA, c.expense_table, CURRENT_SCHEMA, c.book_table),
                true, false, ''
            )))[1]::text::bigint
            ELSE NULL
        END AS orphan_count
    FROM cols c
)
SELECT
    item_num,
    check_item,
    result,
    requirement
FROM (
    -- 1. Expenses Table Presence
    SELECT
        1 AS item_num,
        'Expenses Table Resolution' AS check_item,
        CASE 
            WHEN c.expense_match_count = 1 THEN 'PASS (' || c.expense_status || ')'
            ELSE c.expense_status
        END AS result,
        'Expenses table must exist uniquely in current schema (no ambiguity)' AS requirement
    FROM cols c

    UNION ALL

    -- 2. Books Table Presence
    SELECT
        2 AS item_num,
        'Books Table Resolution' AS check_item,
        CASE 
            WHEN c.book_match_count = 1 THEN 'PASS (' || c.book_status || ')'
            ELSE c.book_status
        END AS result,
        'Books table must exist uniquely in current schema (no ambiguity)' AS requirement
    FROM cols c

    UNION ALL

    -- 3. Required Column: Expenses.id
    SELECT
        3 AS item_num,
        'Required Column: Expenses.id' AS check_item,
        CASE
            WHEN c.expense_match_count <> 1 THEN 'SKIPPED: Expenses table unresolved'
            WHEN c.expense_id_exists THEN 'PASS (Column id exists on ' || quote_ident(c.expense_table) || ')'
            ELSE 'FAIL: Column id missing on ' || quote_ident(c.expense_table)
        END AS result,
        'Expenses table must have a primary key column id for transaction tracking' AS requirement
    FROM cols c

    UNION ALL

    -- 4. Required Column: Expenses.book_id
    SELECT
        4 AS item_num,
        'Required Column: Expenses.book_id' AS check_item,
        CASE
            WHEN c.expense_match_count <> 1 THEN 'SKIPPED: Expenses table unresolved'
            WHEN c.expense_book_id_exists THEN 'PASS (Column book_id exists on ' || quote_ident(c.expense_table) || ' [' || c.expense_book_id_type || '])'
            ELSE 'FAIL: Column book_id missing on ' || quote_ident(c.expense_table)
        END AS result,
        'Expenses table must have a book_id column referencing Books.id' AS requirement
    FROM cols c

    UNION ALL

    -- 5. Required Column: Books.id
    SELECT
        5 AS item_num,
        'Required Column: Books.id' AS check_item,
        CASE
            WHEN c.book_match_count <> 1 THEN 'SKIPPED: Books table unresolved'
            WHEN c.book_id_exists THEN 'PASS (Column id exists on ' || quote_ident(c.book_table) || ' [' || c.book_id_type || '])'
            ELSE 'FAIL: Column id missing on ' || quote_ident(c.book_table)
        END AS result,
        'Books table must have an id column' AS requirement
    FROM cols c

    UNION ALL

    -- 6. Column Type Compatibility
    SELECT
        6 AS item_num,
        'Column Type Compatibility' AS check_item,
        CASE
            WHEN c.expense_match_count <> 1 OR c.book_match_count <> 1 OR NOT c.expense_book_id_exists OR NOT c.book_id_exists
                THEN 'SKIPPED: Required tables or columns unresolved'
            WHEN c.types_are_fk_compatible
                THEN 'PASS: Compatible types for FK (' || quote_ident(c.expense_table) || '.book_id [' || c.expense_book_id_type || '] -> ' || quote_ident(c.book_table) || '.id [' || c.book_id_type || '])'
            ELSE 'FAIL: Incompatible types for FK (' || quote_ident(c.expense_table) || '.book_id [' || c.expense_book_id_type || '] vs ' || quote_ident(c.book_table) || '.id [' || c.book_id_type || '])'
        END AS result,
        'Expenses.book_id and Books.id must have compatible data types for a foreign key' AS requirement
    FROM cols c

    UNION ALL

    -- 7. Books.id Uniqueness & Target Suitability
    SELECT
        7 AS item_num,
        'Books.id Uniqueness & FK Target Suitability' AS check_item,
        CASE
            WHEN c.book_match_count <> 1 OR NOT c.book_id_exists THEN 'SKIPPED: Books table or Books.id unresolved'
            WHEN c.book_id_uniqueness_status LIKE 'PRIMARY_KEY:%' THEN
                'PASS: Books.id is backed by PRIMARY KEY (' || split_part(c.book_id_uniqueness_status, ':', 2) || ')'
            WHEN c.book_id_uniqueness_status LIKE 'UNIQUE_CONSTRAINT:%' THEN
                'PASS: Books.id is backed by UNIQUE constraint (' || split_part(c.book_id_uniqueness_status, ':', 2) || ')'
            WHEN c.book_id_uniqueness_status LIKE 'UNIQUE_INDEX:%' THEN
                'PASS: Books.id is backed by valid UNIQUE index (' || split_part(c.book_id_uniqueness_status, ':', 2) || ')'
            WHEN c.book_id_uniqueness_status LIKE 'DEFERRABLE:%' THEN
                'FAIL: Unique/primary key constraint on Books.id (' || split_part(c.book_id_uniqueness_status, ':', 2) || ') is DEFERRABLE; PostgreSQL rejects deferrable constraints as foreign key targets'
            WHEN c.book_id_uniqueness_status LIKE 'NOT_IMMEDIATE:%' THEN
                'FAIL: Unique constraint/index on Books.id (' || split_part(c.book_id_uniqueness_status, ':', 2) || ') is NOT IMMEDIATE (indimmediate=false); PostgreSQL requires immediate enforcement for FK targets'
            WHEN c.book_id_uniqueness_status = 'PARTIAL' THEN
                'FAIL: Unique index on Books.id is PARTIAL; cannot serve as valid FK target'
            WHEN c.book_id_uniqueness_status = 'INVALID' THEN
                'FAIL: Unique constraint/index on Books.id is INVALID (indisvalid=false)'
            WHEN c.book_id_uniqueness_status = 'NOT_READY' THEN
                'FAIL: Unique constraint/index on Books.id is NOT READY (indisready=false)'
            WHEN c.book_id_uniqueness_status = 'NOT_LIVE' THEN
                'FAIL: Unique constraint/index on Books.id is NOT LIVE (indislive=false)'
            ELSE 'FAIL: Books.id has no single-column PRIMARY KEY or UNIQUE constraint/index (PostgreSQL requires unique target for FK)'
        END AS result,
        'Referenced column Books.id must be backed by a valid, non-partial, non-deferrable unique or primary key constraint' AS requirement
    FROM cols c

    UNION ALL

    -- 8. Safety check for existing constraint named fk_expenses_book
    SELECT
        8 AS item_num,
        'Constraint "fk_expenses_book" Safety' AS check_item,
        CASE
            WHEN c.expense_match_count <> 1 THEN 'SKIPPED: Expenses table unresolved'
            WHEN fka.fk_expenses_book_conflict_status IS NULL THEN 'PASS: No existing constraint named "fk_expenses_book" on ' || quote_ident(c.expense_table)
            WHEN fka.fk_expenses_book_conflict_status = 'TARGET_MATCH' THEN 'PASS: Existing "fk_expenses_book" already connects book_id -> Books(id)'
            WHEN fka.fk_expenses_book_conflict_status LIKE 'NON_FK:%' THEN 'FAIL: Constraint "fk_expenses_book" exists on ' || quote_ident(c.expense_table) || ' but is NOT a foreign key'
            WHEN fka.fk_expenses_book_conflict_status LIKE 'WRONG_TABLE:%' THEN 'FAIL: Constraint "fk_expenses_book" exists on ' || quote_ident(c.expense_table) || ' but references wrong table (' || split_part(fka.fk_expenses_book_conflict_status, ':', 2) || ')'
            WHEN fka.fk_expenses_book_conflict_status LIKE 'COMPOSITE:%' THEN 'FAIL: Constraint "fk_expenses_book" exists on ' || quote_ident(c.expense_table) || ' but is composite (' || split_part(fka.fk_expenses_book_conflict_status, ':', 2) || ' columns)'
            ELSE 'FAIL: Constraint "fk_expenses_book" exists with mismatched columns'
        END AS result,
        'Constraint fk_expenses_book must not exist as non-FK or reference wrong table/columns' AS requirement
    FROM cols c
    CROSS JOIN fk_analysis fka

    UNION ALL

    -- 9. Exact Target FK Status
    SELECT
        9 AS item_num,
        'Target FK (book_id -> Books.id) Status' AS check_item,
        CASE
            WHEN c.expense_match_count <> 1 OR c.book_match_count <> 1 THEN 'SKIPPED: Tables unresolved'
            WHEN COALESCE(fka.exact_target_fk_count, 0) = 1 THEN
                'EXACT FK FOUND: Constraint ' || quote_ident(split_part(fka.exact_target_fk_primary, '|', 1)) || ' with ON DELETE ' ||
                CASE split_part(fka.exact_target_fk_primary, '|', 2)
                    WHEN 'c' THEN 'CASCADE (Already upgraded; migration will be idempotent)'
                    WHEN 'a' THEN 'NO ACTION (Migration will upgrade to CASCADE)'
                    WHEN 'r' THEN 'RESTRICT (Migration will upgrade to CASCADE)'
                    WHEN 'n' THEN 'SET NULL (Migration will upgrade to CASCADE)'
                    WHEN 'd' THEN 'SET DEFAULT (Migration will upgrade to CASCADE)'
                    ELSE split_part(fka.exact_target_fk_primary, '|', 2)
                END
            WHEN COALESCE(fka.exact_target_fk_count, 0) > 1 THEN
                'EXACT FK FOUND: Multiple matching constraints (' || fka.exact_target_fk_count || ': ' || fka.exact_target_fk_details || ') ' ||
                CASE 
                    WHEN NOT fka.exact_target_has_non_cascade THEN 'with ON DELETE CASCADE (Already upgraded; migration will consolidate)'
                    ELSE '(Migration will consolidate to single fk_expenses_book with CASCADE)'
                END
            WHEN COALESCE(fka.other_fk_count, 0) = 1 THEN
                'WARNING: No single-column FK to Books.id, but other FK on book_id exists: ' ||
                quote_ident(split_part(fka.other_fk_primary, '|', 1)) ||
                ' (ref: ' || quote_ident(split_part(fka.other_fk_primary, '|', 2)) || ', ' ||
                split_part(fka.other_fk_primary, '|', 3) || ' cols). Migration will create fk_expenses_book and preserve this unrelated FK.'
            WHEN COALESCE(fka.other_fk_count, 0) > 1 THEN
                'WARNING: No single-column FK to Books.id, but ' || fka.other_fk_count || ' other FKs on book_id exist: ' ||
                fka.other_fk_summary || '. Migration will create fk_expenses_book and preserve these unrelated FKs.'
            ELSE 'INFO: No existing FK on book_id (Migration will create fk_expenses_book with CASCADE)'
        END AS result,
        'Identifies exact target foreign key from Expenses.book_id to Books.id' AS requirement
    FROM cols c
    CROSS JOIN fk_analysis fka

    UNION ALL

    -- 10. Index on Expenses(book_id) & Suitability
    SELECT
        10 AS item_num,
        'Index on Expenses(book_id) & Suitability' AS check_item,
        CASE
            WHEN c.expense_match_count <> 1 THEN 'SKIPPED: Expenses table unresolved'
            WHEN ia.leading_index_info IS NOT NULL THEN
                CASE
                    WHEN split_part(ia.leading_index_info, '|', 4) = 'false'
                        THEN 'WARNING: Leading key index exists (' || quote_ident(split_part(ia.leading_index_info, '|', 1)) || ') but is NOT LIVE (indislive=false). Migration will create idx_expenses_book_id'
                    WHEN split_part(ia.leading_index_info, '|', 2) = 'false'
                        THEN 'WARNING: Leading key index exists (' || quote_ident(split_part(ia.leading_index_info, '|', 1)) || ') but is INVALID (indisvalid=false). Migration will create idx_expenses_book_id'
                    WHEN split_part(ia.leading_index_info, '|', 3) = 'false'
                        THEN 'WARNING: Leading key index exists (' || quote_ident(split_part(ia.leading_index_info, '|', 1)) || ') but is NOT READY (indisready=false). Migration will create idx_expenses_book_id'
                    WHEN split_part(ia.leading_index_info, '|', 6) <> 'btree'
                        THEN 'WARNING: Leading key index exists (' || quote_ident(split_part(ia.leading_index_info, '|', 1)) || ') but is NON-B-TREE access method (' || split_part(ia.leading_index_info, '|', 6) || '; B-tree required for FK lookups). Migration will create idx_expenses_book_id'
                    WHEN split_part(ia.leading_index_info, '|', 5) = 'true'
                        THEN 'WARNING: Leading key index exists (' || quote_ident(split_part(ia.leading_index_info, '|', 1)) || ') but is PARTIAL (WHERE clause); NOT universally sufficient for FK delete lookups. Migration will create full index idx_expenses_book_id'
                    ELSE 'PASS: Suitable full leading key index exists (' || quote_ident(split_part(ia.leading_index_info, '|', 1)) || ')'
                END
            WHEN ia.nonleading_index_info IS NOT NULL THEN
                'INFO: Non-leading key index exists (' || quote_ident(split_part(ia.nonleading_index_info, '|', 1)) || '); migration will add optimal leading key index idx_expenses_book_id'
            WHEN ia.included_index_name IS NOT NULL THEN
                'WARNING: book_id is ONLY an INCLUDE column in (' || quote_ident(ia.included_index_name) || '); DOES NOT support cascade delete lookups. Migration will create idx_expenses_book_id'
            ELSE 'INFO: No index on book_id found; migration will create idx_expenses_book_id'
        END AS result,
        'Distinguishes valid full leading keys, partial indexes, non-leading keys, and INCLUDE-only columns' AS requirement
    FROM cols c
    CROSS JOIN index_analysis ia

    UNION ALL

    -- 11. idx_expenses_book_id Schema Availability & Collision Check
    SELECT
        11 AS item_num,
        'Index Name "idx_expenses_book_id" Schema Check' AS check_item,
        CASE
            WHEN c.expense_match_count <> 1 THEN 'SKIPPED: Expenses table unresolved'
            WHEN nia.named_idx_status = 'AVAILABLE' THEN
                'PASS: Index name "idx_expenses_book_id" is available in current schema'
            WHEN nia.named_idx_status = 'SUITABLE_ON_EXPENSES' THEN
                'INFO: Suitable B-tree index named "idx_expenses_book_id" already exists on Expenses (Migration IF NOT EXISTS will safely skip creation)'
            WHEN nia.named_idx_status = 'COLLISION_NON_INDEX' THEN
                'FAIL: Collision conflict - Relation "idx_expenses_book_id" already exists as non-index relation (relkind=' || nia.relkind_text || ') in current schema! CREATE INDEX will fail!'
            WHEN nia.named_idx_status = 'COLLISION_OTHER_TABLE' THEN
                'FAIL: Collision conflict - ' ||
                CASE WHEN nia.relkind_text = 'I' THEN 'Partitioned index' ELSE 'Relation' END ||
                ' "idx_expenses_book_id" already exists on ANOTHER ' ||
                CASE WHEN nia.relkind_text = 'I' THEN 'table' ELSE 'relation' END ||
                ' (' || quote_ident(nia.indexed_table_name) || ')! Migration CREATE INDEX IF NOT EXISTS will skip creating the index on Expenses!'
            ELSE
                'FAIL: Existing index "idx_expenses_book_id" on Expenses is UNSUITABLE (' || nia.named_idx_detail || ')! Migration IF NOT EXISTS will skip creation, leaving Expenses without a suitable index!'
        END AS result,
        'Verifies index name idx_expenses_book_id is available or already suitable on Expenses, and does not collide across the schema' AS requirement
    FROM cols c
    CROSS JOIN named_index_analysis nia

    UNION ALL

    -- 12. Orphaned Expenses Check
    SELECT
        12 AS item_num,
        'Orphaned Expenses Check' AS check_item,
        CASE
            WHEN oe.orphan_count IS NULL THEN 'SKIPPED: Missing or ambiguous tables/columns, or incompatible types'
            WHEN oe.orphan_count = 0 THEN 'PASS: 0 orphaned expenses detected (Referential integrity clean)'
            ELSE 'FAIL: ' || oe.orphan_count || ' orphaned expenses detected! Clean up before adding FK.'
        END AS result,
        'Expenses.book_id must reference existing Books.id rows before applying FK constraint' AS requirement
    FROM orphan_eval oe

    UNION ALL

    -- 13. Overall Readiness
    SELECT
        13 AS item_num,
        'Overall Migration Readiness' AS check_item,
        CASE
            WHEN c.expense_match_count = 1 AND c.book_match_count = 1
                 AND c.expense_id_exists AND c.expense_book_id_exists AND c.book_id_exists
                 AND c.types_are_fk_compatible
                 AND (c.book_id_uniqueness_status LIKE 'PRIMARY_KEY:%' OR c.book_id_uniqueness_status LIKE 'UNIQUE_CONSTRAINT:%' OR c.book_id_uniqueness_status LIKE 'UNIQUE_INDEX:%')
                 AND (fka.fk_expenses_book_conflict_status IS NULL OR fka.fk_expenses_book_conflict_status = 'TARGET_MATCH')
                 AND (nia.named_idx_status IN ('AVAILABLE', 'SUITABLE_ON_EXPENSES'))
                 AND oe.orphan_count = 0
            THEN 'READY: All pre-flight safety checks passed. Safe to apply V20261117_1__cascade_delete_book_expenses.sql.'
            ELSE 'NOT READY: One or more pre-flight checks failed or were skipped. Review checklist above.'
        END AS result,
        'Consolidated pre-deployment verification for production database safety' AS requirement
    FROM cols c
    CROSS JOIN fk_analysis fka
    CROSS JOIN named_index_analysis nia
    CROSS JOIN orphan_eval oe
) checks
ORDER BY item_num;
