**This files starts with prematching_dataset_long and makes prematched_clean

cd "C:\Users\530443\Google Drive\Research projects\Competitiveness\" //computer Frank
*cd "ETS_competitiveness/data/"  *computer antoine
* matching dataset
set more off
use prematching_dataset_long, clear
destring nace3dig, replace 
destring nace4dig, replace
keep bvdid country_code ETS nace4dig nace3dig
duplicates drop
compress
save prematching_dataset_nace_ctry_ETS, replace
*=================================================================================================================
use prematching_dataset_long, clear 
keep bvdid year fias toas empl opre oppl plbt 
* keep fixed assets fias=intangible and tangible (everything except current assets)
duplicates tag bvd year, gen(dup)
tab dup
 * 11,422 dupplicates in bvd & year have different missing variables for fias empl opre 
*browse if dup>0
bys bvd : egen dupyes=max(dup)
* when there is a unique value and 2 rows, populate with this unique value. then drop duplicates.
foreach xxx in fias toas empl opre oppl plbt{  
	gen missing_`xxx'=`xxx'==. if dup>0
	bys bvd year : gen nmissing_`xxx'=sum(missing_`xxx') if dup>0
	bys bvd year : egen max_`xxx'=max(`xxx') if dup>0
	replace `xxx' = max_`xxx' if dup==1 & nmissing_`xxx'==1
	replace `xxx' = max_`xxx' if dup==2 & nmissing_`xxx'==2
	drop max_`xxx' missing_`xxx' nmissing_`xxx'
}
drop dup dupyes
duplicates drop
duplicates tag bvd year, gen(dup)
tab dup
bys bvd : egen dupyes=max(dup)
* replace with missing if the value is not the minimum of the absolute distance to the mean of the variable across the bvdid
foreach xxx in fias toas empl opre oppl plbt{  
	bys bvd : egen meant_`xxx'=mean(`xxx') if dupyes>0
	gen `xxx'_absdiffmeant = abs(`xxx'- meant_`xxx') if dupyes>0
	by bvd year : egen min_absdiffmeant_`xxx'=min(`xxx'_absdiffmeant) if dupyes>0
	replace `xxx' = . if `xxx'_absdiffmeant!=min_absdiffmeant_`xxx' & dup>0 
}
drop dup dupyes *meant*
duplicates drop

duplicates tag bvd year, gen(dup)
tab dup
bys bvd : egen dupyes=max(dup)
foreach xxx in fias toas empl opre oppl plbt{  
	gen missing_`xxx'=`xxx'==. if dup>0
	bys bvd year : gen nmissing_`xxx'=sum(missing_`xxx') if dup>0
	bys bvd year : egen max_`xxx'=max(`xxx') if dup>0
	replace `xxx' = max_`xxx' if dup==1 & nmissing_`xxx'==1
	replace `xxx' = max_`xxx' if dup==2 & nmissing_`xxx'==2
	drop max_`xxx' missing_`xxx' nmissing_`xxx'
}
drop dup dupyes
duplicates drop
duplicates tag bvd year, gen(dup)
tab dup
* deal with remaining issues: (1) 3 lines and only 1 missing value; (2) minuscule differences. by inspection, not problematic to do this.
foreach xxx in fias toas empl opre oppl plbt{  
	bys bvd year : egen max_`xxx'=max(`xxx') if dup>0
	replace `xxx' = max_`xxx' if dup>0
	drop max_`xxx' 
}
drop dup
duplicates drop
duplicates tag bvd year, gen(dup)
tab dup
drop dup
fillin bvdid year 
* adds observations with missing to obtain a 'balanced' panel
drop _fillin
save prematching_temp1, replace
*================================================================================================================
use prematching_temp1, clear
egen firm_id=group(bvdid)
xtset firm_id year, yearly

/*
* Drop if all observations before 2005 are missing
foreach xxx in opre empl fias { 
	bys firm_id : egen mean_`xxx'=mean(`xxx') if year<2005 & year>2001
	gen missing_mean_`xxx'=mean_`xxx'==. & year<2005 & year>2001
	by firm_id : egen max_missing_mean_`xxx'=max(missing_mean_`xxx') //to include the later years in the dropped observations
	drop if max_missing_mean_`xxx'>0
	}
	drop mean* *missing*
*Drop if all obs after 2004 are missing
foreach xxx in opre empl fias { 
	bys firm_id : egen mean_`xxx'=mean(`xxx') if year>2004 & year<2013
	gen missing_mean_`xxx'=mean_`xxx'==. & year>2004 & year<2013
	by firm_id : egen max_missing_mean_`xxx'=max(missing_mean_`xxx') 
}
drop if max_missing_mean_opre==1 & max_missing_mean_empl==1 & max_missing_mean_fias==1

count if  (max_missing_mean_opre==1 | max_missing_mean_empl==1 | max_missing_mean_fias==1) //259000 would be dropped, dont exclude here
drop mean* *missing*

