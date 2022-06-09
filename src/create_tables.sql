DROP TABLE IF EXISTS continente CASCADE;
DROP TABLE IF EXISTS region CASCADE;
DROP TABLE IF EXISTS pais CASCADE;
DROP TABLE IF EXISTS anio CASCADE;
DROP TABLE IF EXISTS turismoDatos CASCADE;
DROP VIEW IF EXISTS turismo;

CREATE TABLE continente (
    id SERIAL,
    nombre TEXT NOT NULL,
    PRIMARY KEY(id),
    UNIQUE(nombre)
);

CREATE TABLE region (
    id SERIAL,
    idContinente INT NOT NULL,
    nombre TEXT NOT NULL,
    PRIMARY KEY(id),
    UNIQUE(idContinente, nombre),
    FOREIGN KEY(idContinente) REFERENCES continente (id) ON DELETE CASCADE
);

CREATE TABLE pais (
    id SERIAL,
    idRegion INT NOT NULL,
    nombre TEXT NOT NULL,
    PRIMARY KEY(id),
    UNIQUE(idRegion, nombre),
    FOREIGN KEY(idRegion) REFERENCES region (id) ON DELETE CASCADE
);

CREATE TABLE anio (
    anio INT NOT NULL,
    esBisiesto BOOLEAN NOT NULL,
    PRIMARY KEY(anio)
);

CREATE TABLE turismoDatos (
    idPais INT NOT NULL,
    anio INT NOT NULL,
    aerea INT NOT NULL,
    maritima INT NOT NULL,
    PRIMARY KEY(idPais, anio),
    FOREIGN KEY(idPais) REFERENCES pais(id) ON DELETE CASCADE,
    FOREIGN KEY(anio) REFERENCES anio(anio) ON DELETE CASCADE
);

CREATE VIEW turismo AS
SELECT pais.nombre AS pais, (aerea+maritima) AS total, aerea, maritima, region.nombre AS region, continente.nombre AS continente, anio
FROM turismoDatos JOIN pais ON turismoDatos.idPais=pais.id JOIN
region ON pais.idRegion=region.id JOIN continente ON region.idContinente=continente.id;
