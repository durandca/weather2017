*******************************************************************
*Combine weather data with CHTS data and conduct spatial data prep*
*******************************************************************

**Import weather station information and match to nearest zip code centroid

*Import station text file
import delimited "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\Weather_data\201207station.txt", delimiter("|") varnames(1) 

*Drop if not a CA weather station
drop if state!="CA"

*Drop non-airports
drop if inlist(wban, 4222, 53139, 53150, 53151, 53152, 93243, 93245)

*keep relevant vars
keep wban name location latitude longitude

*save
save "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\weather_stations_CA.dta"

*Append to geocoded zip file
use "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\chts_zips_geocoded.dta" 

append using "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\weather_stations_CA.dta"

*save
 save "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\weather_station_zip_code_appended.dta"

**Dist match to nearest neighbor
*Add variable to indicate donors and recipients
g donor=1 if wban!=.
g recip=1 if wban==.

*create temporary id for the distmatch procedure.  Need to do this because some values of wban
*are the same as some of the values of hzip.  Therefore, they cannot uniquely identify obs
*within the appended dataset.  Since we need the wban to be on the same row as the corresponding 
*hzhip for later merge with CHTS dataset,this workaround will allow that to happen.
g id=_n
replace id=wban if wban!=.

*find nearest neighbor
distmatch, latitude(latitude) longitude(longitude) near(1) don(donor) rec(recip) id(id) noisily

*Drop appended station data
drop if wban!=.

*save
save "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\weather_station_zip_code_appended.dta", replace

*Merge results into the main CHTS HH/person/place file

merge m:1 hzip using "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\weather_station_zip_code_appended.dta", keepusing(_id1 _dist1) generate(_merge_ws)

*rename some vars 

ren _id1 wban

ren _dist1 wban_dist

*save
save "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\chts_household_person_place_weather_stations_merged.dta"


***weather prep***
***After downloading and extracting text files for each month from Jan 2012 to Feb 2013...

*Import hourly data into Stata

foreach date in 201201 201202 201203 201204 201205 201206 201207 201208 201209 201210 201211 201212 201301 201302{

*Import station identifiers into Stata

import delimited "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\Weather_data/`date'station.txt", delimiter("|", asstring)

*save

save "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather/`date'station" 

clear

*import hourly data

import delimited "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\Weather_data/`date'hourly.txt"

*save

save "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather/`date'hourly"

*Merge the two files

merge m:1 wban using "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather/`date'station"

*save

save "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather/`date'merged"

*Extract only California stations

keep if state=="CA"

*Eliminate non-airport locations !!!!!!!!!check that this list is comprehensive 
drop if inlist(wban, 4222, 53139, 53150, 53151, 53152, 93243, 93245)

*save

save "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather/`date'ca_only"


*Destring all relevant variables except relative humidity.  Need to change blanks in precipitation to 0 as long 
*as other data elements aren't denoted as missing.  Can't destring RH yet because that is the basis for 
*determining whether precipitation data is missing or not.  After that, will destring RH.
destring drybulbfarenheit windspeed hourlyprecip, replace force

*Recode blank values as 0 for the hourly precipitation variable as long as other vars are not missing.
*Note that there is no way to know for sure whether they are missing or zero; we are inferring from other variables
replace hourlyprecip=0 if relativehumidity!="M" & hourlyprecip==.

*destring relative humidity
destring relativehumidity, replace force

*Calculate summary stats for each day
collapse (min) mintemp=drybulbfarenheit (max) maxtemp=drybulbfarenheit (mean) meantemp=drybulbfarenheit  ///
meanrh=relativehumidity  meanwindspd=windspeed (sum) sumprecip=hourlyprecip, by(wban date)

*save

save "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather/`date'sumstats"

clear

}

*Append together
use "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\201201sumstats"
foreach date in 201202 201203 201204 201205 201206 201207 201208 201209 201210 201211 201212 201301 201302{
append using "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather/`date'sumstats"
save "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\appendedsumstats", replace
}

*Make dates Stata-readable
tostring date, generate(dateobs)
gen dateobs2 = date(dateobs, "YMD")
format dateobs2 %td
drop dateobs
ren dateobs2 dateobs

*drop days with no data
drop if date==.

save "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\appendedsumstats", replace

*Merge weather data into CHTS dataset by station ID and day of year

use "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\chts_household_person_place_weather_stations_merged.dta" 

*extract travel date from CHTS dataset 

gen dateobs = date(recdate, "YMDhms")

format dateobs %td

*merge hpp and weather data

merge m:1 wban dateobs using "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\appendedsumstats.dta", generate(_merge5)

drop if _merge5==2

save "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\chts_hpp_weather_merged"

