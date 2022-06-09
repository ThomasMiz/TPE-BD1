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
