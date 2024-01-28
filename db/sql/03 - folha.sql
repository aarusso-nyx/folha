CREATE TABLE audit.auditable (    
    user_id     INTEGER NOT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by INTEGER NOT NULL,
 
    revoked_at TIMESTAMP,
    revoked_by INTEGER,

    active     BOOLEAN NULL DEFAULT TRUE    
);


-- Abstract base class for all tables with inicio-fim
DROP TABLE IF EXISTS audit.periodo CASCADE;
CREATE TABLE audit.periodo (
    inicio     DATE NOT NULL,
    fim        DATE,

    CHECK ((fim IS NULL) OR (inicio < fim))
) INHERITS (audit.auditable);

-- ----------------------------------------------------------------------------
-- Endereços
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS folha.enderecos CASCADE;
CREATE TABLE folha.enderecos (
    endereco_id     SERIAL PRIMARY KEY,

    logradouro      TEXT NOT NULL,
    numero          TEXT NOT NULL,
    complemento     TEXT,
    bairro          TEXT NOT NULL,
    cep             TEXT NOT NULL,

--     mun             INTEGER NOT NULL REFERENCES municipios(ibge_id),
--     uf              INTEGER NOT NULL REFERENCES estados(ibge_id),

    pos             GEOGRAPHY(POINT, 4326)  
) INHERITS (audit.auditable);


-- ----------------------------------------------------------------------------
-- Pessoas
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS folha.pessoas CASCADE;
CREATE TABLE folha.pessoas (
    pessoa_id       SERIAL PRIMARY KEY,
    cpf             TEXT NOT NULL UNIQUE,

    nome            TEXT NOT NULL,
    nasc            DATE NOT NULL,
    endereco_id     INTEGER NOT NULL REFERENCES folha.enderecos(endereco_id)
) INHERITS (audit.auditable);

-- ----------------------------------------------------------------------------
-- Filiais e Unidades
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS folha.filiais CASCADE;
CREATE TABLE folha.filiais (
    filial_id       SERIAL PRIMARY KEY,
    cnpj            TEXT NOT NULL UNIQUE,

    nome            TEXT NOT NULL,
    endereco_id     INTEGER NOT NULL REFERENCES folha.enderecos(endereco_id)
) INHERITS (audit.auditable); 


DROP TABLE IF EXISTS folha.unidades CASCADE;
CREATE TABLE folha.unidades (
    unidade_id      SERIAL PRIMARY KEY,
    filial_id       INTEGER NOT NULL REFERENCES folha.filiais(filial_id),

    endereco_id     INTEGER NOT NULL REFERENCES folha.enderecos(endereco_id)
) INHERITS (audit.auditable);

-- ----------------------------------------------------------------------------
-- Papéis e Perfis
-- ----------------------------------------------------------------------------
DROP ENUM IF EXISTS folha.roles CASCADE;
CREATE TYPE folha.roles AS ENUM (
    'Administrador',
    'Gestor',
    'Funcionário',
    'Cidadão',
    'Filial/Órgão'
    'Fornecedor',
    'Parceiro Público',
    'Parceiro Privado'
);

DROP TABLE IF EXISTS folha.perfis CASCADE;
CREATE TABLE folha.perfis (
    perfil_id       SERIAL PRIMARY KEY,

    pessoa_id       INTEGER NOT NULL REFERENCES folha.pessoas(pessoa_id),
    papel           roles NOT NULL
) INHERITS (audit.auditable);

-- ----------------------------------------------------------------------------
-- Cargos, Jornadas e Carreiras
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS folha.cargos CASCADE;
CREATE TABLE folha.cargos (
    cargo_id        SERIAL PRIMARY KEY,
    cargo_desc      TEXT NOT NULL
) INHERITS (audit.auditable);


DROP TABLE IF EXISTS folha.jornadas CASCADE;
CREATE TABLE folha.jornadas (
    jornada_id      SERIAL PRIMARY KEY,
    jornada_desc    TEXT NOT NULL,

    cargo_id        INTEGER NOT NULL REFERENCES folha.cargos(cargo_id),
    horas           INTEGER NOT NULL
) INHERITS (audit.auditable);

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
DROP TYPE IF EXISTS folha.carreira_nivel CASCADE;
CREATE TYPE folha.carreira_nivel AS ENUM ('A','B','C','D','E');

DROP TYPE IF EXISTS folha.carreira_grau CASCADE;
CREATE TYPE folha.carreira_grau AS ENUM ('1', '2', '3', '4', '5');

DROP TABLE IF EXISTS folha.carreiras CASCADE;
CREATE TABLE folha.carreiras (
    carreira_id     SERIAL PRIMARY KEY,

    cargo_id        INTEGER NOT NULL REFERENCES folha.cargos(cargo_id),
    jornada_id      INTEGER NOT NULL REFERENCES folha.jornadas(jornada_id),

    nivel           carreira_nivel NOT NULL,
    grau            carreira_grau  NOT NULL,
    
    valor           NUMERIC NOT NULL,

    UNIQUE (cargo_id, jornada_id, nivel, grau)
) INHERITS (audit.auditable);