*interpolation for missing data within pre period. 
*creates 7976 interpoated obs in 2003 and 14,278 interpolated obs in 2002, generally small companies, P90% has 60 employees (same numbers for fias, empl and opre)
foreach xxx in fias empl opre oppl plbt{ 
	bys firm_id (year) : ipolate `xxx' year if year<2005, generate(`xxx'_ip) 
	*tab year if `xxx'_ip!=. & `xxx'==.
	replace `xxx'=`xxx'_ip if year<2005 //var ip is missing for 2005 and after
	drop `xxx'_ip
	*bys firm_id (year) : ipolate `xxx' year if year>2004, generate(`xxx'_ip_post)
	*replace `xxx'=`xxx'_ip_post if year>2004
	*drop `xxx'_ip_post
}
*keep if year>2001 & year<2013 // too early because growth in 2002 and 2013 is needed below to detect spikes

*/

ren opre revenue 
ren empl employees 
ren fias assets
ren oppl ebit //operating profit/loss=operating revenue-cost of sales and other costs
ren plbt ebt // profit/loss before tax= includes financial revenues (sales of emission permits) and financial taxes

save prematching_temp2, replace

*================================================================================================================
**truncate at p99.9 and drop unlikely values: 1. revenue/employee 2.asset/employee 3.spikes in employees 4.spikes in assets
*================================================================================================================
use prematching_temp2, clear

/*
**truncate values at the p99.9 (one pro mille) : revenue>5.5 billion; employees > 8800; assets>7.5 billion; EBIT>452 million or EBT >608 million
**564 companies deleted
foreach xxx in revenue employees assets ebit ebt { 
egen `xxx'_p999=pctile(`xxx'), p(99.9)
sum `xxx'_p999
}
foreach xxx in revenue employees assets ebit ebt { 
bysort bvdid: egen `xxx'_max=max(`xxx')
drop if `xxx'_max > `xxx'_p999 & `xxx'_max!=. //I drop entire company because too big, unlikely to have a meaningful match
drop `xxx'_max  `xxx'_p999 
}
*****Revenue/employee >31 million (1promille of data)
***These companies are suspected to be financial headquarters of ETS firms(possibly also wrongly identified as non-ETS). 
**Dropping the entire time series if problem occurs once protects against firms that switch from being producing entity towards financial headquarter
gen revenue_per_empl=revenue/employees
summarize revenue_per_empl, detail
summarize revenue_per_empl if revenue_per_empl>r(p99), detail //  (10 obs from 3 companies in old matched database )
gen high_revenue_per_empl=1 if revenue_per_empl>r(p90) & revenue_per_empl!=.
bys firm_id: egen high_revenue_company=total(high_revenue_per_empl)
drop if high_revenue_company>=1 //5071 obs deleted.
drop high_revenue_company high_revenue_per_empl revenue_per_empl

****Assets/employee > 74 million
**Goldman sachs with 1000billion assets was identified as ETS in old matched dataset, CARGILL spain ran 500 million assets with 2 employees which was an error in the employee data.
gen assets_per_empl=assets/employees
summarize assets_per_empl, detail
summarize assets_per_empl if assets_per_empl>r(p99) , detail 
gen high_assets_per_empl=1 if assets_per_empl>r(p90)  & assets_per_empl!=.
by firm_id: egen high_assets_company=total(high_assets_per_empl)
drop if high_assets_company>=1 //4488 obs deleted
drop high_assets_company high_assets_per_empl assets_per_empl
*/

****drop unlikely spikes (up and down) 
sort firm_id year
**avoid zeros that are in reality missing to be able to define growth rates with respect to the value before
replace assets=. if assets==0 & l.assets!=0 &l.assets!=. & f.assets!=0 & f.assets!=.
replace employees=. if employees==0 & l.employees>10 &l.employees!=. & f.employees>10 & f.employees!=.