*Merge in activities file
*Still working in hpp file
sort sampn perno plano 
egen sampnpernoplano=concat(sampno perno plano)
order sampnpernoplano, after(plano)
destring sampnpernoplano, replace

save "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\chts_hpp_weather_merged", replace

clear

*Now work in activities file
use "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\chts_activity"

sort sampn perno plano actno
egen sampnpernoplano=concat(sampno perno plano)
order sampnpernoplano, after(plano)
destring sampnpernoplano, replace

*Merge files from HPP file into Activity file
merge m:1 sampnpernoplano using "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\chts_hpp_weather_merged", generate(_mergeX)

save "C:\Users\Casey\Google Drive\Work\Papers\CHTS_weather\chts_hpp_weather_activity_merged", replace

*Run PA data prep

*create single new variable to indicate individual people by
*combining household and person-within-household identifiers
egen sampnperno=concat(sampn perno)
order sampnperno, after(plano)

***********************************************************
*Flag transport related physical activity*
***********************************************************

***Identify walk/bike trips used to get to/from transit

**Necessary definitions using CHTS coding scheme:
*Active travel: 1 (walking), 2 (biking)
*Transit: 15 (local bus/rapid bus), 16 (express bus), 17 (premium bus), 19 (public transit shuttle)
*24 (BART, Metro Red/Purple line, aka heavy rail), 26 (light rail), 27 (street car/cable car)

*First, need to capture trips to reach transit

*Create a variable to flag those trips that preceded a transit trip.  We are assuming
*these are how they accessed transit.

gen tranxflag=0
la var tranxflag "Flag obs if preceded a transit trip"
order tranxflag, after(mode)
bys sampnperno: replace tranxflag=1 if inlist(mode[_n+1], 15, 16, 17, 19, 24, 26, 27)

*Create a variable to indicate if access mode was active (walking or biking)

gen activtrans=0
la var activtrans "Active transit access(1) or not (0)"
order activtrans, after(tranxflag)
bys sampnperno: replace activtrans=1 if tranxflag==1 & inlist(mode, 1, 2)


*Create variable capturing transit access trip minutes that were active
g activmin=tripdur*activtrans

*create variable containing summ of activmins for each trip
bys sampnperno: egen totalmins=total(activmin)


***Identify walk/bike trips to get to a destination other than transit

**Other destination types: shopping/errands, food/eating, social, work, school, other personal, home(regardless of activity purpose at home)

**NOTE: Because each trip can have 1-3 purposes, trips can appear in 1 or more of the broad categories above.  This is part of the reason for
*running separate regressions for each destination type.

**ALSO: All trips that are "to home" are categorized together, and the other trips separated by specific categories are counted contingent on them
*not being to home.

**Shopping/errands

*STEP 1: generate a variable indicating if person engaged in any
*shopping trips at all during the day, regardless of access mode. Results in a 
*binary variable "shopatall", 1=yes, 0=no.
gen shopaxflag=0
replace shopaxflag=1 if inlist(apurp, 27, 28, 29) & pname!="HOME"
bys sampnperno: egen shopatall=total(shopaxflag)
replace shopatall=1 if shopatall!=0

*STEP 2: generate variable indicating if people who engaged in any
*shopping trips at all during the day used an active mode (walk or bike).
*Results in binary variable "shopact", 1=yes, 0=no.
g shopact=0 if shopatall==1
replace shopact=1 if inlist(mode,1,2) & inlist(apurp, 27, 28, 29) & pname!="HOME"


*STEP 3: sum up active (walk, bike) minutes as part of trip to get to 
*shopping destinations.  Zeros are generated for people who went shopping but did
*not use active mode, as well as those who did not go shopping at all.  This distinction
*will be sorted out using the "shopatall" binary variable from above as part of the 
*Heckman model.  This code written to ensure that time associated with activites with the same 
*broad purpose within each trip are not counted multiple times.  This is because within each
*trip, there can be multiple activities; all have the same associated trip characteristics, 
*(e.g. trip dur, mode, etc)
g shopactmin=0
bys sampnpernoplano: gen shopcount=_n if inlist(apurp, 27, 28, 29) & pname!="HOME"
bys sampnpernoplano: egen minshop=min(shopcount)
replace shopactmin=tripdur if inlist(mode,1,2) & shopcount==minshop
replace shopactmin=0 if shopcount==.
bys sampnperno: egen tactshopmin=total(shopactmin), missing

**food/eating

*STEP 1:
gen foodaxflag=0
replace foodaxflag=1 if inlist(apurp, 2, 18, 31) & pname!="HOME"
bys sampnperno: egen foodatall=total(foodaxflag)
replace foodatall=1 if foodatall!=0