-- ----------------------------------------------------------------------------
-- Quadro Funcional e Vagas por Unidade
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS folha.quadro CASCADE;
CREATE TABLE folha.quadro (
    quadro_id       SERIAL PRIMARY KEY,

    unidade_id      INTEGER NOT NULL REFERENCES folha.unidades(unidade_id),
    cargo_id        INTEGER NOT NULL REFERENCES folha.cargos(cargo_id),
    jornada_id      INTEGER NOT NULL REFERENCES folha.jornadas(jornada_id),
    vagas           INTEGER NOT NULL DEFAULT 0,

    UNIQUE (unidade_id, cargo_id, jornada_id)
) INHERITS (audit.auditable);

-- ----------------------------------------------------------------------------
-- Vinculos
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS folha.categorias CASCADE;
CREATE TABLE folha.categorias (
    categoria_id SERIAL PRIMARY KEY,
    categoria         TEXT NOT NULL UNIQUE
) INHERITS (audit.auditable);

INSERT INTO folha.categorias (user_id, created_by, categoria) VALUES 
(0, 0, 'Efetivo'), 
(0, 0, 'Comissionado'), 
(0, 0, 'Contratado'), 
(0, 0, 'Estagiário'), 
(0, 0, 'Terceirizado');

DROP TABLE IF EXISTS folha.vinculos CASCADE;
CREATE TABLE folha.vinculos (
    vinculo_id      SERIAL PRIMARY KEY,
    categoria_id    INTEGER NOT NULL REFERENCES folha.categorias(categoria_id),
    carreira_id     INTEGER NOT NULL REFERENCES folha.carreiras(carreira_id),
    pessoa_id       INTEGER NOT NULL REFERENCES folha.pessoas(pessoa_id),

    matricula       INTEGER NOT NULL UNIQUE
) INHERITS (audit.auditable, audit.periodo);

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS folha.lotacao CASCADE;
CREATE TABLE folha.lotacao (
    quadro_id       INTEGER NOT NULL REFERENCES folha.quadro(quadro_id),
    vinculo_id      INTEGER NOT NULL REFERENCES folha.vinculos(vinculo_id), 

    PRIMARY KEY (quadro_id, vinculo_id)
) INHERITS (audit.auditable);


-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS folha.escopos CASCADE;
CREATE TABLE folha.escopos (
    escopo_id       SERIAL PRIMARY KEY,

    filial_id       INTEGER REFERENCES folha.filiais(filial_id),
    unidade_id      INTEGER REFERENCES folha.unidades(unidade_id),
    
    vinculo_id      INTEGER REFERENCES folha.vinculos(vinculo_id),

    cargo_id        INTEGER REFERENCES folha.cargos(cargo_id),
    jornada_id      INTEGER REFERENCES folha.jornadas(jornada_id),
    categoria_id    INTEGER REFERENCES folha.categorias(categoria_id)
    
) INHERITS (audit.auditable);

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS folha.folha_status CASCADE;
CREATE TABLE folha.folha_status (
    status SERIAL       PRIMARY KEY,
    descricao           TEXT NOT NULL
);

INSERT INTO folha.folha_status (descricao)
VALUES ('Aberta'), ('Fechada'), ('Cancelada'), ('Reaberta'), ('Quitada');

DROP TABLE IF EXISTS folha.folha CASCADE;
CREATE TABLE folha.folha (
    folha_id SERIAL     PRIMARY KEY,
    competencia         INTEGER NOT NULL,

    escopo              INTEGER REFERENCES folha.escopos(escopo_id),
    status              INTEGER NOT NULL DEFAULT 0 REFERENCES folha.folha_status(status),

    UNIQUE (competencia, escopo, status)
) INHERITS (audit.auditable, audit.periodo);





-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS folha.rubrica_tipos CASCADE;
CREATE TABLE folha.rubrica_tipos (
    rubrica_tipo_id SERIAL PRIMARY KEY,
    rubrica_tipo TEXT NOT NULL UNIQUE
) INHERITS (audit.auditable);

INSERT INTO folha.rubrica_tipos (user_id, created_by, rubrica_tipo)
VALUES (0,0,'Provento'), (0,0,'Desconto'), (0,0,'Indenização'), (0,0,'Dedução'), (0,0,'Base de Cálculo');

DROP TABLE IF EXISTS folha.rubrica CASCADE;
CREATE TABLE folha.rubricas (
    rubrica_id SERIAL   PRIMARY KEY,
    rubrica_tipo        INTEGER NOT NULL REFERENCES folha.rubrica_tipos(rubrica_tipo_id),
    rubrica             TEXT NOT NULL,

    escopo              INTEGER REFERENCES folha.escopos(escopo_id),
    regra JSONB, 

    peso INTEGER NOT NULL DEFAULT 0,
    CHECK(peso = -1 OR peso = 0 OR peso = 1)
) INHERITS (audit.auditable, audit.periodo);



-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS folha.lancamentos CASCADE;
CREATE TABLE folha.lancamentos (
    lancamento_id   SERIAL PRIMARY KEY,
    folha_id        INTEGER NOT NULL REFERENCES folha.folha(folha_id),

    vinculo_id      INTEGER NOT NULL REFERENCES folha.vinculos(vinculo_id),
    rubrica_id      INTEGER NOT NULL REFERENCES folha.rubricas(rubrica_id),

    valor           NUMERIC NOT NULL,

    origem          INTEGER, -- competencia de origem 

    UNIQUE (folha_id, vinculo_id, rubrica_id)
) INHERITS (audit.auditable);