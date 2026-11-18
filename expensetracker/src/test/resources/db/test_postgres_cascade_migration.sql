-- ============================================================================
-- Automated PostgreSQL Test Suite for Book-Expense Cascade Migration
-- Tests:
-- 1. Unrelated FK deliberately named 'fk_expenses_book' on expenses -> aborts & preserves constraint
-- 2. Same-named constraint 'fk_expenses_book' on another table -> allowed to coexist, migration succeeds
-- 3. Lowercase unquoted tables + custom old FK + unrelated FKs -> drops old FK, creates CASCADE, preserves others
-- 4. Mixed-case quoted tables ("Expenses", "Books") + NO ACTION -> upgrades to CASCADE, idempotent
-- 5. Composite foreign key -> preserved, not dropped by single-column cascade migration
-- ============================================================================

\set ON_ERROR_STOP on

-- ============================================================================
-- TEST 1: Unrelated FK on expenses named 'fk_expenses_book'
-- ============================================================================
BEGIN;
CREATE SCHEMA test_unrelated_named_fk;
SET search_path TO test_unrelated_named_fk;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE categories (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (
    id BIGSERIAL PRIMARY KEY,
    book_id BIGINT,
    category_id BIGINT,
    CONSTRAINT fk_expenses_book FOREIGN KEY (category_id) REFERENCES categories(id)
);

SAVEPOINT sp_test1;
\set ON_ERROR_STOP off
\ir ../../../main/resources/db/migration/V20261117_1__cascade_delete_book_expenses.sql
\set ON_ERROR_STOP on
ROLLBACK TO SAVEPOINT sp_test1;

-- Verify constraint was preserved
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_schema = CURRENT_SCHEMA
          AND constraint_name = 'fk_expenses_book'
    ) THEN
        RAISE EXCEPTION 'TEST 1 FAILED: Constraint fk_expenses_book was erroneously dropped!';
    END IF;
    RAISE NOTICE 'TEST 1 VERIFIED: Unrelated fk_expenses_book constraint was preserved intact.';
END $$;

ROLLBACK;

-- ============================================================================
-- TEST 2: Same-named constraint 'fk_expenses_book' on another table allowed
-- ============================================================================
BEGIN;
CREATE SCHEMA test_unrelated_table_named_fk;
SET search_path TO test_unrelated_table_named_fk;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE categories (
    id BIGSERIAL PRIMARY KEY,
    book_id BIGINT,
    CONSTRAINT fk_expenses_book FOREIGN KEY (book_id) REFERENCES books(id)
);
CREATE TABLE expenses (
    id BIGSERIAL PRIMARY KEY,
    book_id BIGINT,
    CONSTRAINT custom_old_fk FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE NO ACTION
);

-- Run migration: must succeed and NOT treat categories.fk_expenses_book as conflict
\ir ../../../main/resources/db/migration/V20261117_1__cascade_delete_book_expenses.sql

-- Verify:
-- 1. expenses now has fk_expenses_book with ON DELETE CASCADE
-- 2. categories still has its constraint fk_expenses_book
DO $$
DECLARE
    v_exp_del_rule text;
    v_cat_del_rule text;
BEGIN
    SELECT confdeltype INTO v_exp_del_rule
    FROM pg_constraint
    WHERE conrelid = 'expenses'::regclass
      AND conname = 'fk_expenses_book';

    IF v_exp_del_rule <> 'c' THEN
        RAISE EXCEPTION 'TEST 2 FAILED: expenses.fk_expenses_book delete rule is not CASCADE (got: %)', v_exp_del_rule;
    END IF;

    SELECT confdeltype INTO v_cat_del_rule
    FROM pg_constraint
    WHERE conrelid = 'categories'::regclass
      AND conname = 'fk_expenses_book';

    IF v_cat_del_rule IS NULL THEN
        RAISE EXCEPTION 'TEST 2 FAILED: categories.fk_expenses_book was unexpectedly dropped!';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'expenses'::regclass
          AND conname = 'custom_old_fk'
    ) THEN
        RAISE EXCEPTION 'TEST 2 FAILED: custom_old_fk on expenses was not dropped!';
    END IF;

    RAISE NOTICE 'TEST 2 PASSED: Migration succeeded with same-named constraint on categories; both constraints coexist.';
END $$;

ROLLBACK;

-- ============================================================================
-- TEST 3: Lowercase tables, custom old FK, unrelated FKs, idempotency, cascade delete
-- ============================================================================
BEGIN;
CREATE SCHEMA test_lowercase_flow;
SET search_path TO test_lowercase_flow;

CREATE TABLE users (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE categories (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255), user_id BIGINT REFERENCES users(id));
CREATE TABLE expenses (
    id BIGSERIAL PRIMARY KEY,
    description VARCHAR(255),
    book_id BIGINT,
    category_id BIGINT REFERENCES categories(id),
    user_id BIGINT REFERENCES users(id),
    CONSTRAINT custom_old_fk_name FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE NO ACTION
);

INSERT INTO users (name) VALUES ('Alice');
INSERT INTO categories (name) VALUES ('Travel');
INSERT INTO books (name, user_id) VALUES ('Vacation Book', 1);
INSERT INTO expenses (description, book_id, category_id, user_id) VALUES ('Flight', 1, 1, 1), ('Hotel', 1, 1, 1);

-- Run migration Run 1
\ir ../../../main/resources/db/migration/V20261117_1__cascade_delete_book_expenses.sql

-- Verify Run 1
DO $$
DECLARE
    v_del_rule text;
