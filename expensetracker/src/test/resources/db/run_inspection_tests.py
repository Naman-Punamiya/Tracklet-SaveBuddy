import subprocess
import sys

psql = r'D:\Tools\PostgreSql\bin\psql.exe'
inspection_file = r'C:\Users\Naman\Desktop\Expense Tracker\expensetracker\src\test\resources\db\supabase_pre_migration_inspection.sql'

scenarios = [
    {
        'id': 1,
        'name': 'Normal lowercase books and expenses',
        'schema': 'sc1_lowercase',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id) ON DELETE NO ACTION, amount NUMERIC);
            INSERT INTO books (name) VALUES ('Test Book');
            INSERT INTO expenses (book_id, amount) VALUES (1, 100);
        ''',
        'expected': [
            ('OK: Uniquely resolved to books', True),
            ('OK: Uniquely resolved to expenses', True),
            ('READY: All pre-flight safety checks passed', True)
        ]
    },
    {
        'id': 2,
        'name': 'Quoted mixed-case "Books" and "Expenses"',
        'schema': 'sc2_mixedcase',
        'setup': '''
            CREATE TABLE "Books" (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE "Expenses" (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES "Books"(id) ON DELETE NO ACTION, amount NUMERIC);
            INSERT INTO "Books" (name) VALUES ('Mixed Book');
            INSERT INTO "Expenses" (book_id, amount) VALUES (1, 200);
        ''',
        'expected': [
            ('OK: Uniquely resolved to "Books"', True),
            ('OK: Uniquely resolved to "Expenses"', True),
            ('READY: All pre-flight safety checks passed', True)
        ]
    },
    {
        'id': 3,
        'name': 'Missing Books table',
        'schema': 'sc3_missing_books',
        'setup': '''
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, amount NUMERIC);
            INSERT INTO expenses (book_id, amount) VALUES (999, 50);
        ''',
        'expected': [
            ('FAIL: Table not found in current schema', True),
            ('SKIPPED: Books table unresolved', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 4,
        'name': 'Missing Expenses table',
        'schema': 'sc4_missing_expenses',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            INSERT INTO books (name) VALUES ('Lone Book');
        ''',
        'expected': [
            ('FAIL: Table not found in current schema', True),
            ('SKIPPED: Expenses table unresolved', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 5,
        'name': 'Both lowercase and mixed-case variants existing in one schema',
        'schema': 'sc5_ambiguous',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE "Books" (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT);
            CREATE TABLE "Expenses" (id BIGSERIAL PRIMARY KEY, book_id BIGINT);
        ''',
        'expected': [
            ('FAIL: Ambiguity detected', True),
            ('FAIL: Ambiguous table name', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 6,
        'name': 'Correct book_id -> Books.id FK with NO ACTION',
        'schema': 'sc6_fk_no_action',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (
                id BIGSERIAL PRIMARY KEY,
                book_id BIGINT,
                CONSTRAINT custom_no_action_fk FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE NO ACTION
            );
        ''',
        'expected': [
            ('EXACT TARGET FK (Expenses.book_id -> Books.id)', True),
            ('NO ACTION (Migration will upgrade to CASCADE)', True),
            ('READY: All pre-flight safety checks passed', True)
        ]
    },
    {
        'id': 7,
        'name': 'Correct FK with CASCADE',
        'schema': 'sc7_fk_cascade',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (
                id BIGSERIAL PRIMARY KEY,
                book_id BIGINT,
                CONSTRAINT fk_expenses_book FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
            );
        ''',
        'expected': [
            ('EXACT TARGET FK (Expenses.book_id -> Books.id)', True),
            ('CASCADE (Already upgraded; migration will be idempotent)', True),
            ('READY: All pre-flight safety checks passed', True)
        ]
    },
    {
        'id': 8,
        'name': 'book_id FK referencing the wrong table',
        'schema': 'sc8_fk_wrong_table',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE other_table (id BIGSERIAL PRIMARY KEY);
            CREATE TABLE expenses (
                id BIGSERIAL PRIMARY KEY,
                book_id BIGINT,
                CONSTRAINT fk_to_wrong_table FOREIGN KEY (book_id) REFERENCES other_table(id)
            );
        ''',
        'expected': [
            ('UNRELATED FK on book_id (references table other than Books: other_table)', True),
            ('WARNING: No single-column FK to Books.id, but other FK on book_id exists: fk_to_wrong_table', True)
        ]
    },
    {
        'id': 9,
        'name': 'Composite FK involving book_id',
        'schema': 'sc9_composite_fk',
        'setup': '''
            CREATE TABLE books (id BIGINT, tenant_id BIGINT, PRIMARY KEY (id, tenant_id));
            CREATE TABLE expenses (
                id BIGSERIAL PRIMARY KEY,
                book_id BIGINT,
                tenant_id BIGINT,
                CONSTRAINT fk_composite_book FOREIGN KEY (book_id, tenant_id) REFERENCES books(id, tenant_id)
            );
        ''',
        'expected': [
            ('COMPOSITE FK to Books (involves book_id)', True),
            ('WARNING: No single-column FK to Books.id, but other FK on book_id exists: fk_composite_book', True)
        ]
    },
    {
        'id': 10,
        'name': 'Index with book_id as leading key',
        'schema': 'sc10_leading_idx',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, tenant_id BIGINT);
            CREATE INDEX idx_book_tenant ON expenses (book_id, tenant_id);
        ''',
        'expected': [
            ('SUITABLE: Full leading index key (Optimal FK lookup / delete support)', True),
            ('PASS: Suitable full leading key index exists (idx_book_tenant)', True)
        ]
    },
    {
        'id': 11,
        'name': 'Index with book_id as non-leading key',
        'schema': 'sc11_nonleading_idx',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, tenant_id BIGINT);
            CREATE INDEX idx_tenant_book ON expenses (tenant_id, book_id);
        ''',
        'expected': [
            ('PARTIAL SUPPORT: Non-leading key column (requires leading columns)', True),
            ('INFO: Non-leading key index exists (idx_tenant_book)', True)
        ]
    },
    {
        'id': 12,
        'name': 'Index with book_id only as an INCLUDE column',
        'schema': 'sc12_include_idx',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, amount NUMERIC);
            CREATE INDEX idx_amount_covering ON expenses (amount) INCLUDE (book_id);
        ''',
        'expected': [
            ('UNSUITABLE: Included column only (NO FK lookup support; payload only)', True),
            ('WARNING: book_id is ONLY an INCLUDE column in (idx_amount_covering); DOES NOT support cascade delete lookups', True)
        ]
    },
    {
        'id': 13,
        'name': 'No index on book_id',
        'schema': 'sc13_no_idx',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, amount NUMERIC);
            CREATE INDEX idx_other ON expenses (amount);
        ''',
        'expected': [
            ('INFO: No index on book_id found; migration will create idx_expenses_book_id', True),
            ('DOES NOT EXIST anywhere in schema: Name is available', True)
        ]
    },
    {
        'id': 14,
        'name': 'Index name already used by another table',
        'schema': 'sc14_index_collision',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE categories (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id));
            CREATE INDEX idx_expenses_book_id ON categories (name);
        ''',
        'expected': [
            ('COLLISION CONFLICT: Index named "idx_expenses_book_id" exists on ANOTHER table: categories', True),
            ('FAIL: Collision conflict - Relation "idx_expenses_book_id" already exists on ANOTHER relation (categories)', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 15,
        'name': 'Invalid or unsuitable index on Expenses.book_id',
        'schema': 'sc15_invalid_index',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id));
            CREATE INDEX idx_corrupt ON expenses (book_id);
            UPDATE pg_index SET indisvalid = false WHERE indexrelid = 'idx_corrupt'::regclass;
        ''',
        'expected': [
            ('UNSUITABLE: Invalid index (indisvalid=false)', True),
            ('WARNING: Leading key index exists (idx_corrupt) but is INVALID (indisvalid=false)', True)
        ]
    },
    {
        'id': 16,
        'name': 'Partial index on book_id',
        'schema': 'sc16_partial_index',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);
            CREATE INDEX idx_partial ON expenses (book_id) WHERE amount > 0;
        ''',
        'expected': [
            ('PARTIAL: Has predicate (WHERE ...) - NOT universally sufficient for FK delete lookups', True),
            ('WARNING: Leading key index exists (idx_partial) but is PARTIAL (WHERE clause)', True)
        ]
    },
    {
        'id': 17,
        'name': 'Books.id without a unique constraint',
        'schema': 'sc17_books_no_pk',
        'setup': '''
            CREATE TABLE books (id BIGINT, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, amount NUMERIC);
        ''',
        'expected': [
            ('FAIL: Books.id has no single-column PRIMARY KEY or UNIQUE constraint/index', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 18,
        'name': 'Missing Expenses.id column',
        'schema': 'sc18_missing_exp_id',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (book_id BIGINT REFERENCES books(id), amount NUMERIC);
        ''',
        'expected': [
            ('FAIL: Column id missing on expenses', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 19,
        'name': 'Incompatible book_id and Books.id types',
        'schema': 'sc19_incompatible_types',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id TEXT, amount NUMERIC);
        ''',
        'expected': [
            ('FAIL: Incompatible types for FK (expenses.book_id [text] vs books.id [bigint])', True),
            ('SKIPPED orphan check: Incompatible column types', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 20,
        'name': 'idx_expenses_book_id on Expenses indexes amount instead of book_id',
        'schema': 'sc20_named_idx_wrong_col',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);
            CREATE INDEX idx_expenses_book_id ON expenses (amount);
        ''',
        'expected': [
            ('BLOCKER: Index named "idx_expenses_book_id" exists on Expenses (expenses) but first key column is amount (not book_id)', True),
            ('FAIL: Existing index "idx_expenses_book_id" on Expenses is UNSUITABLE (Index on Expenses indexes amount instead of book_id)', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 21,
        'name': 'Exact named index on Expenses is partial',
        'schema': 'sc21_named_idx_partial',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);
            CREATE INDEX idx_expenses_book_id ON expenses (book_id) WHERE amount > 0;
        ''',
        'expected': [
            ('BLOCKER: Index named "idx_expenses_book_id" exists on Expenses (expenses) but is PARTIAL (has WHERE predicate)', True),
            ('FAIL: Existing index "idx_expenses_book_id" on Expenses is UNSUITABLE (Index on Expenses is partial (has WHERE predicate))', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 22,
        'name': 'Exact named index on Expenses is invalid',
        'schema': 'sc22_named_idx_invalid',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id));
            CREATE INDEX idx_expenses_book_id ON expenses (book_id);
            UPDATE pg_index SET indisvalid = false WHERE indexrelid = 'idx_expenses_book_id'::regclass;
        ''',
        'expected': [
            ('BLOCKER: Index named "idx_expenses_book_id" exists on Expenses (expenses) but is INVALID (indisvalid=false)', True),
            ('FAIL: Existing index "idx_expenses_book_id" on Expenses is UNSUITABLE (Index on Expenses is invalid (indisvalid=false))', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 23,
        'name': 'Exact named index on Expenses is not ready',
        'schema': 'sc23_named_idx_not_ready',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id));
            CREATE INDEX idx_expenses_book_id ON expenses (book_id);
            UPDATE pg_index SET indisready = false WHERE indexrelid = 'idx_expenses_book_id'::regclass;
        ''',
        'expected': [
            ('BLOCKER: Index named "idx_expenses_book_id" exists on Expenses (expenses) but is NOT READY (indisready=false)', True),
            ('FAIL: Existing index "idx_expenses_book_id" on Expenses is UNSUITABLE (Index on Expenses is not ready (indisready=false))', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 24,
        'name': 'Non-index relation named idx_expenses_book_id exists in schema',
        'schema': 'sc24_non_index_collision',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id));
            CREATE TABLE idx_expenses_book_id (id INT);
        ''',
        'expected': [
            ('COLLISION CONFLICT: Relation "idx_expenses_book_id" exists as non-index relation (relkind=r)', True),
            ('FAIL: Collision conflict - Relation "idx_expenses_book_id" already exists as non-index relation (relkind=r)', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 25,
        'name': 'Books.id has a deferrable unique constraint',
        'schema': 'sc25_deferrable_unique',
        'setup': '''
            CREATE TABLE books (id BIGINT, name VARCHAR(255), CONSTRAINT uq_books_id UNIQUE (id) DEFERRABLE);
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, amount NUMERIC);
        ''',
        'expected': [
            ('FAIL: Unique/primary key constraint on Books.id (uq_books_id) is DEFERRABLE; PostgreSQL rejects deferrable constraints as foreign key targets', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 26,
        'name': 'Candidate unique index for Books.id is not live',
        'schema': 'sc26_not_live_pk',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, amount NUMERIC);
            UPDATE pg_index SET indislive = false WHERE indrelid = 'books'::regclass;
        ''',
        'expected': [
            ('FAIL: Unique constraint/index on Books.id is NOT LIVE (indislive=false)', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 27,
        'name': 'Non-B-tree index (hash) has book_id as leading key',
        'schema': 'sc27_hash_idx',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);
            CREATE INDEX idx_hash_expense_book ON expenses USING hash (book_id);
        ''',
        'expected': [
            ('UNSUITABLE: Non-B-tree index access method (hash; B-tree required for FK lookup)', True),
            ('WARNING: Leading key index exists (idx_hash_expense_book) but is NON-B-TREE access method (hash; B-tree required for FK lookups)', True),
            ('READY: All pre-flight safety checks passed', True)
        ]
    },
    {
        'id': 28,
        'name': 'Non-B-tree index (hash) on Expenses named idx_expenses_book_id',
        'schema': 'sc28_named_hash_idx',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);
            CREATE INDEX idx_expenses_book_id ON expenses USING hash (book_id);
        ''',
        'expected': [
            ('BLOCKER: Index named "idx_expenses_book_id" exists on Expenses (expenses) but is NON-B-TREE access method (hash)', True),
            ('FAIL: Existing index "idx_expenses_book_id" on Expenses is UNSUITABLE (Index on Expenses is non-B-tree (hash))', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 29,
        'name': 'Suitable B-tree index named idx_expenses_book_id already exists on Expenses',
        'schema': 'sc29_named_suitable_idx',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);
            CREATE INDEX idx_expenses_book_id ON expenses (book_id);
        ''',
        'expected': [
            ('EXISTS on Expenses (expenses): SUITABLE (Valid, Ready, Live, Non-partial B-tree index on book_id)', True),
            ('Migration IF NOT EXISTS will safely skip creation (already suitably indexed on Expenses)', True),
            ('PASS: Suitable full leading key index exists (idx_expenses_book_id)', True),
            ('INFO: Suitable B-tree index named "idx_expenses_book_id" already exists on Expenses (Migration IF NOT EXISTS will safely skip creation)', True),
            ('READY: All pre-flight safety checks passed', True)
        ]
    },
    {
        'id': 30,
        'name': 'Books has a deferrable unique constraint AND a valid PRIMARY KEY on id',
        'schema': 'sc30_deferrable_and_pk',
        'setup': '''
            CREATE TABLE books (id BIGINT, name VARCHAR(255), PRIMARY KEY (id), CONSTRAINT uq_books_id_def UNIQUE (id) DEFERRABLE);
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);
        ''',
        'expected': [
            ('PASS: Books.id is backed by PRIMARY KEY (books_pkey)', True),
            ('READY: All pre-flight safety checks passed', True)
        ]
    },
    {
        'id': 31,
        'name': 'Non-immediate unique index on Books.id',
        'schema': 'sc31_non_immediate_unique',
        'setup': '''
            CREATE TABLE books (id BIGINT, name VARCHAR(255));
            CREATE UNIQUE INDEX idx_books_id_uq ON books (id);
            UPDATE pg_index SET indimmediate = false WHERE indexrelid = 'idx_books_id_uq'::regclass;
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT, amount NUMERIC);
        ''',
        'expected': [
            ('FAIL: Unique constraint/index on Books.id (idx_books_id_uq) is NOT IMMEDIATE (indimmediate=false); PostgreSQL requires immediate enforcement for FK targets', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 32,
        'name': 'Valid primary key alongside an unsuitable unique candidate',
        'schema': 'sc32_valid_pk_and_unsuitable_uq',
        'setup': '''
            CREATE TABLE books (id BIGINT PRIMARY KEY, name VARCHAR(255));
            CREATE UNIQUE INDEX idx_books_id_unsuitable ON books (id);
            UPDATE pg_index SET indimmediate = false WHERE indexrelid = 'idx_books_id_unsuitable'::regclass;
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);
        ''',
        'expected': [
            ('PASS: Books.id is backed by PRIMARY KEY (books_pkey)', True),
            ('READY: All pre-flight safety checks passed', True)
        ]
    },
    {
        'id': 33,
        'name': 'Multiple constraints sharing the target FK name, including a conflicting one',
        'schema': 'sc33_conflicting_shared_fk_name',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE expenses (id BIGINT, book_id BIGINT, amount NUMERIC) PARTITION BY RANGE (id);
            CREATE TABLE expenses_p1 PARTITION OF expenses FOR VALUES FROM (1) TO (1000);
            CREATE TABLE expenses_p2 PARTITION OF expenses FOR VALUES FROM (1001) TO (2000);
            ALTER TABLE expenses_p1 ADD CONSTRAINT fk_expenses_book CHECK (book_id > 0);
            ALTER TABLE expenses_p2 ADD CONSTRAINT fk_expenses_book FOREIGN KEY (book_id) REFERENCES books(id);
        ''',
        'expected': [
            ('FAIL: Constraint "fk_expenses_book" exists on expenses but is NOT a foreign key', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    },
    {
        'id': 34,
        'name': 'Partitioned-index name collision',
        'schema': 'sc34_partitioned_index_collision',
        'setup': '''
            CREATE TABLE books (id BIGSERIAL PRIMARY KEY, name VARCHAR(255));
            CREATE TABLE categories (id BIGINT, name VARCHAR(255)) PARTITION BY RANGE (id);
            CREATE TABLE categories_p1 PARTITION OF categories FOR VALUES FROM (1) TO (1000);
            CREATE INDEX idx_expenses_book_id ON categories (name);
            CREATE TABLE expenses (id BIGSERIAL PRIMARY KEY, book_id BIGINT REFERENCES books(id), amount NUMERIC);
        ''',
        'expected': [
            ('COLLISION CONFLICT: Partitioned index named "idx_expenses_book_id" exists on ANOTHER table: categories! CREATE INDEX IF NOT EXISTS will skip creating the index on Expenses!', True),
            ('FAIL: Collision conflict - Partitioned index "idx_expenses_book_id" already exists on ANOTHER table (categories)! Migration CREATE INDEX IF NOT EXISTS will skip creating the index on Expenses!', True),
            ('NOT READY: One or more pre-flight checks failed', True)
        ]
    }
]

with open(inspection_file, 'r', encoding='utf-8') as f:
    inspection_sql = f.read()

all_passed = True
for sc in scenarios:
    full_script = f'''
    BEGIN;
    DROP SCHEMA IF EXISTS {sc['schema']} CASCADE;
    CREATE SCHEMA {sc['schema']};
    SET search_path TO {sc['schema']};

    {sc['setup']}

    {inspection_sql}

    ROLLBACK;
    '''
    res = subprocess.run([psql, '-U', 'postgres', '-d', 'postgres'], input=full_script, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"FAIL: Scenario {sc['id']:02d} ({sc['name']}) returned non-zero code {res.returncode}")
        print('STDERR:', res.stderr[:500])
        all_passed = False
        continue

    output = res.stdout
    sc_ok = True
    for exp, should_find in sc['expected']:
        if should_find and exp not in output:
            print(f"FAIL: Scenario {sc['id']:02d} ({sc['name']}): Expected string not found: '{exp}'")
            sc_ok = False
        elif not should_find and exp in output:
            print(f"FAIL: Scenario {sc['id']:02d} ({sc['name']}): Unexpected string found: '{exp}'")
            sc_ok = False

    if sc_ok:
        print(f"PASS: Scenario {sc['id']:02d} - {sc['name']}")
    else:
        all_passed = False

if all_passed:
    print(f"\nALL {len(scenarios)} SCENARIOS PASSED WITH ZERO CRASHES AND ACCURATE DIAGNOSTICS!")
else:
    sys.exit(1)
