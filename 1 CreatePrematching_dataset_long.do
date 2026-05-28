* Do file for OECD paper on ETS & competitiveness
* NACE codes
import delimited using e:\orbis_data\historical\Europe\bvdid_nace.txt, varn(1) clear stringcols(_all)   
keep bvdidnumber countryisocode nacerev2corecode
gen nace3dig = substr(nacerev2corecode,1,3)
replace bvdid=trim(bvdid)
compress
save e:\orbis_data\historical\Europe\bvdid_nace, replace
* List of ETS BVDIDs
import excel using ETS_competitiveness/data/CITL_BVDID_finalchecks_newrev.xlsx, first  clear    
keep bvdidNEW
duplicates drop
ren bvdidNEW bvdid
gen byte ETS = 1
save ETS_competitiveness/data/ETS_companies_BVDID_list, replace
* Add NACE codes
use ETS_competitiveness/data/ETS_companies_BVDID_list, clear
drop if bvd==""
replace bvdid=trim(bvdid)
mmerge bvdid using ETS_competitiveness/stata/ETS_companies_BVDID_country_NACE, umatch(bvdidnumber) unmatched(master)
mmerge bvdid using e:\orbis_data\historical\Europe\bvdid_nace, umatch(bvdidnumber) unmatched(master)
replace nace = nacerev if nacerev2!=""
replace country=countryiso if country=="" & countryiso!=""
replace country=substr(bvd,1,2) if country=="" 
keep bvdid ETS nace country
ren nace nace4dig
gen nace3dig = substr(nace4dig,1,3)
save ETS_competitiveness/data/ETS_companies_BVDID_NACE, replace
* Combination of country X ETS sectors
use ETS_competitiveness/data/ETS_companies_BVDID_NACE, clear
keep  country nace3dig
duplicates drop
drop if nace==""
save ETS_competitiveness/data/ETS_companies_NACE_country_combinations, replace
* Pre-matching datasets 1 - add NACE codes and keep only firms in 3-digit sectors having at least one ETS-regulated firm
/*HR*/ 
/*MT*/ 
foreach xxx in AT BE BG CY CZ DE DK EE ES FI FR GB GR HU IE IS IT LI LT LU LV NL NO PL PT RO SE SI SK{
	use e:\orbis_data\historical\Europe\Financials_F_`xxx', clear
	ren fiscal_year year
	keep if year>1999 
	ren countryiso country_code
	keep bvdid year country_code gros fias tfas toas empl opre turn oppl plbt  
	mmerge bvdid using e:\orbis_data\historical\Europe\bvdid_nace, umatch(bvdidnumber) unmatched(none) ukeep(nace3dig nacerev2corecode)
	mmerge country_code nace3dig using ETS_competitiveness/data/ETS_companies_NACE_country_combinations, umatch(country nace3dig) unmatched(none)
	mmerge bvdid using ETS_competitiveness/data/ETS_companies_BVDID_list, unmatched(master)
	replace ETS=0 if ETS==.
	ren nacerev2corecode nace4dig
	keep bvdid year country_code ETS nace4dig nace3dig fias tfas toas empl opre turn gros oppl plbt  
	order bvdid year country_code ETS nace4dig nace3dig fias tfas toas empl opre turn gros oppl plbt  
	sort bvdid year
	compress
	save "E:\ETS_competitiveness\prematching\allfirms_ETS_sectors_`xxx'.dta", replace
	}
* Final file having all countries
use "E:\ETS_competitiveness\prematching\allfirms_ETS_sectors_AT.dta", clear
foreach xxx in BE BG CY CZ DE DK EE ES FI FR GB GR HU IE IS IT LI LT LU LV NL NO PL PT RO SE SI SK{
	append using "E:\ETS_competitiveness\prematching\allfirms_ETS_sectors_`xxx'.dta"
}
sort bvdid year
compress
save ETS_competitiveness/data/prematching_dataset_long, replace
use ETS_competitiveness/data/prematching_dataset_long, clear
saveold ETS_competitiveness/data/prematching_dataset_long_stata13, replace
********************************************************************************************************************************************
* descriptives
*  # of ETS firms
unique bvdid if ETS==1
* total # of obs in the dataset
count
* # of missing values in the whole dataset
nmissing fias tfas toas empl opre turn oppl plbt gros
* # of obs for ETS firms
count if ETS==1
* # of missing values for ETS firms
nmissing fias tfas toas empl opre turn oppl plbt gros if ETS==1
* # of obs in 2004
count if year==2004
*=================================================================================================================