foreach xxx in employees assets revenue {
gen growth_`xxx' = (`xxx'-l.`xxx')/l.`xxx'
replace growth_`xxx' = (`xxx'-l2.`xxx')/l2.`xxx' if l.`xxx'==.
gen lag1_`xxx'=l.`xxx'
gen lag2_`xxx'=l2.`xxx'
gen lead1_`xxx'=f.`xxx'
gen lead2_`xxx'=f2.`xxx'
summarize `xxx', detail //p90 150 employees; p75=39 employees
global `xxx'_p50 =r(p50)
global `xxx'_p75 =r(p75)
}
*EMPLOYEES
*erase employees peaks, starting at least at P75 (39 emp), more than doubles, next more than halves (time series of 39 , 78 , 39 would be too suspicious)
*drop observation also if the spike is preceded and/or followed by a missing: time series 39,.,78,.,39 would be suspicious
*browse bvdid year growth_employees lag2_employees lag1_employees employees  lead1_employees lead2_employees if l.employees > $employees_p75*2 & growth_employees >1 & growth_employees!=. & (f.growth_employees<-0.5 | (f.growth_employees==. & f2.growth_employees<-0.5) ) 
replace employees=. if employees>$employees_p75 *2 & growth_employees>1 & growth_employees!=. & (f.growth_employees<-0.5 | (f.growth_employees==. & f2.growth_employees<-0.5)) //329 observations
* same for peaks starting at P50 (10 emp) but adding requirement that assets and revenue would not peak
*browse bvdid year growth_employees lag2_employees lag1_employees employees  lead1_employees lead2_employees if l.employees>$employees_p50 & growth_employees>1 & growth_employees!=.  & (f.growth_employees<-0.5 | (f.growth_employees==. & f2.growth_employees<-0.5) ) & growth_assets<0.2 & growth_revenue<0.2 & f.growth_assets>-0.2 & f.growth_revenue>-0.2
replace employees=. if employees>$employees_p50 *2 & growth_employees>1 & growth_employees!=. & (f.growth_employees<-0.5 | (f.growth_employees==. & f2.growth_employees<-0.5) ) & growth_assets<0.2 & growth_revenue<0.2 & f.growth_assets>-0.2 & f.growth_revenue>-0.2  //135 obs 
* same for peaks starting at least at P75, but increase of 70% adding requirement that assets and revenue would not peak ( 39, 67, 39 while assets and revenue do at most 100,120, 100)
*browse bvdid year growth_employees lag2_employees lag1_employees employees  lead1_employees lead2_employees if l.employees>$employees_p75 & growth_employees>0.70 & growth_employees!=.  & (f.growth_employees<-0.411 | (f.growth_employees==. & f2.growth_employees<-0.411) ) & growth_assets<0.2 & growth_revenue<0.2 & f.growth_assets>-0.2 & f.growth_revenue>-0.2
replace employees=. if employees>$employees_p75 *2 & growth_employees>0.70 & growth_employees!=. & (f.growth_employees<-0.411 | (f.growth_employees==. & f2.growth_employees<-0.411) ) & growth_assets<0.2 & growth_revenue<0.2 & f.growth_assets>-0.2 & f.growth_revenue>-0.2  //97 obs 
*Erase employees downward peaks, for employees starting at 2 times P75 (39) decreasing by more than 50% the following year and increasing by 100% the next year (timeseries 78 ;39;78 would seem suspicious)
*browse bvdid year growth_employees lag2_employees lag1_employees employees  lead1_employees lead2_employees if l.employees>$employees_p75 *2 & growth_employees<-0.50 & ((f.growth_employees>1 & f.growth_employees!=.) |(f.growth_employees==. & f2.growth_employees>1 & f2.growth_employees!=.) )
replace employees=. if l.employees>$employees_p75 *2 & growth_employees<-0.50 & ((f.growth_employees>1 & f.growth_employees!=.) | (f.growth_employees==. & f2.growth_employees>1 & f2.growth_employees!=.) )  //514 obs
*The same for downward peaks at P50 (10 emp) but adding requirement that assets and revenue would not peak
*browse bvdid year growth_employees lag2_employees lag1_employees employees  lead1_employees lead2_employees if l.employees>$employees_p50 *2 & growth_employees<-0.50 & ((f.growth_employees>1 & f.growth_employees!=.) |(f.growth_employees==. & f2.growth_employees>1 & f2.growth_employees!=.) )& growth_assets>-0.2 & growth_revenue>-0.2 & f.growth_assets<0.2 & f.growth_revenue<0.2 
replace employees=. if l.employees>$employees_p50 *2 & growth_employees<-0.50 & ((f.growth_employees>1 & f.growth_employees!=.) |(f.growth_employees==. & f2.growth_employees>1 & f2.growth_employees!=.) )& growth_assets>-0.2 & growth_revenue>-0.2 & f.growth_assets<0.2 & f.growth_revenue<0.2  //174 obs
* same for downward peaks starting at least at P75, but decrease of 70% adding requirement that assets and revenue would not peak ( 78, 46, 78 while assets and revenue do at most 100,80, 100)
*browse bvdid year growth_employees lag2_employees lag1_employees employees  lead1_employees lead2_employees if l.employees>$employees_p75 *2 & growth_employees<-0.411 & ((f.growth_employees>0.70 & f.growth_employees!=.) |(f.growth_employees==. & f2.growth_employees>0.70 & f2.growth_employees!=.) )& growth_assets>-0.2 & growth_revenue>-0.2 & f.growth_assets<0.2 & f.growth_revenue<0.2 
replace employees=. if l.employees>$employees_p75 *2 & growth_employees<-0.411 & ((f.growth_employees>0.70 & f.growth_employees!=.) |(f.growth_employees==. & f2.growth_employees>0.70 & f2.growth_employees!=.) )& growth_assets>-0.2 & growth_revenue>-0.2 & f.growth_assets<0.2 & f.growth_revenue<0.2  //184 obs

****ASSETS
*erase assets peaks, starting at least at P75 (4.25Million), more than doubles, next more than halves (time series of 4.25M; 8.5M; 4.25M would be too suspicious)
*drop observation also if the spike is preceded and/or followed by a missing. 
*browse bvdid year growth_assets lag2_assets lag1_assets assets  lead1_assets lead2_assets if l.assets > $assets_p75 & growth_assets >1 & growth_assets!=. & (f.growth_assets<-0.5 | (f.growth_assets==. & f2.growth_assets<-0.5) ) 
replace assets=. if assets>$assets_p75 *2 & growth_assets>1 & growth_assets!=. & (f.growth_assets<-0.5 | (f.growth_assets==. & f2.growth_assets<-0.5)) //377 observations
* same for peaks starting at P50 (850.000) but adding requirement that assets and revenue would not  peak
*browse bvdid year growth_assets lag2_assets lag1_assets assets  lead1_assets lead2_assets if l.assets>$assets_p50 & growth_assets>1 & growth_assets!=.  & (f.growth_assets<-0.5 | (f.growth_assets==. & f2.growth_assets<-0.5) ) & growth_employees<0.2 & growth_revenue<0.2 & f.growth_employees>-0.2 & f.growth_revenue>-0.2
replace assets=. if assets>$assets_p50 *2 & growth_assets>1 & growth_assets!=. & (f.growth_assets<-0.5 | (f.growth_assets==. & f2.growth_assets<-0.5) ) & growth_employees<0.2 & growth_revenue<0.2 & f.growth_employees>-0.2 & f.growth_revenue>-0.2  //61 obs 
*same as for employment
*browse bvdid year growth_assets lag2_assets lag1_assets assets  lead1_assets lead2_assets if l.assets>$assets_p75 & growth_assets>0.70 & growth_assets!=.  & (f.growth_assets<-0.411 | (f.growth_assets==. & f2.growth_assets<-0.411) ) & growth_employees<0.2 & growth_revenue<0.2 & f.growth_employees>-0.2 & f.growth_revenue>-0.2
replace assets=. if assets>$assets_p75 *2 & growth_assets>0.70 & growth_assets!=. & (f.growth_assets<-0.411 | (f.growth_assets==. & f2.growth_assets<-0.411) ) & growth_employees<0.2 & growth_revenue<0.2 & f.growth_employees>-0.2 & f.growth_revenue>-0.2  //49 obs 
*Erase assets downward peaks, for assets is above P75 (4.25Million) and decreased by more than 50% the preceding year and increases by 100% the next year (timeseries 78 ;39;78 would seem suspicious)
*browse bvdid year growth_assets lag2_assets lag1_assets assets  lead1_assets lead2_assets if l.assets>$assets_p75 *2 & growth_assets<-0.50 & ((f.growth_assets>1 & f.growth_assets!=.) |(f.growth_assets==. & f2.growth_assets>1 & f2.growth_assets!=.) )
replace assets=. if l.assets>$assets_p75 *2 & growth_assets<-0.50 & ((f.growth_assets>1 & f.growth_assets!=.) | (f.growth_assets==. & f2.growth_assets>1 & f2.growth_assets!=.) )  //372 obs
*The same for downward peaks at P50 (850.000) but adding requirement that assets and revenue would not peak
*browse bvdid year growth_assets lag2_assets lag1_assets assets  lead1_assets lead2_assets if l.assets>$assets_p50 *2 & growth_assets<-0.50 & ((f.growth_assets>1 & f.growth_assets!=.) |(f.growth_assets==. & f2.growth_assets>1 & f2.growth_assets!=.) )& growth_employees>-0.2 & growth_revenue>-0.2 & f.growth_employees<0.2 & f.growth_revenue<0.2 
replace assets=. if l.assets>$assets_p50 *2 & growth_assets<-0.50 & ((f.growth_assets>1 & f.growth_assets!=.) | (f.growth_assets==. & f2.growth_assets>1 & f2.growth_assets!=.) ) & growth_employees>-0.2 & growth_revenue>-0.2 & f.growth_employees<0.2 & f.growth_revenue<0.2  //41 obs
*idem employment
*browse bvdid year growth_assets lag2_assets lag1_assets assets  lead1_assets lead2_assets if l.assets>$assets_p75 *2 & growth_assets<-0.411 & ((f.growth_assets>0.70 & f.growth_assets!=.) |(f.growth_assets==. & f2.growth_assets>0.70 & f2.growth_assets!=.) )& growth_employees>-0.2 & growth_revenue>-0.2 & f.growth_employees<0.2 & f.growth_revenue<0.2 
replace assets=. if l.assets>$assets_p75 *2 & growth_assets<-0.411 & ((f.growth_assets>0.70 & f.growth_assets!=.) | (f.growth_assets==. & f2.growth_assets>0.70 & f2.growth_assets!=.) ) & growth_employees>-0.2 & growth_revenue>-0.2 & f.growth_employees<0.2 & f.growth_revenue<0.2  //49 obs

*REVENUE
*erase revenue peaks, starting at least at P75 (5Mio), more than quadruples, next more than divided by 4 (time series of 5 , 20 , 5 would be too suspicious)
*drop observation also if the spike is preceded and/or followed by a missing: time series 5,.,20,.,5 would be suspicious
*browse bvdid year growth_revenue lag2_revenue lag1_revenue revenue  lead1_revenue lead2_revenue if revenue > $revenue_p75 *4 & growth_revenue >3 & growth_revenue!=. & (f.growth_revenue<-0.75 | (f.growth_revenue==. & f2.growth_revenue<-0.75) ) 
replace revenue=. if revenue>$revenue_p75 *4 & growth_revenue>3 & growth_revenue!=. & (f.growth_revenue<-0.75 | (f.growth_revenue==. & f2.growth_revenue<-0.75)) //110 observations
* same for peaks starting at P50 (1M) but adding requirement that assets and revenue would not peak
*browse bvdid year growth_revenue lag2_revenue lag1_revenue revenue  lead1_revenue lead2_revenue if  revenue>$revenue_p50 *4 & growth_revenue>3 & growth_revenue!=. & (f.growth_revenue<-0.75 | (f.growth_revenue==. & f2.growth_revenue<-0.75) ) & growth_assets<0.2 & growth_employees<0.2 & f.growth_assets>-0.2 & f.growth_employees>-0.2
replace revenue=. if revenue>$revenue_p50 *4 & growth_revenue>3 & growth_revenue!=. & (f.growth_revenue<-0.75 | (f.growth_revenue==. & f2.growth_revenue<-0.75) ) & growth_assets<0.2 & growth_employees<0.2 & f.growth_assets>-0.2 & f.growth_employees>-0.2  // 10 obs 
* same for peaks starting at least at P75, but increase of 200% adding requirement that assets and revenue would not peak ( 5, 20, 5 while assets and empl do at most 100,120, 100)
*browse bvdid year growth_revenue lag2_revenue lag1_revenue revenue  lead1_revenue lead2_revenue if  revenue>$revenue_p75 *3 & growth_revenue>2 & growth_revenue!=. & (f.growth_revenue<-0.66 | (f.growth_revenue==. & f2.growth_revenue<-0.66) ) & growth_assets<0.2 & growth_employees<0.2 & f.growth_assets>-0.2 & f.growth_employees>-0.2
replace revenue=. if revenue>$revenue_p75 *3 & growth_revenue>2 & growth_revenue!=. & (f.growth_revenue<-0.66 | (f.growth_revenue==. & f2.growth_revenue<-0.66) ) & growth_assets<0.2 & growth_employees<0.2 & f.growth_assets>-0.2 & f.growth_employees>-0.2  // 5obs 
*Erase revenue downward peaks, for revenue starting at 4 times P75 (4*5M) decreasing by more than 75% and increasing by 300% the next year (timeseries 20 ;5;20 would seem suspicious)
*browse bvdid year growth_revenue lag2_revenue lag1_revenue revenue  lead1_revenue lead2_revenue if l.revenue>$revenue_p75 *4 & growth_revenue<-0.75 & ((f.growth_revenue>3 & f.growth_revenue!=.) | (f.growth_revenue==. & f2.growth_revenue>3 & f2.growth_revenue!=.) ) 
replace revenue=. if l.revenue>$revenue_p75 *4 & growth_revenue<-0.75 & ((f.growth_revenue>3 & f.growth_revenue!=.) | (f.growth_revenue==. & f2.growth_revenue>3 & f2.growth_revenue!=.) )  // 437 obs
*The same for downward peaks at P50 (1M) but adding requirement that assets and revenue would not peak
*browse bvdid year growth_revenue lag2_revenue lag1_revenue revenue  lead1_revenue lead2_revenue if l.revenue>$revenue_p50 *4 & growth_revenue<-0.75 & ((f.growth_revenue>3 & f.growth_revenue!=.) |(f.growth_revenue==. & f2.growth_revenue>3 & f2.growth_revenue!=.) )& growth_assets>-0.2 & growth_employees>-0.2 & f.growth_assets<0.2 & f.growth_employees<0.2
replace revenue=. if l.revenue>$revenue_p50 *4 & growth_revenue<-0.75 & ((f.growth_revenue>3 & f.growth_revenue!=.) |(f.growth_revenue==. & f2.growth_revenue>3 & f2.growth_revenue!=.) )& growth_assets>-0.2 & growth_employees>-0.2 & f.growth_assets<0.2 & f.growth_employees<0.2  // 57 obs
* same for downward peaks starting at least at P75, but decrease of 66% adding requirement that assets and revenue would not peak ( 20, 6.6, 20 while assets and revenue do at most 100,80, 100)
*browse bvdid year growth_revenue lag2_revenue lag1_revenue revenue  lead1_revenue lead2_revenue if l.revenue>$revenue_p75 *4 & growth_revenue<-0.66 & ((f.growth_revenue>2 & f.growth_revenue!=.) |(f.growth_revenue==. & f2.growth_revenue>2 & f2.growth_revenue!=.) )& growth_assets>-0.2 & growth_employees>-0.2 & f.growth_assets<0.2 & f.growth_employees<0.2 
replace revenue=. if l.revenue>$revenue_p75 *4 & growth_revenue<-0.66 & ((f.growth_revenue>2 & f.growth_revenue!=.) |(f.growth_revenue==. & f2.growth_revenue>2 & f2.growth_revenue!=.) )& growth_assets>-0.2 & growth_employees>-0.2 & f.growth_assets<0.2 & f.growth_employees<0.2  // 59 obs
  
drop growth* lag* lead*

save prematching_temp3, replace
*=================================================================================================================
******large drops or increases that do not exist in other variables
*=================================================================================================================
*I need to calculate growth rates again because I want to disregard the peaks that have been erased
use prematching_temp3, clear

foreach xxx in employees assets revenue {
gen growth_`xxx' = (`xxx'-l.`xxx')/l.`xxx'
replace growth_`xxx' = (`xxx'-l2.`xxx')/l2.`xxx' if l.`xxx'==.
}
*drop entire company if employment drops by 50% (jumps by 100%) while assets and revenue do diminish (increase) by less than 20% , 
*not in the same period, nor the preceding (if nonmissing), nor the following (if nonmissing)
*only applied for a drop in employees that start at 2* P75 (78 employees) or for a jump that exceeds p75 after the jump
gen emp_drop=1 if l.employees > $employees_p75 *2 & l.employees!=. & growth_employees<-0.5 & growth_assets>-0.20 & growth_assets!=. & l.growth_assets>-0.20 & f.growth_assets>-0.20 & growth_revenue>-0.20 & growth_revenue!=. & l.growth_revenue>-0.20  & f.growth_revenue>-0.20 & year>2002 & year<2013
replace emp_drop=1 if employees > $employees_p75 & growth_employees>1 & growth_employees!=. & growth_assets<0.20 & (l.growth_assets<0.20 | l.growth_assets==.) & (f.growth_assets<0.20 | f.growth_assets==.) & growth_revenue<0.20 &  (l.growth_revenue<0.20 | l.growth_revenue==.) & (f.growth_revenue<0.20 | f.growth_revenue==.) & year>2002 & year<2013 
*166 obs
*idem for drops by 75% (jumps by 300%) while assets and revenue decrease (increase) by less than 30%
replace emp_drop=1 if l.employees > $employees_p75 *4 & l.employees!=. & growth_employees<-0.75 & growth_assets>-0.30 & growth_assets!=. & l.growth_assets>-0.30 & f.growth_assets>-0.30 & growth_revenue>-0.30 & growth_revenue!=. & l.growth_revenue>-0.30  & f.growth_revenue>-0.30 & year>2002 & year<2013
*18 ob
replace emp_drop=1 if employees > $employees_p75 & growth_employees>3 & growth_employees!=. & growth_assets<0.30 & (l.growth_assets<0.30 | l.growth_assets==.) & (f.growth_assets<0.30 | f.growth_assets==.) & growth_revenue<0.30 &  (l.growth_revenue<0.30 | l.growth_revenue==.) & (f.growth_revenue<0.30 | f.growth_revenue==.) & year>2002 & year<2013 
*35obs
bys firm_id : egen emp_drop_max = max(emp_drop)
*browse if emp_drop_max==1 
drop if emp_drop_max==1 // 7120 obs, 445 companies
drop emp_*

