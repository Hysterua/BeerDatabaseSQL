-- COMP3311 22T3 Assignment 1 Z5208823
--
-- Fill in the gaps ("...") below with your code
-- You can add any auxiliary views/function that you like
-- The code in this file *MUST* load into an empty database in one pass
-- It will be tested as follows:
-- createdb test; psql test -f ass1.dump; psql test -f ass1.sql
-- Make sure it can load without error under these conditions

-- Q1: new breweries in Sydney in 2020
CREATE OR REPLACE VIEW Q1 AS
SELECT breweries.name, locations.town FROM breweries
JOIN locations ON breweries.located_in = locations.id
WHERE breweries.founded = 2020
AND locations.metro = 'Sydney';

-- Q2: beers whose name is same as their style
CREATE OR REPLACE VIEW Q2 AS
SELECT beers.name AS beerName, breweries.name AS breweryName FROM brewed_by
JOIN beers ON brewed_by.beer = beers.id
JOIN breweries ON brewed_by.brewery = breweries.id
JOIN styles ON beers.style = styles.id
WHERE beers.name = styles.name;

-- Q3: original Californian craft brewery
CREATE OR REPLACE VIEW Q3 AS
SELECT breweries.name, breweries.founded from breweries
WHERE breweries.founded = (
    SELECT MIN(founded) FROM breweries
    JOIN locations ON breweries.located_in = locations.id
    WHERE locations.region = 'California'
);

-- Q4: all IPA variations, and how many times each occurs
CREATE OR REPLACE VIEW Q4 AS
SELECT styles.name, COUNT(styles.name) from beers
JOIN styles ON beers.style = styles.id
WHERE styles.name LIKE '%IPA%'
GROUP BY styles.name;

-- Q5: all Californian breweries, showing precise location
CREATE OR REPLACE VIEW Q5 AS
SELECT breweries.name, CASE
        WHEN locations.town IS NULL THEN locations.metro
        ELSE locations.town
        END AS area
FROM breweries
INNER JOIN locations ON breweries.located_in = locations.id
WHERE locations.region = 'California';

-- Q6: strongest barrel-aged beer
CREATE OR REPLACE VIEW Q6 AS
SELECT beers.name AS beerName, breweries.name AS breweryName, beers.abv FROM brewed_by
JOIN beers ON brewed_by.beer = beers.id
JOIN breweries ON brewed_by.brewery = breweries.id
WHERE beers.abv = (
    SELECT MAX(beers.ABV) FROM beers
    WHERE beers.notes LIKE '%barrel%'
    AND beers.notes LIKE '%aged%'
);

-- Q7: most popular hop
CREATE OR REPLACE VIEW Q7 AS
SELECT ingredients.name AS hops FROM contains
JOIN ingredients ON contains.ingredient = ingredients.id
WHERE itype = 'hop'
GROUP BY ingredients.name
ORDER BY COUNT(ingredients.name) DESC
FETCH FIRST 1 ROWS WITH TIES;

-- Q8: breweries that don't make IPA or Lager or Stout (any variation thereof)
CREATE OR REPLACE VIEW Q8 AS
SELECT breweries.name FROM breweries
EXCEPT (
    SELECT breweries.name FROM brewed_by
    JOIN breweries ON brewed_by.brewery = breweries.id
    JOIN beers ON brewed_by.beer = beers.id
    JOIN styles ON beers.style = styles.id
    WHERE styles.name LIKE '%Lager%'
    OR styles.name LIKE '%IPA%'
    OR styles.name LIKE '%Stout%'
);

-- Q9: most commonly used grain in Hazy IPAs
CREATE OR REPLACE VIEW Q9 AS
SELECT ingredients.name FROM contains
JOIN ingredients ON contains.ingredient = ingredients.id
JOIN beers ON contains.beer = beers.id
JOIN styles ON beers.style = styles.id
WHERE styles.name = 'Hazy IPA'
AND itype = 'grain'
GROUP BY ingredients.name
ORDER BY COUNT(ingredients.name) DESC
FETCH FIRST 1 ROWS WITH TIES;

-- Q10: ingredients not used in any beer
CREATE OR REPLACE VIEW Q10 AS
SELECT ingredients.name FROM ingredients
EXCEPT (
    SELECT ingredients.name FROM contains
    JOIN ingredients ON contains.ingredient = ingredients.id
);

-- Q11: min/max abv for a given country
-- Didn't change source code to match style as I wasn't sure if this was appropriate
drop type if exists ABVrange cascade;
create type ABVrange as (minABV float, maxABV float);

