----------------------------
--------- Tables -----------
----------------------------

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
    anio INT NOT NULL CHECK (anio > 0),
    esBisiesto BOOLEAN NOT NULL,
    PRIMARY KEY(anio)
);

CREATE TABLE turismoDatos (
    idPais INT NOT NULL,
    anio INT NOT NULL,
    aerea INT NOT NULL CHECK (aerea >= 0),
    maritima INT NOT NULL CHECK (maritima >= 0),
    PRIMARY KEY(idPais, anio),
    FOREIGN KEY(idPais) REFERENCES pais(id) ON DELETE CASCADE,
    FOREIGN KEY(anio) REFERENCES anio(anio) ON DELETE CASCADE
);

CREATE VIEW turismo AS
SELECT pais.nombre AS pais, (aerea+maritima) AS total, aerea, maritima, region.nombre AS region, continente.nombre AS continente, anio
FROM turismoDatos JOIN pais ON turismoDatos.idPais=pais.id JOIN
region ON pais.idRegion=region.id JOIN continente ON region.idContinente=continente.id;


---------------------------
-------- Triggers ---------
---------------------------

DROP FUNCTION IF EXISTS IsLeapYear;
DROP TRIGGER IF EXISTS TrgTurismoAnioInsertingOrUpdating ON turismodatos;
DROP TRIGGER IF EXISTS TrgInsertOrUpdateTurismo ON turismo;
DROP FUNCTION IF EXISTS OnTurismoAnioInsertingOrUpdating;
DROP FUNCTION IF EXISTS OnInsertOrUpdateTurismo;

CREATE FUNCTION IsLeapYear(anio anio.anio%type)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (anio % 4 = 0) AND (anio % 100 <> 0 OR anio % 400 = 0);
END
$$ LANGUAGE plpgsql;

CREATE FUNCTION OnTurismoAnioInsertingOrUpdating()
RETURNS TRIGGER AS $$
DECLARE c INT;
BEGIN
    SELECT COUNT(*) INTO c FROM anio WHERE anio.anio=NEW.anio;
    IF (c = 0)
    THEN
        INSERT INTO anio VALUES (NEW.anio, IsLeapYear(NEW.anio));
    END IF;
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER TrgTurismoAnioInsertingOrUpdating BEFORE INSERT OR UPDATE OF anio ON turismoDatos FOR EACH ROW EXECUTE PROCEDURE OnTurismoAnioInsertingOrUpdating();

CREATE FUNCTION OnInsertOrUpdateTurismo()
RETURNS TRIGGER AS $$
DECLARE
idCont continente.id%type;
idRegi region.id%type;
idPais pais.id%type;
BEGIN
    IF (NEW.aerea < 0 OR NEW.maritima < 0)
    THEN
        RAISE EXCEPTION '%', 'Aerea and Maritima must be >= 0.';
    END IF;

    IF (NEW.aerea + NEW.maritima <> NEW.total)
    THEN
        RAISE WARNING '%', 'Total doesnt match the sum. Value will be replaced by the actual sum.';
    END IF;

    IF (NEW.anio <= 0)
    THEN
        RAISE EXCEPTION '%', 'Anio must  be greater than 0.';
    END IF;

    IF (NEW.anio < 1903 AND NEW.aerea <> 0)
    THEN
        RAISE EXCEPTION '%', 'Aereal tourists cant arrive before planes were invented.';
    END IF;
    
    SELECT id INTO idCont FROM continente WHERE continente.nombre=NEW.continente;
    IF (idCont IS NULL)
    THEN
        INSERT INTO continente (nombre) VALUES (NEW.continente) RETURNING id INTO idCont;
    END IF;
    
    SELECT id INTO idRegi FROM region WHERE region.nombre=NEW.region AND region.idContinente=idCont;
    IF (idRegi IS NULL)
    THEN
        INSERT INTO region (idContinente, nombre) VALUES (idCont, NEW.region) RETURNING id INTO idRegi;
    END IF;
    
    SELECT id INTO idPais FROM pais WHERE pais.nombre=NEW.pais AND pais.idRegion=idRegi;
    IF (idPais IS NULL)
    THEN
        INSERT INTO pais (idRegion, nombre) VALUES (idRegi, NEW.pais) RETURNING id INTO idPais;
    END IF;
    
    INSERT INTO turismoDatos VALUES (idPais, NEW.anio, NEW.aerea, NEW.maritima);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER TrgInsertOrUpdateTurismo INSTEAD OF INSERT ON turismo FOR EACH ROW EXECUTE PROCEDURE OnInsertOrUpdateTurismo();