*STEP 2:
g foodactmin=0
bys sampnpernoplano: gen foodcount=_n if inlist(apurp, 2, 18, 31) & pname!="HOME"
bys sampnpernoplano: egen minfood=min(foodcount)
replace foodactmin=tripdur if inlist(mode,1,2) & foodcount==minfood
replace foodactmin=0 if foodcount==.
bys sampnperno: egen tactfoodmin=total(foodactmin), missing

**social/entertainment

*STEP 1:
gen socaxflag=0
replace socaxflag=1 if inlist(apurp, 36, 37, 13, 3) & pname!="HOME"
bys sampnperno: egen socatall=total(socaxflag)
replace socatall=1 if socatall!=0

*STEP 2:
g socactmin=0
bys sampnpernoplano: gen soccount=_n if inlist(apurp, 36, 37, 13, 3) & pname!="HOME"
bys sampnpernoplano: egen minsoc=min(soccount)
replace socactmin=tripdur if inlist(mode,1,2) & soccount==minsoc
replace socactmin=0 if soccount==.
bys sampnperno: egen tactsocmin=total(socactmin), missing

**work

*STEP 1:
gen workaxflag=0
replace workaxflag=1 if inlist(apurp, 25, 16, 9, 10, 11, 12) & pname!="HOME"
bys sampnperno: egen workatall=total(workaxflag)
replace workatall=1 if workatall!=0

*STEP 2:
g workactmin=0
bys sampnpernoplano: gen workcount=_n if inlist(apurp, 25, 16, 9, 10, 11, 12) & pname!="HOME"
bys sampnpernoplano: egen minwork=min(workcount)
replace workactmin=tripdur if inlist(mode,1,2) & workcount==minwork
replace workactmin=0 if workcount==.
bys sampnperno: egen tactworkmin=total(workactmin), missing

**school

*STEP 1:
gen schaxflag=0
replace schaxflag=1 if inlist(apurp, 5, 17) & pname!="HOME"
bys sampnperno: egen schatall=total(schaxflag)
replace schatall=1 if schatall!=0

*STEP 2:
g schactmin=0
bys sampnpernoplano: gen schcount=_n if inlist(apurp, 5, 17) & pname!="HOME"
bys sampnpernoplano: egen minsch=min(schcount)
replace schactmin=tripdur if inlist(mode,1,2) & schcount==minsch
replace schactmin=0 if schcount==.
bys sampnperno: egen tactschmin=total(schactmin), missing

**other personal, including exercise

*STEP 1:
gen operaxflag=0
replace operaxflag=1 if inlist(apurp, 30, 32, 33, 1, 15, 14, 35, 34, 4, 19, 20) & pname!="HOME"
bys sampnperno: egen operatall=total(operaxflag)
replace operatall=1 if operatall!=0

*STEP 2:
g operactmin=0
bys sampnpernoplano: gen opercount=_n if inlist(apurp, 30, 32, 33, 1, 15, 14, 35, 34, 4, 19, 20) & pname!="HOME"
bys sampnpernoplano: egen minoper=min(opercount)
replace operactmin=tripdur if inlist(mode,1,2) & opercount==minoper
replace operactmin=0 if opercount==.
bys sampnperno: egen tactopermin=total(operactmin), missing

**home (regardless of activty purpose at home)
*!!!!!!!!!!!Check flow of step two as well to be sure it still works
*given that this is now contingent on the pname and not apurp

*STEP 1:
gen homeaxflag=0
replace homeaxflag=1 if pname=="HOME"
bys sampnperno: egen homeatall=total(homeaxflag)
replace homeatall=1 if homeatall!=0

*STEP 2:
g homeactmin=0
bys sampnpernoplano: gen homecount=_n if pname=="HOME"
bys sampnpernoplano: egen minhome=min(homecount)
replace homeactmin=tripdur if inlist(mode,1,2) & homecount==minhome
replace homeactmin=0 if homecount==.
bys sampnperno: egen tacthomemin=total(homeactmin), missing

*******************
*Regression models*
*******************

**data preparation

*keep only the first record for each person, since that records their daily totals in the different categories.




****Three part models
*Part 1: Went to a particular destination (y/n)
*Part 2: Active travel to destination (y/n)
*Part 3: Minutes in active travel (>greater than zero)

*Run separately for each destination

foreach dest of {
gsem(`dest' <- indepvars, probit) (`acttrav' <- indepvars, probit) (`minact' <- indepvars, gamma), vce(clus sampn) ///*check vce spec

}

*produce marginal effects based on combined model

margins, dydx(*) exp(predict(outcome(depvar1)) * predict(outcome(depvar2)) * predict(outcome(depvar3))) vce(unconditional) ///*vce correct?
























