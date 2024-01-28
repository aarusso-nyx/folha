
DROP VIEW IF EXISTS folha.carreiras_grau_nivel CASCADE;
CREATE VIEW folha.carreiras_grau_nivel AS
SELECT *
FROM (SELECT unnest(enum_range(NULL::grau)) AS nivel) AS t1
CROSS JOIN (SELECT unnest(enum_range(NULL::nivel)) AS grau) AS t2;




INSERT INTO folha.carreiras (nivel, grau, cargo_id, jornada_id, valor)
SELECT nivel, grau, cargo_id, jornada_id, 0
FROM folha.cargos, folha.jornadas, folha.carreiras_grau_nivel;
