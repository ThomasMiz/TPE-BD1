DROP TABLE IF EXISTS continente CASCADE;
DROP TABLE IF EXISTS region CASCADE;
DROP TABLE IF EXISTS pais CASCADE;
DROP TABLE IF EXISTS anio CASCADE;
DROP TABLE IF EXISTS turismo CASCADE;

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

CREATE TABLE turismo (
    idPais INT NOT NULL,
    anio INT NOT NULL,
    aerea INT NOT NULL,
    maritima INT NOT NULL,
    PRIMARY KEY(idPais, anio),
    FOREIGN KEY(idPais) REFERENCES pais(id) ON DELETE CASCADE,
    FOREIGN KEY(anio) REFERENCES anio(anio) ON DELETE CASCADE
);