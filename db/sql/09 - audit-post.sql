CREATE TABLE audit.pessoas (LIKE folha.pessoas INCLUDING ALL);
CREATE TABLE audit.vinculos (LIKE folha.vinculos INCLUDING ALL);



CREATE TRIGGER tag_changes
    BEFORE INSERT OR UPDATE OR DELETE ON <XXXXXXXX>
    FOR EACH ROW EXECUTE PROCEDURE audit.tag_changes();


CREATE TRIGGER deactivate
    AFTER UPDATE OF active ON <XXXXXXXX>
    FOR EACH ROW EXECUTE PROCEDURE audit.deactivate();



-- create trigger and revoke delete for tables inherited from auditable


SELECT child.relname AS child_table
FROM pg_class parent
JOIN pg_inherits ON pg_inherits.inhparent = parent.oid
JOIN pg_class child ON pg_inherits.inhrelid = child.oid
JOIN pg_namespace ns ON parent.relnamespace = ns.oid
WHERE parent.relname = 'tracked'
AND  ns.nspname = 'folha';






CREATE ROLE trigger_delete_role;
REVOKE DELETE ON your_table FROM PUBLIC;
REVOKE DELETE ON your_table FROM inkas;
-- Repeat for any other roles as necessary

GRANT DELETE ON your_table TO trigger_delete_role;
ALTER FUNCTION delete_trigger_function() OWNER TO user_with_trigger_delete_role;

-- Set permissions for the function
REVOKE ALL ON FUNCTION delete_trigger_function() FROM public;
GRANT EXECUTE ON FUNCTION delete_trigger_function() TO trigger_delete_role;
