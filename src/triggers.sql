CREATE OR REPLACE FUNCTION IsLeapYear(anio IN anio.anio%type)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (anio % 4 = 0) AND (anio % 100 <> 0 OR anio % 400 = 0);
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION OnTurismoAnioInsertingOrUpdating()
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

CREATE OR REPLACE TRIGGER TrgTurismoAnioInsertingOrUpdating
BEFORE INSERT OR UPDATE OF anio ON turismoDatos FOR EACH ROW
EXECUTE PROCEDURE OnTurismoAnioInsertingOrUpdating();

CREATE OR REPLACE FUNCTION OnInsertOrUpdateTurismo()
RETURNS TRIGGER AS $$
DECLARE
idCont continente.id%type;
idRegi region.id%type;
idPais pais.id%type;
BEGIN
    IF (NEW.aerea + NEW.maritima <> NEW.total)
    THEN
        RAISE EXCEPTION '%', 'Total doesnt match the sum';
    END IF;
    
    SELECT id INTO idCont FROM continente WHERE continente.nombre=NEW.continente;
    IF (idCont IS NULL)
    THEN
        INSERT INTO continente (nombre) VALUES (NEW.continente) RETURNING id INTO idCont;
    END IF;
    
    SELECT id INTO idRegi FROM region WHERE region.nombre=NEW.region;
    IF (idRegi IS NULL)
    THEN
        INSERT INTO region (idContinente, nombre) VALUES (idCont, NEW.region) RETURNING id INTO idRegi;
    END IF;
    
    SELECT id INTO idPais FROM pais WHERE pais.nombre=NEW.pais;
    IF (idPais IS NULL)
    THEN
        INSERT INTO pais (idRegion, nombre) VALUES (idRegi, NEW.pais) RETURNING id INTO idPais;
    END IF;
    
    INSERT INTO turismoDatos VALUES (idPais, NEW.anio, NEW.aerea, NEW.maritima);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER TrgInsertOrUpdateTurismo
INSTEAD OF INSERT OR UPDATE ON turismo FOR EACH ROW
EXECUTE PROCEDURE OnInsertOrUpdateTurismo();
