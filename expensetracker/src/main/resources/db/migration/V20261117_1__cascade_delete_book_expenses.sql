-- Migration: Add ON DELETE CASCADE to Expenses.book_id and supporting index
-- Safe and idempotent for PostgreSQL: dynamically discovers exact table casing,
-- schema-qualifies statements, pairs columns by ordinal position, preserves unrelated foreign keys,
-- safely aborts if an unrelated constraint on Expenses is named fk_expenses_book, and avoids dropping already-valid cascade constraints.

DO $$
DECLARE
    v_schema text := CURRENT_SCHEMA;
    v_expense_table text;
    v_book_table text;
    v_other_ctype text;
    v_valid_cascade_exists boolean := false;
    r RECORD;
BEGIN
    -- 1. Dynamically resolve actual table names (case-insensitive search within v_schema)
    SELECT table_name INTO v_expense_table
    FROM information_schema.tables
    WHERE table_schema = v_schema
      AND lower(table_name) = 'expenses'
    LIMIT 1;

    SELECT table_name INTO v_book_table
    FROM information_schema.tables
    WHERE table_schema = v_schema
      AND lower(table_name) = 'books'
    LIMIT 1;

    IF v_expense_table IS NULL THEN
        RAISE EXCEPTION 'Migration aborted: Table "expenses" not found in schema "%".', v_schema;
    END IF;

    IF v_book_table IS NULL THEN
        RAISE EXCEPTION 'Migration aborted: Table "books" not found in schema "%".', v_schema;
    END IF;

    -- 2. Verify required columns exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = v_schema AND table_name = v_expense_table AND column_name = 'book_id'
    ) THEN
        RAISE EXCEPTION 'Migration aborted: Column "book_id" not found on table "%.%".', v_schema, v_expense_table;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = v_schema AND table_name = v_book_table AND column_name = 'id'
    ) THEN
        RAISE EXCEPTION 'Migration aborted: Column "id" not found on table "%.%".', v_schema, v_book_table;
    END IF;

    -- 3. Safety Check: If a constraint named 'fk_expenses_book' already exists on the resolved
    -- Expenses table, verify that it is a FOREIGN KEY.
    SELECT constraint_type
    INTO v_other_ctype
    FROM information_schema.table_constraints
    WHERE table_schema = v_schema
      AND table_name = v_expense_table
      AND constraint_name = 'fk_expenses_book'
      AND constraint_type <> 'FOREIGN KEY'
    LIMIT 1;

    IF v_other_ctype IS NOT NULL THEN
        RAISE EXCEPTION 'Migration aborted: Constraint "fk_expenses_book" already exists on "%.%" as a % constraint (not a FOREIGN KEY).',
            v_schema, v_expense_table, v_other_ctype;
    END IF;

    -- 4. Check if 'fk_expenses_book' exists as a foreign key on v_expense_table.
    -- If it does, ensure it specifically connects single-column book_id to v_book_table(id).
    -- If it references a different table, column, or is composite, abort immediately.
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_schema = v_schema
          AND table_name = v_expense_table
          AND constraint_name = 'fk_expenses_book'
          AND constraint_type = 'FOREIGN KEY'
    ) THEN
        IF NOT EXISTS (
            WITH fk_cols AS (
                SELECT
                    kcu1.constraint_name,
                    kcu1.column_name AS child_col,
                    kcu1.ordinal_position AS child_pos,
                    kcu2.table_name AS ref_table,
                    kcu2.column_name AS ref_col,
                    kcu1.position_in_unique_constraint AS ref_pos,
                    COUNT(*) OVER (PARTITION BY pgc.oid) AS total_cols
                FROM information_schema.key_column_usage kcu1
                JOIN pg_constraint pgc
                    ON pgc.conname = kcu1.constraint_name
                    AND pgc.conrelid = format('%I.%I', v_schema, v_expense_table)::regclass::oid
                    AND pgc.contype = 'f'
                JOIN pg_constraint pgc_ref
                    ON pgc_ref.conrelid = pgc.confrelid
                    AND pgc_ref.contype IN ('p', 'u')
                JOIN pg_class ref_cls
                    ON ref_cls.oid = pgc_ref.conrelid
                JOIN information_schema.key_column_usage kcu2
                    ON kcu2.constraint_name = pgc_ref.conname
                    AND kcu2.table_schema = v_schema
                    AND kcu2.table_name = ref_cls.relname
                    AND kcu1.position_in_unique_constraint = kcu2.ordinal_position
                WHERE kcu1.table_schema = v_schema
                  AND kcu1.table_name = v_expense_table
                  AND kcu1.constraint_name = 'fk_expenses_book'
            )
            SELECT 1 FROM fk_cols
            WHERE total_cols = 1
              AND child_col = 'book_id'
              AND child_pos = 1
              AND ref_table = v_book_table
              AND ref_col = 'id'
              AND ref_pos = 1
        ) THEN
            RAISE EXCEPTION 'Migration aborted: Constraint "fk_expenses_book" already exists on "%.%" but references a different table, column, or is composite.',
                v_schema, v_expense_table;
        END IF;
    END IF;

    -- 5. Discover all foreign keys on v_expense_table verified to connect single-column
    -- book_id to v_book_table(id) paired by ordinal position.
    SELECT EXISTS (
        WITH fk_cols AS (
            SELECT
                kcu1.constraint_name,
                CASE pgc.confdeltype
                    WHEN 'c' THEN 'CASCADE'
                    WHEN 'n' THEN 'SET NULL'
                    WHEN 'd' THEN 'SET DEFAULT'
                    WHEN 'r' THEN 'RESTRICT'
                    WHEN 'a' THEN 'NO ACTION'
                    ELSE 'OTHER'
                END AS delete_rule,
                kcu1.column_name AS child_col,
                kcu1.ordinal_position AS child_pos,
                kcu2.table_name AS ref_table,
                kcu2.column_name AS ref_col,
                kcu1.position_in_unique_constraint AS ref_pos,
                COUNT(*) OVER (PARTITION BY pgc.oid) AS total_cols
            FROM information_schema.key_column_usage kcu1
            JOIN pg_constraint pgc
                ON pgc.conname = kcu1.constraint_name
                AND pgc.conrelid = format('%I.%I', v_schema, v_expense_table)::regclass::oid
                AND pgc.contype = 'f'
            JOIN pg_constraint pgc_ref
                ON pgc_ref.conrelid = pgc.confrelid
                AND pgc_ref.contype IN ('p', 'u')
            JOIN pg_class ref_cls
                ON ref_cls.oid = pgc_ref.conrelid
            JOIN information_schema.key_column_usage kcu2
                ON kcu2.constraint_name = pgc_ref.conname
                AND kcu2.table_schema = v_schema
                AND kcu2.table_name = ref_cls.relname
                AND kcu1.position_in_unique_constraint = kcu2.ordinal_position
            WHERE kcu1.table_schema = v_schema
              AND kcu1.table_name = v_expense_table
              AND kcu1.constraint_name = 'fk_expenses_book'
        )
        SELECT 1 FROM fk_cols
        WHERE total_cols = 1
          AND child_col = 'book_id'
          AND child_pos = 1
          AND ref_table = v_book_table
          AND ref_col = 'id'
          AND ref_pos = 1
          AND delete_rule = 'CASCADE'
    ) INTO v_valid_cascade_exists;

    IF v_valid_cascade_exists THEN
        -- fk_expenses_book is already present on v_expense_table and configured with ON DELETE CASCADE.
        -- Only drop any obsolete or duplicate foreign keys connecting book_id to books(id).
        FOR r IN (
            WITH fk_cols AS (
                SELECT
                    kcu1.constraint_name,
                    kcu1.column_name AS child_col,
                    kcu1.ordinal_position AS child_pos,
                    kcu2.table_name AS ref_table,
                    kcu2.column_name AS ref_col,
                    kcu1.position_in_unique_constraint AS ref_pos,
                    COUNT(*) OVER (PARTITION BY pgc.oid) AS total_cols
                FROM information_schema.key_column_usage kcu1
                JOIN pg_constraint pgc
                    ON pgc.conname = kcu1.constraint_name
                    AND pgc.conrelid = format('%I.%I', v_schema, v_expense_table)::regclass::oid
                    AND pgc.contype = 'f'
                JOIN pg_constraint pgc_ref
                    ON pgc_ref.conrelid = pgc.confrelid
                    AND pgc_ref.contype IN ('p', 'u')
                JOIN pg_class ref_cls
                    ON ref_cls.oid = pgc_ref.conrelid
                JOIN information_schema.key_column_usage kcu2
                    ON kcu2.constraint_name = pgc_ref.conname
                    AND kcu2.table_schema = v_schema
                    AND kcu2.table_name = ref_cls.relname
                    AND kcu1.position_in_unique_constraint = kcu2.ordinal_position
                WHERE kcu1.table_schema = v_schema
                  AND kcu1.table_name = v_expense_table
            )
            SELECT DISTINCT constraint_name FROM fk_cols
            WHERE total_cols = 1
              AND child_col = 'book_id'
              AND child_pos = 1
              AND ref_table = v_book_table
              AND ref_col = 'id'
              AND ref_pos = 1
              AND constraint_name <> 'fk_expenses_book'
        ) LOOP
            EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT %I', v_schema, v_expense_table, r.constraint_name);
        END LOOP;
    ELSE
        -- Drop only verified target foreign keys connecting book_id to books(id).
        -- NOTE: Dropping only verified target foreign keys ensures unrelated foreign keys
        -- and non-target constraints are never touched.
        FOR r IN (
            WITH fk_cols AS (
                SELECT
                    kcu1.constraint_name,
                    kcu1.column_name AS child_col,
                    kcu1.ordinal_position AS child_pos,
                    kcu2.table_name AS ref_table,
                    kcu2.column_name AS ref_col,
                    kcu1.position_in_unique_constraint AS ref_pos,
                    COUNT(*) OVER (PARTITION BY pgc.oid) AS total_cols
                FROM information_schema.key_column_usage kcu1
                JOIN pg_constraint pgc
                    ON pgc.conname = kcu1.constraint_name
                    AND pgc.conrelid = format('%I.%I', v_schema, v_expense_table)::regclass::oid
                    AND pgc.contype = 'f'
                JOIN pg_constraint pgc_ref
                    ON pgc_ref.conrelid = pgc.confrelid
                    AND pgc_ref.contype IN ('p', 'u')
                JOIN pg_class ref_cls
                    ON ref_cls.oid = pgc_ref.conrelid
                JOIN information_schema.key_column_usage kcu2
                    ON kcu2.constraint_name = pgc_ref.conname
                    AND kcu2.table_schema = v_schema
                    AND kcu2.table_name = ref_cls.relname
                    AND kcu1.position_in_unique_constraint = kcu2.ordinal_position
                WHERE kcu1.table_schema = v_schema
                  AND kcu1.table_name = v_expense_table
            )
            SELECT DISTINCT constraint_name FROM fk_cols
            WHERE total_cols = 1
              AND child_col = 'book_id'
              AND child_pos = 1
              AND ref_table = v_book_table
              AND ref_col = 'id'
              AND ref_pos = 1
        ) LOOP
            EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT %I', v_schema, v_expense_table, r.constraint_name);
        END LOOP;

        EXECUTE format(
            'ALTER TABLE %I.%I ADD CONSTRAINT fk_expenses_book FOREIGN KEY (book_id) REFERENCES %I.%I (id) ON DELETE CASCADE',
            v_schema, v_expense_table, v_schema, v_book_table
        );
    END IF;

    -- 6. Create supporting B-tree index on expenses(book_id) if not exists
    EXECUTE format(
        'CREATE INDEX IF NOT EXISTS idx_expenses_book_id ON %I.%I (book_id)',
        v_schema, v_expense_table
    );
END $$;