*drop entire company if assets drops by 50% (jumps by 100%) while employees and revenue do diminish (increase) by less than 20% , 
*not in the same period, nor the preceding (if nonmissing), nor the following (if nonmissing)
*only applied for a drop in assets that start at 2* P75 (8.5M assets) or for a jump that exceeds p75 after the jump
gen ass_drop=1 if l.assets > $assets_p75 *2 & l.assets!=. & growth_assets<-0.5 & growth_employees>-0.20 & growth_employees!=. & l.growth_employees>-0.20 & f.growth_employees>-0.20 & growth_revenue>-0.20 & growth_revenue!=. & l.growth_revenue>-0.20  & f.growth_revenue>-0.20 & year>2002 & year<2013
*792
replace ass_drop=1 if assets > $assets_p75 & growth_assets>1 & growth_assets!=. & growth_employees<0.20 & (l.growth_employees<0.20 | l.growth_employees==.) & (f.growth_employees<0.20 | f.growth_employees==.) & growth_revenue<0.20 &  (l.growth_revenue<0.20 | l.growth_revenue==.) & (f.growth_revenue<0.20 | f.growth_revenue==.) & year>2002 & year<2013 
*2085 obs
*idem for drops by 75% (jumps by 300%) while assets and revenue decrease (increase) by less than 30%
replace ass_drop=1 if l.assets > $assets_p75 *4 & l.assets!=. & growth_assets<-0.75 & growth_employees>-0.30 & growth_employees!=. & l.growth_employees>-0.30 & f.growth_employees>-0.30 & growth_revenue>-0.30 & growth_revenue!=. & l.growth_revenue>-0.30  & f.growth_revenue>-0.30 & year>2002 & year<2013
*88obs
replace ass_drop=1 if assets > $assets_p75 & growth_assets>3 & growth_assets!=. & growth_employees<0.30 & (l.growth_employees<0.30 | l.growth_employees==.) & (f.growth_employees<0.30 | f.growth_employees==.) & growth_revenue<0.30 &  (l.growth_revenue<0.30 | l.growth_revenue==.) & (f.growth_revenue<0.30 | f.growth_revenue==.) & year>2002 & year<2013 
*377 obs
bys firm_id : egen ass_drop_max = max(ass_drop)
*browse if ass_drop_max==1 // 50480 obs, 3155 companies, 2% of database (within the highest quartile) Assets is much more reliable as a variable
drop if ass_drop_max==1
drop ass_* growth*