---------------------------
-------- Functions --------
--------------------------- 
DROP FUNCTION IF EXISTS CalcConsolidarTransporte;
DROP FUNCTION IF EXISTS AnalisisConsolidado;

CREATE FUNCTION CalcConsolidarTransporte(IN panio anio.anio%type)
RETURNS record AS $$
DECLARE aux record;
BEGIN
    SELECT SUM(turismoDatos.aerea) AS totalAerea,
    SUM(turismoDatos.maritima) AS totalMaritima,
    CAST(AVG(turismoDatos.aerea) AS INT) AS avgAerea,
    CAST(AVG(turismoDatos.maritima) AS INT) AS avgMaritima
    INTO aux
    FROM turismoDatos JOIN pais ON turismoDatos.idPais=pais.id JOIN region ON pais.idRegion=region.id JOIN continente ON region.idContinente=continente.id
    WHERE anio=panio;
    
    RETURN aux;
END; $$ LANGUAGE plpgsql;

CREATE FUNCTION AnalisisConsolidado(IN n INT)
RETURNS VOID AS $$
DECLARE
cur CURSOR FOR (
SELECT anio, continente.id AS idCont, continente.nombre AS nombreCont,
SUM(turismoDatos.aerea+turismoDatos.maritima) AS total,
CAST(AVG(turismoDatos.aerea+turismoDatos.maritima) AS INT) AS average
FROM turismoDatos JOIN pais ON turismoDatos.idPais=pais.id JOIN region ON
pais.idRegion=region.id JOIN continente ON region.idContinente=continente.id
WHERE anio<(SELECT MIN(anio.anio) FROM anio)+n
GROUP BY continente.id, anio ORDER BY anio
);
aux record;
transporte record;
prevAnio anio.anio%type;
yearPrinted BOOLEAN;
BEGIN
    IF n<=0 THEN RETURN; END IF;
    RAISE NOTICE '--------------------------------------------';
    RAISE NOTICE '-------CONSOLIDATED TOURIST REPORT----------';
    RAISE NOTICE '--------------------------------------------';
    RAISE NOTICE 'Year---Category--------------Total---Average';
    RAISE NOTICE '--------------------------------------------';
    
    OPEN cur;
    prevAnio := NULL;
    yearPrinted := FALSE;
    
    LOOP
        FETCH cur INTO aux;
        EXIT WHEN NOT FOUND;
        
        IF (prevAnio IS NULL OR prevAnio <> aux.anio)
        THEN
            IF (prevAnio IS NOT NULL)
            THEN
                transporte := CalcConsolidarTransporte(prevAnio);
                IF yearPrinted
                THEN
                    RAISE NOTICE '----   Transporte:   Aereo   %   %', transporte.totalAerea, transporte.avgAerea;
                ELSE
                    RAISE NOTICE '%   Transporte:   Aereo   %   %', prevAnio, transporte.totalAerea, transporte.avgAerea;
                END IF;
                RAISE NOTICE '----   Transporte:   Maritimo   %   %', transporte.totalMaritima, transporte.avgMaritima;
                RAISE NOTICE '----------------------------  %   %', (transporte.totalAerea+transporte.totalMaritima), (transporte.avgAerea+transporte.avgMaritima);
                RAISE NOTICE '--------------------------------------------';
            END IF;
            prevAnio = aux.anio;
            yearPrinted := FALSE;
        END IF;
        
        IF yearPrinted
        THEN
            RAISE NOTICE '----   Continente: %   %   %', aux.nombreCont, aux.total, aux.average;
        ELSE
            RAISE NOTICE '%   Continente: %   %   %', aux.anio, aux.nombreCont, aux.total, aux.average;
        END IF;
        yearPrinted := TRUE;
        
    END LOOP;
    
    IF (prevAnio IS NOT NULL)
    THEN
        transporte := CalcConsolidarTransporte(prevAnio);
        IF yearPrinted
        THEN
            RAISE NOTICE '----   Transporte:   Aereo   %   %', transporte.totalAerea, transporte.avgAerea;
        ELSE
            RAISE NOTICE '%   Transporte:   Aereo   %   %', prevAnio, transporte.totalAerea, transporte.avgAerea;
        END IF;
        RAISE NOTICE '----   Transporte:   Maritimo   %   %', transporte.totalMaritima, transporte.avgMaritima;
        RAISE NOTICE '----------------------------  %   %', (transporte.totalAerea+transporte.totalMaritima), (transporte.avgAerea+transporte.avgMaritima);
        RAISE NOTICE '--------------------------------------------';
    END IF;
    
    CLOSE cur;
END;
$$ LANGUAGE plpgsql;


DO $$
DECLARE aux record;
BEGIN
    PERFORM AnalisisConsolidado(2);
END; $$ LANGUAGE plpgsql