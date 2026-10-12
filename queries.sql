USE solar;
-- Q1. What is the total AC power generated per day, per plant?
SELECT DATE(DATE_TIME) AS DAY,
    SUM(AC_POWER) as P1_AC_POWER
from p1_generation_data
GROUP BY DAY;
SELECT DATE(DATE_TIME) AS DAY,
    SUM(AC_POWER) as P2_AC_POWER
from p2_generation_data
GROUP BY DAY;
-- Q2. Which day produced the most energy overall?
SELECT DATE(DATE_TIME) as P1_DAY,
    SUM(AC_POWER) * (15 / 60) as P1_TOTAL_ENERGY
FROM p1_generation_data
GROUP BY DATE(DATE_TIME)
ORDER BY P1_TOTAL_ENERGY DESC
LIMIT 1;
SELECT DATE(DATE_TIME) as P2_DAY,
    SUM(AC_POWER) * (15 / 60) as P2_TOTAL_ENERGY
FROM p2_generation_data
GROUP BY DATE(DATE_TIME)
ORDER BY P2_TOTAL_ENERGY DESC
LIMIT 1;
-- Q3. What are the average, minimum and maximum module temperatures per day?
SELECT DATE(DATE_TIME),
    AVG(MODULE_TEMPERATURE),
    MIN(MODULE_TEMPERATURE),
    MAX(MODULE_TEMPERATURE)
from p1_weather_data
GROUP BY DATE(DATE_TIME)
ORDER BY DATE(DATE_TIME);
SELECT DATE(DATE_TIME),
    AVG(MODULE_TEMPERATURE),
    MIN(MODULE_TEMPERATURE),
    MAX(MODULE_TEMPERATURE)
from p2_weather_data
GROUP BY DATE(DATE_TIME)
ORDER BY DATE(DATE_TIME);
-- Q4. Which hours of the day have the highest average power output?
SELECT HOUR(DATE_TIME) as P1_HOUR_24H,
    AVG(AC_POWER) as P1_AVG_AC_POWER
from p1_generation_data
GROUP BY HOUR(DATE_TIME)
ORDER BY P1_AVG_AC_POWER DESC
LIMIT 5;
SELECT HOUR(DATE_TIME) as P2_HOUR_24H,
    AVG(AC_POWER) as P2_AVG_AC_POWER
from p2_generation_data
GROUP BY HOUR(DATE_TIME)
ORDER BY P2_AVG_AC_POWER DESC
LIMIT 5;
-- Q5. At what irradiance levels does the plant produce the most power?
SELECT ROUND(p1w.IRRADIATION, 1) AS IRRADIATION_CATEGORY,
    AVG(p1g.AC_POWER) AS AVG_AC
FROM p1_weather_data AS p1w
    JOIN p1_generation_data AS p1g ON p1w.DATE_TIME = p1g.DATE_TIME
WHERE p1w.IRRADIATION >= 0.3
GROUP BY IRRADIATION_CATEGORY
ORDER BY AVG_AC DESC;
SELECT ROUND(p2w.IRRADIATION, 1) AS IRRADIATION_CATEGORY,
    AVG(p2g.AC_POWER) AS AVG_AC
FROM p2_weather_data AS p2w
    JOIN p2_generation_data AS p2g ON p2w.DATE_TIME = p2g.DATE_TIME
WHERE p2w.IRRADIATION >= 0.3
GROUP BY IRRADIATION_CATEGORY
ORDER BY AVG_AC DESC;
Q6.Does the plant generate more power on cooler
or hotter days with similar irradiance ?
SELECT ROUND(p1w.IRRADIATION, 1) as IRRADIATION_CATEGORY,
    CASE
        WHEN p1w.MODULE_TEMPERATURE < 30 THEN 'Cool'
        WHEN p1w.MODULE_TEMPERATURE < 50 THEN 'Warm'
        ELSE 'Hot'
    END AS TEMP,
    AVG(p1g.AC_POWER) AS AVG_AC
FROM p1_weather_data AS p1w
    JOIN p1_generation_data AS p1g ON p1w.DATE_TIME = p1g.DATE_TIME
WHERE p1w.IRRADIATION >= 0.3
GROUP BY IRRADIATION_CATEGORY,
    TEMP
ORDER BY IRRADIATION_CATEGORY,
    TEMP;