*drop entire company if revenue jumps by 200% while employees and revenue do increase by less than 20%? Impossible because revenue may have dropped in a crisis year and increase again while employment and assets are stable 

**Replace missing values to zero for  bankrupt companies. Companies are considered bankrupt from the year there is no more data. Companies that are bought by another companie continue to have their data (as a subsidiary) in orbis.
gen missingline=(employees==. |employees==0) & (assets==. | assets==0) & (revenue==. | revenue==0) & (toas==. | toas==0)
gen bankrupt=0
replace bankrupt=1 if  missingline==1 & f.missingline==1 & year==2014
foreach xxx in employees assets revenue toas{
forvalues t =2013(-1)2003{
*replace `xxx'=0 if  missingline==1 & f.missingline==1 & f.bankrupt==1 & year==`t' //bankrupt condition is needed to keep missings if these missings are followed by data 2 years later.
replace bankrupt=1 if  missingline==1 & f.missingline==1 & f.bankrupt==1 & year==`t' 
}
}
drop missingline 
*replace zeros of fixed assets to missing if toas is above median (>588.000 euro)
sum toas, detail
replace assets=. if assets/toas==0 & toas > r(p50) //9849 zeros set to missing
* if employees>30 and assets=0 and rev=0 => not clear if employees is wrong or assets and rev are wrong. => better make a visual inspection on merged sample.
* if revenue >4mio (p_75) and employees==0 and assets==0 => not clear if revenue is wrong or employees is wrong.
gen ass_rev_zero= assets==0 & revenue==0 & employees>$employees_p75 & employees!=.
bys firm_id: egen max_ass_rev_zero = max(ass_rev_zero)
*browse if max_ass_rev_zero==1 
drop *ass_rev_zero

drop if year <2002 | year>2012
**explore data (deviation around the mean will not be used as a criteria to drop firms because it can be high for firms with a strong trend)
** there are still problematic data but difficult too eliminate without eliminating all firms that went bankrupt
foreach xxx in employees assets revenue {
bys bvdid : egen `xxx'_mean=mean(`xxx') if year>2001 & year<2013
gen `xxx'_dev_mean=`xxx'/`xxx'_mean if year>2001 & year<2013
bysort firm_id : egen `xxx'_dev_mean_max=max(`xxx'_dev_mean) if year>2001 & year<2013
*browse if `xxx'_dev_mean_max > 3 & `xxx'_dev_mean_max!=. & `xxx'_mean>$`xxx'_p75 & year>2001 & year<2013
drop `xxx'_*
}
reshape wide revenue employees toas assets ebit ebt bankrupt, i(firm_id) j(year)
mmerge bvdid using prematching_dataset_nace_ctry_ETS, unmatched(master)
order bvd firm country_code nace4dig nace3dig ETS
drop _m
save prematching_temp4, replace

