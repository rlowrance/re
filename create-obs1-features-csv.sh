# create-obs1-features-csv.sh
# append the various CSV files in the obs1 features directory into one big features file
# the input files should be the same as those used in create-estimates.lua
FILES=ACRES-log-std.csv \
    BEDROOMS-std.csv  \
    \
    census-avg-commute-std.csv \
    census-income-log-std.csv \
    census-ownership-std.csv \
    \
    day-std.csv  \
    \
    FOUNDATION-CODE-is-001.csv \
    FOUNDATION-CODE-is-CRE.csv \
    FOUNDATION-CODE-is-MSN.csv \
    FOUNDATION-CODE-is-PIR.csv \
    FOUNDATION-CODE-is-RAS.csv \
    FOUNDATION-CODE-is-SLB.csv \
    \
    HEATING-CODE-is-00S.csv \
    HEATING-CODE-is-001.csv \
    HEATING-CODE-is-BBE.csv \
    HEATING-CODE-is-CL0.csv \
    HEATING-CODE-is-FA0.csv \
    HEATING-CODE-is-FF0.csv \
    HEATING-CODE-is-HP0.csv \
    HEATING-CODE-is-HW0.csv \
    HEATING-CODE-is-SP0.csv \
    HEATING-CODE-is-ST0.csv \
    HEATING-CODE-is-GR0.csv \
    HEATING-CODE-is-RD0.csv \
    HEATING-CODE-is-SV0.csv \
    \
    IMPROVEMENT_VALUE_CALCULATED-log-std.csv \
    LAND_VALUE-CALCULATED-log-std.csv \
    \
    latitude-std.csv \
    LIVING-SQUARE-FEET-log-std.csv \
    \
    LOCATION-INFLUENCE-CODE-is-I01.csv \
    LOCATION-INFLUENCE-CODE-is-IBF.csv \
    LOCATION-INFLUENCE-CODE-is-ICA.csv \
    LOCATION-INFLUENCE-CODE-is-ICR.csv \
    LOCATION-INFLUENCE-CODE-is-ICU.csv \
    LOCATION-INFLUENCE-CODE-is-IGC.csv \
    LOCATION-INFLUENCE-CODE-is-ILP.csv \
    LOCATION-INFLUENCE-CODE-is-IRI.csv \
    \
    longtitude-std.csv \
    PARKING-SPACES-std.csv \
    \
    PARKING-TYPE-CODE-is-110.csv \
    PARKING-TYPE-CODE-is-120.csv \
    PARKING-TYPE-CODE-is-140.csv \
    PARKING-TYPE-CODE-is-450.csv \
    PARKING-TYPE-CODE-is-920.csv \
    PARKING-TYPE-CODE-is-A00.csv \
    PARKING-TYPE-CODE-is-ASP.csv \
    PARKING-TYPE-CODE-is-OSP.csv \
    PARKING-TYPE-CODE-is-PAP.csv \
    \
    percent-improvement-value-std.csv \
    \
    POOL-FLAG-is-0.csv \
    \
    ROOF-TYPE-CODE-is-F00.csv \
    ROOF-TYPE-CODE-is-G00.csv \
    \
    SALE-AMOUNT-log-std.csv \
    TOTAL-BATHS-CALCULATED-std.csv \
    \
    YEAR-BUILT-std.csv \

echo FILES=$FILES

../../../../build-linux-64/csvAppend \
ACRES-log-std.csv \
BEDROOMS-std.csv \
\
census-avg-commute-std.csv \
census-income-log-std.csv \
census-ownership-std.csv \
\
day-std.csv  \
\
FOUNDATION-CODE-is-001.csv \
FOUNDATION-CODE-is-CRE.csv \
FOUNDATION-CODE-is-MSN.csv \
FOUNDATION-CODE-is-PIR.csv \
FOUNDATION-CODE-is-RAS.csv \
FOUNDATION-CODE-is-SLB.csv \
\
HEATING-CODE-is-00S.csv \
HEATING-CODE-is-001.csv \
HEATING-CODE-is-BBE.csv \
HEATING-CODE-is-CL0.csv \
HEATING-CODE-is-FA0.csv \
HEATING-CODE-is-FF0.csv \
HEATING-CODE-is-HP0.csv \
HEATING-CODE-is-HW0.csv \
HEATING-CODE-is-SP0.csv \
HEATING-CODE-is-ST0.csv \
HEATING-CODE-is-GR0.csv \
HEATING-CODE-is-RD0.csv \
HEATING-CODE-is-SV0.csv \
\
IMPROVEMENT-VALUE-CALCULATED-log-std.csv \
LAND-VALUE-CALCULATED-log-std.csv \
\
latitude-std.csv \
LIVING-SQUARE-FEET-log-std.csv \
\
LOCATION-INFLUENCE-CODE-is-I01.csv \
LOCATION-INFLUENCE-CODE-is-IBF.csv \
LOCATION-INFLUENCE-CODE-is-ICA.csv \
LOCATION-INFLUENCE-CODE-is-ICR.csv \
LOCATION-INFLUENCE-CODE-is-ICU.csv \
LOCATION-INFLUENCE-CODE-is-IGC.csv \
LOCATION-INFLUENCE-CODE-is-ILP.csv \
LOCATION-INFLUENCE-CODE-is-IRI.csv \
\
longitude-std.csv \
PARKING-SPACES-std.csv \
\
PARKING-TYPE-CODE-is-110.csv \
PARKING-TYPE-CODE-is-120.csv \
PARKING-TYPE-CODE-is-140.csv \
PARKING-TYPE-CODE-is-450.csv \
PARKING-TYPE-CODE-is-920.csv \
PARKING-TYPE-CODE-is-A00.csv \
PARKING-TYPE-CODE-is-ASP.csv \
PARKING-TYPE-CODE-is-OSP.csv \
PARKING-TYPE-CODE-is-PAP.csv \
\
percent-improvement-value-std.csv \
\
POOL-FLAG-is-0.csv \
\
ROOF-TYPE-CODE-is-F00.csv \
ROOF-TYPE-CODE-is-G00.csv \
\
SALE-AMOUNT-log-std.csv \
TOTAL-BATHS-CALCULATED-std.csv \
\
YEAR-BUILT-std.csv \
 > features.csv
