## SOLAR DATASET INVESTIGATION USING SQL

This project uses the Solar Power Plant data from Kaggle to perform some explorations into the power generation capacities of the two plants in question and answer some questions about their performances. This project was also a means to practice SQL queries, and some more complex mechanisms such as joins, window functions and common table expressions. It was an interesting exercise to question the data through a business perspective, finding ways to measure efficiency as well as obtain a holistic perspective of the domain by connecting the environmental factors to the plants results.

## Dataset

Kaggle "Solar Power Generation Data": 2 plants, 22 inverters each. Link: [(https://www.kaggle.com/datasets/anikannal/solar-power-generation-data)]

## Tables

- p1_generation_data / p2_generation_data: DC/AC power and yield per inverter
- p1_weather_data / p2_weather_data: ambient temp, module temp, irradiation

## The questions are as follows (with some notes for insights I learnt for a few questions):

Q1. What is the total AC power generated per day, per plant?

Q2. Which day produced the most energy overall?

Q3. What are the average, minimum and maximum module temperatures per day?

Q4. Which hours of the day have the highest average power output?
P1_HOUR_24H P1_AVG_AC_POWER
11 957.6883081188219
12 950.4819394891116
13 902.0329363746262
10 852.3285287777726
14 780.0390297989876
P2_HOUR_24H P2_AVG_AC_POWER
12 659.3892420530572
9 652.729013624079
10 630.2847790326948
11 630.2388188509029
14 624.9591788029691
As expected, hours surrounding midday when sunlight is the strongest have a high power output.

Q5. At what irradiance levels does the plant produce the most power?
IRRADIATION_CATEGORY AVG_AC
1.2 1296.4829950909095
1.1 1256.8313844785712
1 1207.4081461195735
0.9 1133.7685946428282
0.8 1026.542139598487
0.7 924.1457201488644
0.6 802.3419096883437
0.5 687.7015734573774
0.4 560.0871409682616
0.3 446.56118117229846
IRRADIATION_CATEGORY AVG_AC
1 772.6084469841277
0.7 727.3752791016514
0.9 717.1965112121047
0.8 689.333510636925
0.6 651.1867518754088
0.5 631.1171553686859
1.1 564.1656926406927
0.4 530.5549938443268
0.3 455.0263878509153
Plants 1 and 2 actually differed in their performances here, and we can also see that there isn't always a direct correlation between irradiation and efficiency.

Q6. Does the plant generate more power on cooler or hotter days with similar irradiance?
For this question and the previous one, what I learnt new was grouping together rows into bands, not formed through column properties but by their numerical values and bucketing them using insight for clearer results (eg. grouping together certain temperatures too classify a day as Hot, Warm or Cool, or by categories of irradation).
IRRADIATION_CATEGORY TEMP AVG_AC
0.3 Cool 445.61492424242437
0.3 Hot 492.3684848484849
0.3 Warm 455.02994624473865
0.4 Cool 582.9728787878787
0.4 Hot 535.2332738095236
0.4 Warm 528.9195272117996
0.5 Hot 671.5040630638016
0.5 Warm 627.3193689608636
0.6 Hot 730.5531711661044
0.6 Warm 629.1308760550177
0.7 Hot 722.845791951004
0.7 Warm 731.4530063790098
0.8 Hot 708.265367111234
0.8 Warm 659.6202192822291
0.9 Hot 716.5810807703822
0.9 Warm 724.4990067519544
1 Hot 774.5645054945061
1 Warm 707.8806926406927
1.1 Hot 564.1656926406927

Q7. Which inverter generated the most energy?
Here, using a CTE made the calculation a lot more readable as well as implementing the RANK() function.

```sql
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
```

Q8. Which inverters underperform compared to the plant average?
Here we can draw the insight by ordering the result in a descending order on how much they differed from he plant average.

```sql
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
```

Q9. How did daily energy change compared to the previous day?
This question involved using LAG(), and using it to track trends across days.

```sql
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
```

Q10. Which inverter was the best performer each day?
Here ranking by using PARTITION BY allowed a more detailed look into the data, comparing inverters on a daily basis.

```sql
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
```

Q11. A view for a daily summary of important information