*=================================================================================================================
* PRE and POST AVERAGES, LOGs, RENAME VARIABLES
*=================================================================================================================
use prematching_temp4, clear
** PRE-ETS; POST-ETS and Pre-and post averages
foreach xxx in revenue employees assets toas ebit ebt {
forval j = 2002/2004{
ren `xxx'`j'   pre_`xxx'`j'
}  
forval j = 2005/2012{
ren `xxx'`j'   post_`xxx'`j'
}
egen m_`xxx'_preETS=rowmean(pre_`xxx'*)
egen m_`xxx'_postETS=rowmean(post_`xxx'*)
}
* LOG
foreach j of varlist m_*{
   gen double ln_`j' = ln(`j')
}
ren ln_m_revenue_postETS lrevpost
ren ln_m_revenue_preETS lrevpre
ren ln_m_assets_preETS lasspre
ren ln_m_assets_postETS lasspost
ren ln_m_employees_preETS lemppre
ren ln_m_employees_postETS lemppost
ren ln_m_toas_preETS ltoaspre
ren ln_m_toas_postETS ltoaspost
drop ln_m_ebit_preETS ln_m_ebt_preETS ln_m_ebit_postETS ln_m_ebt_postETS
*no logs for profits because losses are negative
ren m_revenue_postETS revpost
ren m_revenue_preETS revpre
ren m_assets_preETS asspre
ren m_assets_postETS asspost
ren m_employees_preETS emppre
ren m_employees_postETS emppost
ren m_ebit_preETS ebitpre
ren m_ebit_postETS ebitpost
ren m_ebt_preETS ebtpre
ren m_ebt_postETS ebtpost
ren m_toas_preETS toaspre
ren m_toas_postETS toaspost

