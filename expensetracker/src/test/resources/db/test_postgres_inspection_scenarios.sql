-- ============================================================================
-- Automated PostgreSQL Test Suite for Supabase Pre-Migration Inspection Script
-- Covers 34 Comprehensive Local Scenarios:
--  1. Normal lowercase books and expenses
--  2. Quoted mixed-case "Books" and "Expenses"
--  3. Missing Books table
--  4. Missing Expenses table
--  5. Both lowercase and mixed-case variants existing in one schema (Ambiguity)
--  6. Correct book_id -> Books.id FK with NO ACTION
--  7. Correct FK with CASCADE
--  8. book_id FK referencing the wrong table
--  9. Composite FK involving book_id
-- 10. Index with book_id as leading key
-- 11. Index with book_id as non-leading key
-- 12. Index with book_id only as an INCLUDE column
-- 13. No index on book_id
-- 14. Index name already used by another table
-- 15. Invalid or unsuitable index on Expenses.book_id
-- 16. Partial index on book_id
-- 17. Books.id without a unique constraint
-- 18. Missing Expenses.id column
-- 19. Incompatible book_id and Books.id types
-- 20. idx_expenses_book_id on Expenses indexes amount instead of book_id
-- 21. Exact named index on Expenses is partial
-- 22. Exact named index on Expenses is invalid
-- 23. Exact named index on Expenses is not ready
-- 24. Non-index relation named idx_expenses_book_id exists in schema
-- 25. Books.id has a deferrable unique constraint
-- 26. Candidate unique index for Books.id is not live (indislive=false)
-- 27. Non-B-tree index (hash) has book_id as leading key
-- 28. Non-B-tree index (hash) on Expenses named idx_expenses_book_id
-- 29. Suitable B-tree index named idx_expenses_book_id already exists on Expenses
-- 30. Books has a deferrable unique constraint AND a valid PRIMARY KEY on id
-- 31. Non-immediate unique index on Books.id
-- 32. Valid primary key alongside an unsuitable unique candidate
-- 33. Multiple constraints sharing the target FK name, including a conflicting one
-- 34. Partitioned-index name collision
-- ============================================================================

\set ON_ERROR_STOP on

-- ============================================================================
-- SCENARIO 1: Normal lowercase books and expenses
-- ============================================================================
BEGIN;
CREATE SCHEMA sc1_lowercase;
SET search_path TO sc1_lowercase;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id) ON DELETE NO ACTION, amount NUMERIC);
INSERT INTO books (name) VALUES ('Test Book');
INSERT INTO expenses (book_id, amount) VALUES (1, 100);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 2: Quoted mixed-case "Books" and "Expenses"
-- ============================================================================
BEGIN;
CREATE SCHEMA sc2_mixedcase;
SET search_path TO sc2_mixedcase;