BEGIN
    SELECT confdeltype INTO v_del_rule
    FROM pg_constraint
    WHERE conrelid = 'expenses'::regclass AND conname = 'fk_expenses_book';

    IF v_del_rule <> 'c' THEN
        RAISE EXCEPTION 'TEST 3 FAILED: fk_expenses_book is not CASCADE (rule: %)', v_del_rule;
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'expenses'::regclass AND conname = 'custom_old_fk_name'
    ) THEN
        RAISE EXCEPTION 'TEST 3 FAILED: custom_old_fk_name was not dropped!';
    END IF;

    -- Verify unrelated FKs preserved
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'expenses'::regclass AND conname = 'expenses_category_id_fkey') OR
       NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'expenses'::regclass AND conname = 'expenses_user_id_fkey') THEN
        RAISE EXCEPTION 'TEST 3 FAILED: Unrelated foreign keys were dropped!';
    END IF;

    RAISE NOTICE 'TEST 3 (RUN 1) PASSED: fk_expenses_book is CASCADE, old FK dropped, unrelated FKs preserved.';
END $$;

-- Run migration Run 2 (Idempotency)
\ir ../../../main/resources/db/migration/V20261117_1__cascade_delete_book_expenses.sql

-- Verify Cascade Deletion
DELETE FROM books WHERE id = 1;
DO $$
DECLARE
    v_exp_cnt int;
    v_usr_cnt int;
    v_cat_cnt int;
BEGIN
    SELECT COUNT(*) INTO v_exp_cnt FROM expenses;
    SELECT COUNT(*) INTO v_usr_cnt FROM users;
    SELECT COUNT(*) INTO v_cat_cnt FROM categories;

    IF v_exp_cnt <> 0 THEN
        RAISE EXCEPTION 'TEST 3 FAILED: Expenses were not cascade deleted! (count: %)', v_exp_cnt;
    END IF;
    IF v_usr_cnt <> 1 OR v_cat_cnt <> 1 THEN
        RAISE EXCEPTION 'TEST 3 FAILED: Users or Categories were unexpectedly deleted!';
    END IF;
    RAISE NOTICE 'TEST 3 (CASCADE DELETE) PASSED: Child expenses deleted, parent and unrelated intact.';
END $$;

ROLLBACK;

-- ============================================================================
-- TEST 4: Mixed-case quoted tables ("Expenses", "Books")
-- ============================================================================
BEGIN;
CREATE SCHEMA test_mixed_case_flow;
SET search_path TO test_mixed_case_flow;

CREATE TABLE "Users" (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE "Books" (id BIGSERIAL PRIMARY KEY, name VARCHAR(255), user_id BIGINT REFERENCES "Users"(id));
CREATE TABLE "Expenses" (
    id BIGSERIAL PRIMARY KEY,
    description VARCHAR(255),
    book_id BIGINT,
    user_id BIGINT REFERENCES "Users"(id),
    CONSTRAINT fk_expenses_book FOREIGN KEY (book_id) REFERENCES "Books"(id) ON DELETE NO ACTION
);

INSERT INTO "Users" (name) VALUES ('Bob');
INSERT INTO "Books" (name, user_id) VALUES ('Bob Ledger', 1);
INSERT INTO "Expenses" (description, book_id, user_id) VALUES ('Coffee', 1, 1), ('Lunch', 1, 1);

-- Run migration Run 1
\ir ../../../main/resources/db/migration/V20261117_1__cascade_delete_book_expenses.sql

-- Run migration Run 2 (Idempotency)
\ir ../../../main/resources/db/migration/V20261117_1__cascade_delete_book_expenses.sql

DELETE FROM "Books" WHERE id = 1;
DO $$
DECLARE
    v_exp_cnt int;
BEGIN
    SELECT COUNT(*) INTO v_exp_cnt FROM "Expenses";
    IF v_exp_cnt <> 0 THEN
        RAISE EXCEPTION 'TEST 4 FAILED: Expenses were not cascade deleted from mixed-case table!';
    END IF;
    RAISE NOTICE 'TEST 4 PASSED: Mixed-case tables upgraded, idempotent, and cascade-deleted successfully.';
END $$;

ROLLBACK;

-- ============================================================================
-- TEST 5: Composite Foreign Key preservation
-- ============================================================================
BEGIN;
CREATE SCHEMA test_composite_flow;
SET search_path TO test_composite_flow;

CREATE TABLE books (
    id BIGINT,
    tenant_id BIGINT,
    PRIMARY KEY (id, tenant_id),
    CONSTRAINT uq_books_id UNIQUE (id)
);

CREATE TABLE expenses (
    id BIGSERIAL PRIMARY KEY,
    book_id BIGINT,
    tenant_id BIGINT,
    CONSTRAINT fk_composite FOREIGN KEY (book_id, tenant_id) REFERENCES books(id, tenant_id),
    CONSTRAINT custom_old_fk FOREIGN KEY (book_id) REFERENCES books(id)
);

-- Run migration
\ir ../../../main/resources/db/migration/V20261117_1__cascade_delete_book_expenses.sql

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'expenses'::regclass AND conname = 'fk_composite'
    ) THEN
        RAISE EXCEPTION 'TEST 5 FAILED: Composite foreign key was erroneously dropped!';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'expenses'::regclass AND conname = 'fk_expenses_book' AND confdeltype = 'c'
    ) THEN
        RAISE EXCEPTION 'TEST 5 FAILED: Single target foreign key fk_expenses_book was not created with CASCADE!';
    END IF;

    RAISE NOTICE 'TEST 5 PASSED: Composite foreign key preserved; single target FK upgraded to CASCADE.';
END $$;

ROLLBACK;
