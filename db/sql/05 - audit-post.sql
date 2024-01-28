-------------------------------------------------------------------------------
-- Apply Auditing to All Tables
SELECT audit.audit_table(ns.nspname, child.relname)
FROM pg_class parent
JOIN pg_inherits ON pg_inherits.inhparent = parent.oid
JOIN pg_class child ON pg_inherits.inhrelid = child.oid
JOIN pg_namespace ns ON parent.relnamespace = ns.oid
WHERE (ns.nspname, parent.relname) = ('audit', 'auditable')
  AND NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgrelid = child.oid
    AND tgname = 'track_changes_' || ns.nspname || '_' || child.relname)
ORDER BY ns.nspname, child.relname;