CREATE TABLE "Books" (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE "Expenses" (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES "Books"(id) ON DELETE NO ACTION, amount NUMERIC);
INSERT INTO "Books" (name) VALUES ('Mixed Book');
INSERT INTO "Expenses" (book_id, amount) VALUES (1, 200);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 3: Missing Books table
-- ============================================================================
BEGIN;
CREATE SCHEMA sc3_missing_books;
SET search_path TO sc3_missing_books;

CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, amount NUMERIC);
INSERT INTO expenses (book_id, amount) VALUES (999, 50);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 4: Missing Expenses table
-- ============================================================================
BEGIN;
CREATE SCHEMA sc4_missing_expenses;
SET search_path TO sc4_missing_expenses;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
INSERT INTO books (name) VALUES ('Lone Book');

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 5: Both lowercase and mixed-case variants existing in one schema
-- ============================================================================
BEGIN;
CREATE SCHEMA sc5_ambiguous;
SET search_path TO sc5_ambiguous;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE "Books" (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT);
CREATE TABLE "Expenses" (id BIGSERIAL PRIMARY KEY, book_id BIGINT);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 6: Correct book_id -> Books.id FK with NO ACTION
-- ============================================================================
BEGIN;
CREATE SCHEMA sc6_fk_no_action;
SET search_path TO sc6_fk_no_action;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (
    id BIGSERIAL PRIMARY KEY,
    book_id BIGINT,
    CONSTRAINT custom_no_action_fk FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE NO ACTION
);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 7: Correct FK with CASCADE
-- ============================================================================
BEGIN;
CREATE SCHEMA sc7_fk_cascade;
SET search_path TO sc7_fk_cascade;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (
    id BIGSERIAL PRIMARY KEY,
    book_id BIGINT,
    CONSTRAINT fk_expenses_book FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 8: book_id FK referencing the wrong table
-- ============================================================================
BEGIN;
CREATE SCHEMA sc8_fk_wrong_table;
SET search_path TO sc8_fk_wrong_table;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE other_table (id BIGSERIAL PRIMARY KEY);
CREATE TABLE expenses (
    id BIGSERIAL PRIMARY KEY,
    book_id BIGINT,
    CONSTRAINT fk_to_wrong_table FOREIGN KEY (book_id) REFERENCES other_table(id)
);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 9: Composite FK involving book_id
-- ============================================================================
BEGIN;
CREATE SCHEMA sc9_composite_fk;
SET search_path TO sc9_composite_fk;

CREATE TABLE books (id BIGINT, tenant_id BIGINT, PRIMARY KEY (id, tenant_id));
CREATE TABLE expenses (
    id BIGSERIAL PRIMARY KEY,
    book_id BIGINT,
    tenant_id BIGINT,
    CONSTRAINT fk_composite_book FOREIGN KEY (book_id, tenant_id) REFERENCES books(id, tenant_id)
);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 10: Index with book_id as leading key
-- ============================================================================
BEGIN;
CREATE SCHEMA sc10_leading_idx;
SET search_path TO sc10_leading_idx;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, tenant_id BIGINT);
CREATE INDEX idx_book_tenant ON expenses (book_id, tenant_id);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 11: Index with book_id as non-leading key
-- ============================================================================
BEGIN;
CREATE SCHEMA sc11_nonleading_idx;
SET search_path TO sc11_nonleading_idx;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, tenant_id BIGINT);
CREATE INDEX idx_tenant_book ON expenses (tenant_id, book_id);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 12: Index with book_id only as an INCLUDE column
-- ============================================================================
BEGIN;
CREATE SCHEMA sc12_include_idx;
SET search_path TO sc12_include_idx;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, amount NUMERIC);
CREATE INDEX idx_amount_covering ON expenses (amount) INCLUDE (book_id);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 13: No index on book_id
-- ============================================================================
BEGIN;
CREATE SCHEMA sc13_no_idx;
SET search_path TO sc13_no_idx;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, amount NUMERIC);
CREATE INDEX idx_other ON expenses (amount);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 14: Index name already used by another table
-- ============================================================================
BEGIN;
CREATE SCHEMA sc14_index_collision;
SET search_path TO sc14_index_collision;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE categories (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id));
CREATE INDEX idx_expenses_book_id ON categories (name);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 15: Invalid or unsuitable index on Expenses.book_id
-- ============================================================================
BEGIN;
CREATE SCHEMA sc15_invalid_index;
SET search_path TO sc15_invalid_index;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id));
CREATE INDEX idx_corrupt ON expenses (book_id);
UPDATE pg_index SET indisvalid = false WHERE indexrelid = 'idx_corrupt'::regclass;

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 16: Partial index on book_id
-- ============================================================================
BEGIN;
CREATE SCHEMA sc16_partial_index;
SET search_path TO sc16_partial_index;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);
CREATE INDEX idx_partial ON expenses (book_id) WHERE amount > 0;

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 17: Books.id without a unique constraint
-- ============================================================================
BEGIN;
CREATE SCHEMA sc17_books_no_pk;
SET search_path TO sc17_books_no_pk;

CREATE TABLE books (id BIGINT, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, amount NUMERIC);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 18: Missing Expenses.id column
-- ============================================================================
BEGIN;
CREATE SCHEMA sc18_missing_exp_id;
SET search_path TO sc18_missing_exp_id;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (book_id BIGINT REFERENCES books(id), amount NUMERIC);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 19: Incompatible book_id and Books.id types
-- ============================================================================
BEGIN;
CREATE SCHEMA sc19_incompatible_types;
SET search_path TO sc19_incompatible_types;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id TEXT, amount NUMERIC);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 20: idx_expenses_book_id on Expenses indexes amount instead of book_id
-- ============================================================================
BEGIN;
CREATE SCHEMA sc20_named_idx_wrong_col;
SET search_path TO sc20_named_idx_wrong_col;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);
CREATE INDEX idx_expenses_book_id ON expenses (amount);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 21: Exact named index on Expenses is partial
-- ============================================================================
BEGIN;
CREATE SCHEMA sc21_named_idx_partial;
SET search_path TO sc21_named_idx_partial;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);
CREATE INDEX idx_expenses_book_id ON expenses (book_id) WHERE amount > 0;

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 22: Exact named index on Expenses is invalid
-- ============================================================================
BEGIN;
CREATE SCHEMA sc22_named_idx_invalid;
SET search_path TO sc22_named_idx_invalid;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id));
CREATE INDEX idx_expenses_book_id ON expenses (book_id);
UPDATE pg_index SET indisvalid = false WHERE indexrelid = 'idx_expenses_book_id'::regclass;

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 23: Exact named index on Expenses is not ready
-- ============================================================================
BEGIN;
CREATE SCHEMA sc23_named_idx_not_ready;
SET search_path TO sc23_named_idx_not_ready;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id));
CREATE INDEX idx_expenses_book_id ON expenses (book_id);
UPDATE pg_index SET indisready = false WHERE indexrelid = 'idx_expenses_book_id'::regclass;

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 24: Non-index relation named idx_expenses_book_id exists in schema
-- ============================================================================
BEGIN;
CREATE SCHEMA sc24_non_index_collision;
SET search_path TO sc24_non_index_collision;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id));
CREATE TABLE idx_expenses_book_id (id INT);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 25: Books.id has a deferrable unique constraint
-- ============================================================================
BEGIN;
CREATE SCHEMA sc25_deferrable_unique;
SET search_path TO sc25_deferrable_unique;

