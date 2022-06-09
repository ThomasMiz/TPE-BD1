DROP FUNCTION IF EXISTS CalcConsolidarTransporte;
DROP FUNCTION IF EXISTS AnalisisConsolidado;

CREATE FUNCTION CalcConsolidarTransporte(panio anio.anio%type)
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
    IF n=0 THEN RETURN; END IF;
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