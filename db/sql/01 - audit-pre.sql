CREATE SCHEMA audit;

CREATE ROLE folha_audit_role;

----------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS audit.auditable CASCADE;
CREATE TABLE audit.auditable (    
    user_id     INTEGER NOT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by INTEGER NOT NULL,
 
    revoked_at TIMESTAMP,
    revoked_by INTEGER,

    active     BOOLEAN NULL DEFAULT TRUE    
);

ALTER TABLE audit.auditable OWNER TO folha_audit_role;
REVOKE ALL ON audit.auditable FROM PUBLIC;

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
$$ LANGUAGE plpgsql;

ALTER FUNCTION audit.buildWhere(TEXT, TEXT, RECORD) OWNER TO folha_audit_role;
REVOKE ALL ON FUNCTION audit.buildWhere(TEXT, TEXT, RECORD) FROM PUBLIC;

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

$$
LANGUAGE plpgsql;

ALTER FUNCTION audit.track_changes() OWNER TO folha_audit_role;
REVOKE ALL ON FUNCTION audit.track_changes() FROM PUBLIC;

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

ALTER FUNCTION audit.deactivate() OWNER TO folha_audit_role;
REVOKE ALL ON FUNCTION audit.deactivate() FROM PUBLIC;

----------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE audit.audit_table(schema_name name, table_name name) AS $$
DECLARE
    source_table    TEXT := quote_ident('audit') || quote_ident(schema_name) || '_' || quote_ident(table_name);
    target_table    TEXT := quote_ident(schema_name) || '.' || quote_ident(table_name);
BEGIN
    -- Create a Mirror table on audit schema
    EXECUTE 'CREATE TABLE ' || source_table || ' (LIKE ' || target_table || ' INCLUDING ALL)';
    
    -- Handle permissions
    EXECUTE 'REVOKE DELETE ON ' || source_table || ' FROM public';
    EXECUTE 'GRANT DELETE ON ' || source_table || ' TO folha_audit_role';

    -- Install triggers    
    EXECUTE 'CREATE TRIGGER track_changes_' || schema_name || '_' || table_name ||
            ' BEFORE INSERT OR UPDATE OR DELETE ON ' || target_table ||
            ' FOR EACH ROW EXECUTE PROCEDURE audit.track_changes()';

    EXECUTE 'CREATE TRIGGER deactivate_' || schema_name || '_' || table_name ||
            ' AFTER UPDATE OF active ON ' || target_table ||
            ' FOR EACH ROW EXECUTE PROCEDURE audit.deactivate()';
END;
$$ LANGUAGE plpgsql;

ALTER PROCEDURE audit.audit_table(name, name) OWNER TO folha_audit_role;
REVOKE ALL ON PROCEDURE audit.audit_table(name, name) FROM PUBLIC;