* DROP FIRMS WITH ALL ZEROS
drop if lrevpre==.  | lasspre==. | lemppre==. | (lrevpost==.  & lasspost==. & lemppost==.)  // obs dropped, because neg value for revenue, employment or assets
tab ETS
* 156377 firms
* 2765 (instead of 3057 ETS firms without cleaning.)
*================================================
* DROP SECTORS*COUNTRIES WITH LESS THAN 1 ETS FIRM and 1 non-ETS FIRMS 
*================================================
gen nonETS=ETS==0
gen nace2dig=int(nace3dig/10)
bysort country_c nace2dig: egen seccouETSfirms = sum(ETS) //I changed initial nace3dig to nace2dig to be able to match on 2 dig sectors
bysort country_c nace2dig: egen seccouNonETSfirms = sum(nonETS)
drop if seccouETSfirms<1 
drop if seccouNonETSfirms<1 
tab ETS // 122699 firms, among which 2737 ETS firms 
drop  sec* nonETS
encode country, gen(country_n)
*Define SME's
gen Small=emppre<50 & (revpre<10000 | asspre<10000)
gen Medium=emppre<250 & (revpre<50000 | asspre<43000) & Small==0
*Define sectors
gen sector=1 if nace2==17 
replace sector=2  if nace2==20
replace sector=3  if nace3==231
replace sector=4  if nace3==232 | nace3==233 | nace3==234
replace sector=5  if nace3==235
replace sector=6  if nace2==24
replace sector=7  if nace3==351
replace sector=8  if sector==.
label define sectornames 1 "Paper" 2 "Chemicals" 3 "Glass" 4 "Ceramics" 5 "Cement&Lime" 6 "Basic Metals" 7 "Electricity" 8 "Other Sectors"
label values sector sectornames
*Define East-West Europe
gen east=country_code=="BG" | country_code=="CZ" | country_code=="CY" | country_code=="EE" | country_code=="HU" | country_code=="LT" | country_code=="LV" | country_code=="PL" | country_code=="RO" | country_code=="SK" | country_code=="SI" 
* West is AT BE DE DK ES FI FR GB GR IE IS IT LI LU NL NO PT SE

save prematching_temp5, replace

import excel ETS_Subsidiaries.xlsx, sheet("Feuil1") firstrow clear
//branches are sections within the same company (BranchBvDIDnumber does not containt the bvdid number of the company with extra added numbers)
//non of the ETS firms has data for headquarter, so no need to check for this
generate bvdid=regexr(ID,"[A-Z]+$","") //erase last capital letter at the end
generate OutsideEurope=1
foreach xxx in AT BE BG CY CZ DE DK EE ES FI FR GB GR HU IE IS IT LI LT LU LV NL NO PL PT RO SE SI SK{
replace OutsideEurope=0 if regexm(SubsidiaryBvDIDnumber,"`xxx'")==1
}
generate IncorrectBvDID=regexm(SubsidiaryBvDIDnumber,"\*") 
replace IncorrectBvDID=1 if regexm(SubsidiaryBvDIDnumber,"\-")==1 
drop if IncorrectBvDID==1 | OutsideEurope==1 
keep bvdid SubsidiaryBvDIDnumber
save ETS_Subsidiaries, replace 