CREATE OR REPLACE FUNCTION Q11(_country text) RETURNS abvrange AS $$
DECLARE
    min_abv abvvalue;
    max_abv abvvalue;
    result abvrange;
BEGIN
    SELECT MIN(beers.abv) INTO min_abv FROM brewed_by
    JOIN breweries ON brewed_by.brewery = breweries.id
    JOIN beers ON brewed_by.beer = beers.id
    JOIN locations ON breweries.located_in = locations.id
    WHERE locations.country = _country;

    SELECT MAX(beers.abv) INTO max_abv FROM brewed_by
    JOIN breweries ON brewed_by.brewery = breweries.id
    JOIN beers ON brewed_by.beer = beers.id
    JOIN locations ON breweries.located_in = locations.id
    WHERE locations.country = _country;

    IF min_abv IS NULL THEN
        min_abv := 0;
        max_abv := 0;
    END IF;

    result = (min_abv::numeric(4,1), max_abv::numeric(4,1));
    RETURN result;
END
$$ language plpgsql;

-- Q12: details of beers
-- Didn't change source code to match style as I wasn't sure if this was appropriate
drop type if exists BeerData cascade;
create type BeerData as (beer text, brewer text, info text);

-- This function is used to determine the hops string for a passed in beer from a passed in brewer
CREATE OR REPLACE FUNCTION Q12_Helper(_beerName text, exactBreweryName text) RETURNS text AS
$$
DECLARE
    hops text;
    grains text;
    extras text;
    i record;
    finalOutput text;
BEGIN
    FOR i IN (SELECT ingredients.itype, ingredients.name from brewed_by
    JOIN beers ON brewed_by.beer = beers.id
    JOIN contains ON contains.beer = beers.id
    JOIN breweries ON brewed_by.brewery = breweries.id
    JOIN ingredients ON contains.ingredient = ingredients.id
    WHERE beers.name = _beerName
    AND exactBreweryName = breweries.name
    ORDER BY ingredients.name)
    LOOP
        IF i.itype = 'hop' THEN
            IF hops IS NULL THEN
                hops = i.name;
            ELSE
                hops = (SELECT CONCAT(hops,',', i.name));
            END IF;
        END IF;

        IF i.itype = 'grain' THEN
            IF grains IS NULL THEN
                grains = i.name;
            ELSE
                grains = (SELECT CONCAT(grains,',', i.name));
            END IF;
        END IF;

        IF i.itype = 'adjunct' THEN
            IF extras IS NULL THEN
                extras = i.name;
            ELSE
                extras = (SELECT CONCAT(extras,',', i.name));
            END IF;
        END IF;
    END LOOP;

    IF hops IS NOT NULL THEN
        hops = (SELECT CONCAT('Hops: ', hops));
        finalOutput = hops;
    END IF;

    IF grains IS NOT NULL THEN
        grains = (SELECT CONCAT('Grain: ', grains));
        IF finalOutput IS NULL THEN
            finalOutput = grains;
        ELSE
            finalOutput = (SELECT CONCAT(finalOutput,E'\n',grains));
        END IF;
    END IF;

    IF extras IS NOT NULL THEN
        extras = (SELECT CONCAT('Extras: ', extras));
        IF finalOutput IS NULL THEN
            finalOutput = extras;
        ELSE
            finalOutput = (SELECT CONCAT(finalOutput,E'\n',extras));
        END IF;
    END IF;

    RETURN finalOutput;

END;
$$ language plpgsql;


CREATE OR REPLACE FUNCTION Q12(partial_name text) RETURNS SETOF BeerData AS
$$
DECLARE
    i record;
BEGIN
    FOR i IN
        (SELECT DISTINCT brewed_by.beer, beers.name AS beerName, breweryName AS brewer, Q12_Helper(beers.name, breweries.name) AS info FROM brewed_by
        JOIN beers ON brewed_by.beer = beers.id
        JOIN breweries ON brewed_by.brewery = breweries.id
        FULL OUTER JOIN
        (SELECT brewed_by.beer AS id, string_agg(breweries.name::CHARACTER VARYING, ' + ' ORDER BY breweries.name ASC) AS breweryName FROM brewed_by
        JOIN breweries ON brewed_by.brewery = breweries.id
        GROUP BY brewed_by.beer) AS sortedBrewer
        ON sortedBrewer.id = brewed_by.beer
        WHERE beers.name ILIKE CONCAT('%',partial_name,'%'))
    LOOP
        RETURN NEXT (i.beerName,i.brewer,i.info);
    END LOOP;
END;
$$ language plpgsql;