CREATE TABLE books (id BIGINT, name VARCHAR(255), CONSTRAINT uq_books_id UNIQUE (id) DEFERRABLE);
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, amount NUMERIC);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 26: Candidate unique index for Books.id is not live
-- ============================================================================
BEGIN;
CREATE SCHEMA sc26_not_live_pk;
SET search_path TO sc26_not_live_pk;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, amount NUMERIC);
UPDATE pg_index SET indislive = false WHERE indrelid = 'books'::regclass;

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 27: Non-B-tree index (hash) has book_id as leading key
-- ============================================================================
BEGIN;
CREATE SCHEMA sc27_hash_idx;
SET search_path TO sc27_hash_idx;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);
CREATE INDEX idx_hash_expense_book ON expenses USING hash (book_id);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 28: Non-B-tree index (hash) on Expenses named idx_expenses_book_id
-- ============================================================================
BEGIN;
CREATE SCHEMA sc28_named_hash_idx;
SET search_path TO sc28_named_hash_idx;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);
CREATE INDEX idx_expenses_book_id ON expenses USING hash (book_id);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 29: Suitable B-tree index named idx_expenses_book_id already exists on Expenses
-- ============================================================================
BEGIN;
CREATE SCHEMA sc29_named_suitable_idx;
SET search_path TO sc29_named_suitable_idx;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);
CREATE INDEX idx_expenses_book_id ON expenses (book_id);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 30: Books has a deferrable unique constraint AND a valid PRIMARY KEY on id
-- ============================================================================
BEGIN;
CREATE SCHEMA sc30_deferrable_and_pk;
SET search_path TO sc30_deferrable_and_pk;

CREATE TABLE books (id BIGINT, name VARCHAR(255), PRIMARY KEY (id), CONSTRAINT uq_books_id_def UNIQUE (id) DEFERRABLE);
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 31: Non-immediate unique index on Books.id
-- ============================================================================
BEGIN;
CREATE SCHEMA sc31_non_immediate_unique;
SET search_path TO sc31_non_immediate_unique;

CREATE TABLE books (id BIGINT, name VARCHAR(255));
CREATE UNIQUE INDEX idx_books_id_uq ON books (id);
UPDATE pg_index SET indimmediate = false WHERE indexrelid = 'idx_books_id_uq'::regclass;
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, amount NUMERIC);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 32: Valid primary key alongside an unsuitable unique candidate
-- ============================================================================
BEGIN;
CREATE SCHEMA sc32_valid_pk_and_unsuitable_uq;
SET search_path TO sc32_valid_pk_and_unsuitable_uq;

CREATE TABLE books (id BIGINT PRIMARY KEY, name VARCHAR(255));
CREATE UNIQUE INDEX idx_books_id_unsuitable ON books (id);
UPDATE pg_index SET indimmediate = false WHERE indexrelid = 'idx_books_id_unsuitable'::regclass;
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 33: Multiple constraints sharing the target FK name, including a conflicting one
-- ============================================================================
BEGIN;
CREATE SCHEMA sc33_conflicting_shared_fk_name;
SET search_path TO sc33_conflicting_shared_fk_name;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE expenses (id BIGINT, book_id BIGINT, amount NUMERIC) PARTITION BY RANGE (id);
CREATE TABLE expenses_p1 PARTITION OF expenses FOR VALUES FROM (1) TO (1000);
CREATE TABLE expenses_p2 PARTITION OF expenses FOR VALUES FROM (1001) TO (2000);
ALTER TABLE expenses_p1 ADD CONSTRAINT fk_expenses_book CHECK (book_id > 0);
ALTER TABLE expenses_p2 ADD CONSTRAINT fk_expenses_book FOREIGN KEY (book_id) REFERENCES books(id);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;

-- ============================================================================
-- SCENARIO 34: Partitioned-index name collision
-- ============================================================================
BEGIN;
CREATE SCHEMA sc34_partitioned_index_collision;
SET search_path TO sc34_partitioned_index_collision;

CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
CREATE TABLE categories (id BIGINT, name VARCHAR(255)) PARTITION BY RANGE (id);
CREATE TABLE categories_p1 PARTITION OF categories FOR VALUES FROM (1) TO (1000);
CREATE INDEX idx_expenses_book_id ON categories (name);
CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);

\ir supabase_pre_migration_inspection.sql
ROLLBACK;