import excel ETS_Subsidiaries_of_subsidiaries.xls, sheet("Results") firstrow clear
rename BvDIDnumber bvdid
generate OutsideEurope=1
foreach xxx in AT BE BG CY CZ DE DK EE ES FI FR GB GR HU IE IS IT LI LT LU LV NL NO PL PT RO SE SI SK{
replace OutsideEurope=0 if regexm(SubsidiaryBvDIDnumber,"`xxx'")==1
}
generate IncorrectBvDID=regexm(SubsidiaryBvDIDnumber,"\*") 
replace IncorrectBvDID=1 if regexm(SubsidiaryBvDIDnumber,"\-")==1 
drop if IncorrectBvDID==1 | OutsideEurope==1 
keep bvdid SubsidiaryBvDIDnumber
save ETS_Subsidiaries_of_subsidiaries, replace

import excel ETS_Shareholders.xls, sheet("AllShareholdersWithoutDuplicate") firstrow clear //allshareholders contains all unique bvdids of 4 variables in ORBIS : GUO DUO Direct Shareholders, Controlling Shareholders
generate OutsideEurope=1
foreach xxx in AT BE BG CY CZ DE DK EE ES FI FR GB GR HU IE IS IT LI LT LU LV NL NO PL PT RO SE SI SK{
replace OutsideEurope=0 if regexm(ShareholderBvDIDnumber,"`xxx'")==1
}
generate IncorrectBvDID=regexm(ShareholderBvDIDnumber,"\*") 
replace IncorrectBvDID=1 if regexm(ShareholderBvDIDnumber,"\-")==1 
drop if IncorrectBvDID==1 | OutsideEurope==1 
keep ShareholderBvDIDnumber
save ETS_Shareholders, replace

import excel ETS_Sisters.xls, sheet("Results") firstrow clear 
generate OutsideEurope=1
foreach xxx in AT BE BG CY CZ DE DK EE ES FI FR GB GR HU IE IS IT LI LT LU LV NL NO PL PT RO SE SI SK{
replace OutsideEurope=0 if regexm(SubsidiaryBvDIDnumber,"`xxx'")==1
}
generate IncorrectBvDID=regexm(SubsidiaryBvDIDnumber,"\*") 
replace IncorrectBvDID=1 if regexm(SubsidiaryBvDIDnumber,"\-")==1 
drop if IncorrectBvDID==1 | OutsideEurope==1 
keep SubsidiaryBvDIDnumber
rename SubsidiaryBvDIDnumber SisterBvDIDnumber
save ETS_Sisters, replace

*add variables ETSsubsidiary ETSshareholder ETSsister (this block can be left out if I find a way to 
use prematching_temp5, clear
local Nfinal=_N
append using ETS_Subsidiaries
append using ETS_Subsidiaries_of_subsidiaries
append using ETS_Shareholders
append using ETS_Sisters
local NinclSubs=_N
gen ETSsubsidiary=0
gen ETSshareholder=0
gen ETSsister=0
forvalues i = `Nfinal' / `NinclSubs' { //_N can only be used in expressions. use c(N) instead
quietly replace ETSsubsidiary=1 if bvdid== SubsidiaryBvDIDnumber[`i']
quietly replace ETSshareholder=1 if bvdid== ShareholderBvDIDnumber[`i'] 
quietly replace ETSsister=1 if bvdid==SisterBvDIDnumber[`i']
}
tab ETSsubsidiary, missing
replace ETS=. if ETSsubsidiary==1 & ETS==0 //1678 subsidiaries detected.
replace ETS=. if ETSshareholder==1 & ETS==0 //152 shareholder companies
replace ETS=. if  ETSsister==1 & ETSsubsidiary==0 & ETS==0 //833 ETS sister companies
drop if _n >`Nfinal'
save prematching_temp6, replace

*calculate ETS_GroupWeight to use as weights in regressions
use  prematching_clean, replace
global Nfinal=_N
append using ETS_Subsidiaries
append using ETS_Subsidiaries_of_subsidiaries
append using ETS_Shareholders
append using ETS_Sisters
gen drop= _n >$Nfinal
*a companies that is twice sister should have a contribution of 0.5 in ETSgroupsize of 2 companies
gen RelatedBvDIDnumber=SubsidiaryBvDIDnumber+ShareholderBvDIDnumber+SisterBvDIDnumber
egen Related_id=group(RelatedBvDID)
bys Related_id : egen repeated=count(Related_id)
gen weight=1/repeated
egen firm_id2=group(bvdid)
bys firm_id2 : egen ETS_GroupSize=total(weight)
/*
forvalues i = `Nfinal' / `NinclSubs' { //_N can only be used in expressions. use c(N) instead
quietly replace ETS_GroupSize=ETS_GroupSize[`i'] if bvdid== RelatedBvDIDnumber[`i']
display `i'
}
*/
replace ETS_GroupSize=ETS_GroupSize + 1 if ETS_GroupSize!=0
drop if ETS_GroupSize>29075 //one company has 29075 subsidiaries
gen ETS_GroupWeight=1/ETS_GroupSize
replace ETS_GroupWeight=0 if ETS_GroupWeight==.
global NinclSubs=_N
forvalues i = $Nfinal / $NinclSubs { //_N can only be used in expressions. use c(N) instead
quietly replace ETS_GroupWeight=ETS_GroupWeight+ ETS_GroupWeight[`i'] if bvdid== RelatedBvDIDnumber[`i']
display `i'
}
replace ETS=. if ETS_GroupWeight!=0 & ETS==0 //only 5 firms
drop if drop==1
drop  drop *BvDIDnumber  Related_id repeated weight firm_id2
save prematching_clean, replace