SELECT ROUND(p2w.IRRADIATION, 1) as IRRADIATION_CATEGORY,
    CASE
        WHEN p2w.MODULE_TEMPERATURE < 30 THEN 'Cool'
        WHEN p2w.MODULE_TEMPERATURE < 50 THEN 'Warm'
        ELSE 'Hot'
    END AS TEMP,
    AVG(p2g.AC_POWER) AS AVG_AC
FROM p2_weather_data AS p2w
    JOIN p2_generation_data AS p2g ON p2w.DATE_TIME = p2g.DATE_TIME
WHERE p2w.IRRADIATION >= 0.3
GROUP BY IRRADIATION_CATEGORY,
    TEMP
ORDER BY IRRADIATION_CATEGORY,
    TEMP;
-- Q7. Which inverter generated the most energy?
WITH inverter_energy AS (
    SELECT SOURCE_KEY AS P1_INVERTER_ID,
        SUM(AC_POWER) * (15 / 60) AS P1_TOTAL_ENERGY
    FROM p1_generation_data
    GROUP BY SOURCE_KEY
)
SELECT P1_INVERTER_ID,
    ROUND(P1_TOTAL_ENERGY, 1) AS P1_TOTAL_ENERGY,
    RANK() OVER (
        ORDER BY P1_TOTAL_ENERGY DESC
    ) AS ENERGY_RANK
FROM inverter_energy
ORDER BY ENERGY_RANK;
-- Q8.Which inverters underperform compared to the plant average ? 
WITH inverter_energy AS (
    SELECT SOURCE_KEY as P1_INVERTER_ID,
        SUM(AC_POWER) * (15 / 60) AS TOTAL_ENERGY
    FROM p1_generation_data
    GROUP BY SOURCE_KEY
)
SELECT P1_INVERTER_ID,
    ROUND(TOTAL_ENERGY, 1),
    ROUND(AVG(TOTAL_ENERGY) OVER (), 1) AS PLANT_AVG,
    ROUND(TOTAL_ENERGY / AVG(TOTAL_ENERGY) OVER() * 100, 1) AS PERCENT
FROM inverter_energy
ORDER BY PERCENT;
-- Q9. How did daily energy change compared to the previous day?
WITH daily AS(
    SELECT DATE(DATE_TIME) AS DATE,
        SUM(AC_POWER) * (15 / 60) AS TOTAL_ENERGY
    FROM p2_generation_data
    GROUP BY DATE(DATE_TIME)
)
SELECT DATE,
    ROUND(TOTAL_ENERGY, 1) AS TOTAL_ENERGY,
    ROUND(
        TOTAL_ENERGY - LAG(TOTAL_ENERGY, 1, NULL) OVER (
            ORDER BY DATE
        ),
        1
    ) AS DIFF,
    ROUND(
        (
            TOTAL_ENERGY - LAG(TOTAL_ENERGY, 1, NULL) OVER (
                ORDER BY DATE
            )
        ) / LAG(TOTAL_ENERGY, 1, NULL) OVER (
            ORDER BY DATE
        ) * 100,
        1
    ) AS PERCENT
from daily
ORDER BY DATE;
-- Q10. Which inverter was the best performer each day?
WITH daily AS(
    SELECT SOURCE_KEY,
        DATE(DATE_TIME) AS DAY,
        MAX(DAILY_YIELD) AS YIELD
    FROM p2_generation_data
    GROUP BY SOURCE_KEY,
        DATE(DATE_TIME)
),
ranked AS (
    SELECT *,
        RANK() OVER (
            PARTITION BY DAY
            ORDER BY YIELD DESC
        ) AS YIELD_RANK
    FROM daily
)
SELECT DAY,
    SOURCE_KEY,
    YIELD
from ranked
WHERE YIELD_RANK = 1
ORDER BY DAY;
-- Q11. A view for a daily summary of important information
CREATE OR REPLACE VIEW daily_summary AS
SELECT DATE(g.DATE_TIME) AS DAY,
    ROUND(SUM(g.AC_POWER), 1) AS TOTAL_PWR,
    ROUND(MAX(w.IRRADIATION), 1) AS HIGHEST_IRR,
    ROUND(AVG(w.MODULE_TEMPERATURE)),
    1 AS AVG_TEMP
FROM p2_generation_data g
    JOIN p2_weather_data w ON g.DATE_TIME = w.DATE_TIME
GROUP BY DATE(g.DATE_TIME);
SELECT *
FROM daily_summary;