CREATE SCHEMA audit;


CREATE TABLE audit.auditable (    
    user_id     INTEGER NOT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by INTEGER NOT NULL,
 
    revoked_at TIMESTAMP,
    revoked_by INTEGER,

    active     BOOLEAN NULL DEFAULT TRUE    
);


----------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION audit.buildWhere(schema_name TEXT, table_name TEXT, _row RECORD)
RETURNS TEXT AS $$
DECLARE
    keys TEXT[];
    _row JSONB := ROW_TO_JSONB(_row)::JSONB;
BEGIN
    SELECT ARRAY_AGG(quote_ident(kcu.column_name) || '=' || quote_literal(_row.*))
    INTO keys
    FROM information_schema.key_column_usage kcu
    WHERE kcu.table_name = table_name
    AND kcu.table_schema = schema_name
    AND kcu.constraint_name IN (
        SELECT tc.constraint_name
        FROM information_schema.table_constraints tc
        WHERE tc.table_name = kcu.table_name
            AND tc.table_schema = kcu.table_schema
            AND tc.constraint_type = 'PRIMARY KEY'
    );

    RETURN ' WHERE ' || array_to_string(keys, ' AND ') || ';';
END;

----------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION audit.track_changes() RETURNS TRIGGER AS $$
DECLARE
  target TEXT := 'audit.' || TG_TABLE_NAME;
BEGIN
    IF ( TG_OP = 'INSERT' OR TG_OP = 'UPDATE' ) THEN
        NEW.created_by = NEW.user_id;
        NEW.created_at = NOW();

        EXECUTE 'INSERT INTO ' || target || ' SELECT ($1).*' USING NEW;
    END IF;
	
    IF ( TG_OP = 'DELETE' OR TG_OP = 'UPDATE' ) THEN
        query := 'UPDATE '  || target || ' SET revoked_at = NOW(), revoked_at = $1 '
                            || buildWhere(TG_SCHEMA_NAME, TG_TABLE_NAME, OLD);

        -- Update Revoked At/By columns
        EXECUTE query USING NEW.user_id;
        RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
    END IF;
    RETURN NEW;
END;

----------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------
-- DELETE by setting status to -1
CREATE OR REPLACE FUNCTION audit.deactivate() RETURNS TRIGGER AS $$
DECLARE
    target TEXT := 'audit.' || TG_TABLE_NAME;
BEGIN
    IF NEW.active IS NULL THEN
        EXECUTE 'DELETE FROM ' || target || buildWhere(TG_SCHEMA_NAME, TG_TABLE_NAME, OLD);
    END IF;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

