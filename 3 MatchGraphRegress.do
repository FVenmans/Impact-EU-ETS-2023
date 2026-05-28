*-----------------------------------------------------------------------------------------------------
*Matching and create variable with ID of matched firms
*-----------------------------------------------------------------------------------------------------
*!!!!!!!!!!!!!!!!!!There are basically 4 parameters to be chosen on lines with exclamation marks: !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
*1) work only with nonbankrupt firms in 2012 (line 11) or set variable to missing if matched variable is missing=Pairwisemissing (line 55)
*2)set maxdistance for revenue, employment and assets (and for ebit which is now not imposed) (line 108) 
*3) pairwise truncation (line111) 
*4) include/exclude ebit and set nace2 or E in mathcing command (line 14-15) 

*5) include sisters and related (line15) and change [fweight=weight] to [iweight=ETS_GroupWeight] (this will not correct for ties), and add [iweight=ETS_GroupWeight] in commands collapse for graphs
cd "C:\Users\530443\Google Drive\Research projects\Competitiveness\LastResults" //computer Frank 
*cd "ETS_competitiveness/data/"  //computer antoine
set more off
use "C:\Users\530443\Google Drive\Research projects\Competitiveness\prematching_clean", clear
*drop if bankrupt2012==1 //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
replace ETS=1 if ETS==.  //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
**we match only to obtain the variable matchedc
*ebit has more meaning than ebt, because it is a measure of profit, independent of capital structure and it is the numerator of Return on Assets.
teffects nnmatch (lrevpost lrevpre lemppre lasspre ebitpre) (ETS), atet ematch(nace3dig country_n) biasadj(lrevpre lemppre lasspre) generate(matchedc) vce(iid) osample(calsample) 
teffects nnmatch (lrevpost lrevpre lemppre lasspre ebitpre) (ETS) if calsample==0, atet ematch(nace3dig country_n) biasadj(lrevpre lemppre lasspre) generate(matchedc) vce(iid) osample(calsample2)
count if matchedc1!=. //2808 ETS firms matchedc2 has only 1 observation (tie), I don't use it.
*variable matchedc is only reported for the ETS firms, missing for the matched nonETS firms. It contains the obs number not the id of the control firm 

*create variable matched_id for control firms containting the id of the treated firms 
gen matched_id=.
qui levelsof firm_id if matchedc1!=., local(ETSmatched_id) //ETSmatched_id contains firm_id of ETS firms
foreach i of local ETSmatched_id {
qui summarize matchedc1 if firm_id==`i' , meanonly //observe line number of the nonETSfirm that is matched to the i'th ETS firm
qui expand 2 if matched_id!=. & _n== `r(mean)' //create an extra line if the non-ETS firm has already a matched ETS firm (some non-ETS firms serve multiple times as a match)
qui replace matched_id=`i' if _n== `r(mean)'
}
*add for ETS firms the id of control firm to the variable matched_id
qui levelsof matchedc1 if matchedc1!=., local(nonETSmatched_n)
foreach i of local nonETSmatched_n {
qui summarize firm_id if _n==`i', meanonly
qui replace matched_id=`r(mean)' if matchedc1==`i' 
}

gen matched=matched_id!=. //matched =1 if firm is part of matched sample.

drop if matched==0
drop country_n calsample matchedc* matched

save matched_wide, replace
*------------------------------------------------------------------------------------------
** make dataset wide with 1 line per company and dataset and QQplots
*------------------------------------------------------------------------------------------
use matched_wide, clear
drop if ETS==0
rename * *_t
gen pair_id= firm_id_t
save matched_ETSonly, replace
use matched_wide, clear
drop if ETS==1
rename * *_c
gen pair_id= matched_id_c
save matched_nonETSonly, replace
mmerge pair_id using matched_ETSonly , type(n:1)
drop _merge
*change here if missing is interpreted as bankrupt!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
*set variable to missing if matched variable is missing=Pairwisemissing
foreach xxx in revenue assets employees ebit ebt{
forvalues y=2005/2012{
replace post_`xxx'`y'_c=. if post_`xxx'`y'_t==.
replace post_`xxx'`y'_t=. if post_`xxx'`y'_c==.
}
}
replace ETS_GroupWeight_c=ETS_GroupWeight_t 
**generate distances and maximum values of treated/control (in order to set max pre value in regressions)
*maximum distance on ebit: if in log, if one has ebit 1euro and the other ebit 10.000 euros the difference is huge and meaningless. If expressed in abs value very much dependent on size.
*option would be to compare ROA
gen ROApre_t=ebitpre_t/asspre_t
gen ROApre_c=ebitpre_c/asspre_c
gen maxdist_ROA : "abs difference with treated/control"=abs(ROApre_t - ROApre_c)
egen max_ROApre=rowmax(ROApre_t - ROApre_c)
label variable max_ROApre "highest of treated and nontreated ROA"
foreach xxx in rev ass emp{  
gen dist_l`xxx'pre_t : "difference with treated/control" =l`xxx'pre_t-l`xxx'pre_c 
gen dist_l`xxx'pre_c : "difference with treated/control" =l`xxx'pre_c-l`xxx'pre_t
gen abs_dist_`xxx'=abs(dist_l`xxx'pre_t)
egen max_l`xxx'pre=rowmax(l`xxx'pre_t l`xxx'pre_c)
label variable max_l`xxx'pre "highest of treated and nontreated `xxx'" 
*QQplots
foreach j in 0.5 0.85 1 {
display `j'
qqplot l`xxx'pre_t l`xxx'pre_c if abs(lrevpre_t-lrevpre_c)<`j' & abs(lasspre_t-lasspre_c)<`j' & abs(lemppre_t-lemppre_c)<`j', title(`xxx' "maxdistance" `j')
graph export qqplot_l`xxx'pre_maxdist`j'.png, as(png) replace
sum `xxx'pre_t `xxx'pre_c if abs(lrevpre_t-lrevpre_c)<`j' & abs(lasspre_t-lasspre_c)<`j' & abs(lemppre_t-lemppre_c)<`j'
}
}
qqplot ROApre_t ROApre_c if abs(lrevpre_t-lrevpre_c)<0.85 & abs(lasspre_t-lasspre_c)<0.85 & abs(lemppre_t-lemppre_c)<0.85
graph export qqplotROApre_maxdist1.png, as(png) replace
egen maxdist=rowmax(abs_dist_rev abs_dist_ass abs_dist_emp)
label variable maxdist "max abs diff between t/c for lrevpre lemppre lasspre" 
drop abs_*
save matched_OnePairPerLine, replace
**Generage wide file with one company per line
drop *_c
rename *_t *
save matched_ETSonly_dist, replace
use matched_OnePairPerLine, clear
drop *_t
rename *_c *
save matched_nonETSonly_dist, replace
append using matched_ETSonly_dist
save matched_wide_dist, replace
*qqplots can be obtained from wide database using qqplot3 lrevpre if dist... , by (ETS)

*---------------------------------------------------------------------------------------------------------
****Set the maximum distance, maximum size and create long database
*----------------------------------------------------------------------------------------------------------
*(impossible in long format because some nonETS firms are matched to several ETS firms)
use matched_wide_dist, clear
global distance=85 //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
drop if maxdist> $distance /100 //884 obs dropped if maxdist=1.5
*drop if maxdist_ROA>0.05 //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
global truncate=99 //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
*Truncation is done per pair (variable max_l`xxx'pre contains maximum of treated and control).
foreach xxx in rev ass emp {
sum max_l`xxx'pre, detail
drop if max_l`xxx'pre>r(p$truncate)
}

drop *pre *post //also drops distances
rename pre_* *
rename post_* *
**eliminate duplicates of nonETS firms
bys firm_id : egen weight=count(matched_id) 
drop matched_id maxdist pair_id //because not uniquely defined for non-ETS firms!
duplicates report firm_id //only 4315 unique firm_id's whereas at the start, sum of ETS and non ETS is 2808+1959=4767 (check numbers of matched non ETS firms)
duplicates drop firm_id , force
reshape long revenue employees assets toas ebit ebt bankrupt, i(bvdid) j(year)
label variable year "Year"
* Check quality of data
foreach xxx in employees revenue assets { 
bys bvdid : egen `xxx'_mean=mean(`xxx') if bankrupt==0
gen `xxx'_dev_mean=`xxx'/`xxx'_mean 
bysort firm_id : egen `xxx'_dev_mean_max=max(`xxx'_dev_mean) 
sum `xxx', detail
local `xxx'_p50 = r(p50)
}
browse ETS year employees assets toas revenue ebit ebt employees_dev_mean_max assets_dev_mean_max revenue_dev_mean_max if (employees_dev_mean_max > 3 & employees_dev_mean_max!=. & employees_mean > `employees_p50') |(revenue_dev_mean_max > 3 & revenue_dev_mean_max!=. & revenue_mean > `revenue_p50') | (assets_dev_mean_max > 3 & assets_dev_mean_max!=. & assets_mean > `assets_p50')
foreach xxx in revenue employees assets {
gen missing`xxx'=`xxx'==. if year>2004
bysort firm_id: egen allmissing`xxx'=min(missing`xxx') 
}
drop if allmissingrevenue==1 | allmissingemployees==1 | allmissingassets==1
gen ass_per_emp=assets/employees
gen low_ass_per_emp=1 if ass_per_emp<4
bysort firm_id : egen max_low_asset=max(low_ass_per_emp)
br if max_low_asset==1

drop *_dev_mean*
foreach xxx in revenue assets employees {
gen log_`xxx'=log(`xxx')
replace log_`xxx'=0 if `xxx' <=0 //29 companyyears have zero employees, 13 companyyears have neg revenue (min is 85000euro, very close to 1euro) 
}
save matched_long_dist${distance}_trunc${truncate}, replace
*---------------------------------------------------------------------------------------------------------
*Graph Time series 
*---------------------------------------------------------------------------------------------------------
use matched_long_dist${distance}_trunc${truncate}, clear
collapse assets employees revenue ebit ebt log_assets log_employees log_revenue  [iweight=ETS_GroupWeight], by (year ETS)
sort year
foreach xxx in revenue log_revenue assets log_assets employees log_employees ebit ebt{
line `xxx' year if ETS==1 || line `xxx' year if ETS==0, legend(label(1 "ETS") label(2 "Non-ETS")) title("Evolution `xxx'") note("Maximum distance ${distance}. Truncated at p${truncate}. ")
graph export  Evolution_`xxx'_dist${distance}_trunc${truncate}.png, as(png) replace
}
*Graph for Small Medium and Large companies according to European Commission definition
use matched_long_dist${distance}_trunc${truncate}, clear
collapse assets employees revenue ebit ebt log_assets log_employees log_revenue [iweight=ETS_GroupWeight], by (year ETS Small Medium)
sort year
foreach xxx in revenue log_revenue assets log_assets employees log_employees ebit ebt{
line `xxx' year if ETS==1 & Small==1, lpattern(l) lcolor(navy)         || line `xxx' year if ETS==0 & Small==1, lpattern(-) lcolor(navy)          || ///
line `xxx' year if ETS==1 & Medium==1, lpattern(l) lcolor(maroon)      || line `xxx' year if ETS==0 & Medium==1, lpattern(-) lcolor(maroon)       || ///
line `xxx' year if ETS==1 & Small==0 & Medium==0, lpattern(l) lcolor(forest_green)|| line `xxx' year if ETS==0 & Small==0 & Medium==0, lpattern(-) lcolor(forest_green)|| ///
, legend(label(1 "ETS Small") label(2 "Non-ETS Small") label(3 "ETS Medium") label(4 "Non-ETS Medium") label(5 "ETS Large") label(6 "Non-ETS Large") ) title("Evolution `xxx' by company size") note("Maximum distance ${distance}. Truncated at p${truncate}. ")
graph export  Evolution_SME_`xxx'_dist${distance}_trunc${truncate}.png, as(png) replace
}
*Graph for East-West Europe
use matched_long_dist${distance}_trunc${truncate}, clear
collapse assets employees revenue ebit ebt log_assets log_employees log_revenue [iweight=ETS_GroupWeight], by (year ETS east)
sort year
foreach xxx in revenue log_revenue assets log_assets employees log_employees ebit ebt{
line `xxx' year if ETS==1 & east==1, lpattern(l) lcolor(navy)        || line `xxx' year if ETS==0 & east==1, lpattern(-) lcolor(navy)        || ///
line `xxx' year if ETS==1 & east==0, lpattern(l) lcolor(maroon)      || line `xxx' year if ETS==0 & east==0, lpattern(-) lcolor(maroon)      || ///
, legend(label(1 "ETS Eastern Europe") label(2 "Non-ETS Eastern Europe") label(3 "ETS Western Europe") label(4 "Non-ETS Western Europe") ) title("Evolution `xxx' by Region") note("Maximum distance ${distance}. Truncated at p${truncate}. ")
graph export  Evolution_Region_`xxx'_dist${distance}_trunc${truncate}.png, as(png) replace
}
*Graph by sector
use matched_long_dist${distance}_trunc${truncate}, clear
collapse assets employees revenue ebit ebt log_assets log_employees log_revenue [iweight=ETS_GroupWeight], by (year ETS sector)
sort year
foreach xxx in revenue log_revenue assets log_assets employees log_employees ebit ebt{
line `xxx' year if ETS==1 & sector==1, lpattern(l) lcolor(navy)        || line `xxx' year if ETS==0 & sector==1, lpattern(-) lcolor(navy)        || ///
line `xxx' year if ETS==1 & sector==2, lpattern(l) lcolor(maroon)      || line `xxx' year if ETS==0 & sector==2, lpattern(-) lcolor(maroon)      || ///
line `xxx' year if ETS==1 & sector==3, lpattern(l) lcolor(forest_green)|| line `xxx' year if ETS==0 & sector==3, lpattern(-) lcolor(forest_green)|| ///
line `xxx' year if ETS==1 & sector==4, lpattern(l) lcolor(dkorange)    || line `xxx' year if ETS==0 & sector==4, lpattern(-) lcolor(dkorange)    || ///
, xline (2004.5) legend(label(1 "ETS Paper") label(2 "Non-ETS Paper") label(3 "ETS Chemicals") label(4 "Non-ETS Chemicals") label(5 "ETS Glass") label(6 "Non-ETS Glass") label(7 "ETS Ceramics") label(8 "Non-ETS Ceramics") ) title("Evolution `xxx' by sector") note("Maximum distance ${distance}. Truncated at p${truncate}. ")
graph export  Evolution_sector1_`xxx'_dist${distance}_trunc${truncate}.png, as(png) replace
}
foreach xxx in revenue log_revenue assets log_assets employees log_employees ebit ebt{
line `xxx' year if ETS==1 & sector==5, lpattern(l) lcolor(navy)        || line `xxx' year if ETS==0 & sector==5, lpattern(-) lcolor(navy)        || ///
line `xxx' year if ETS==1 & sector==6, lpattern(l) lcolor(maroon)      || line `xxx' year if ETS==0 & sector==6, lpattern(-) lcolor(maroon)      || ///
line `xxx' year if ETS==1 & sector==7, lpattern(l) lcolor(forest_green)|| line `xxx' year if ETS==0 & sector==7, lpattern(-) lcolor(forest_green)|| ///
line `xxx' year if ETS==1 & sector==8, lpattern(l) lcolor(dkorange)    || line `xxx' year if ETS==0 & sector==8, lpattern(-) lcolor(dkorange)    || ///
, xline (2004.5) legend( label(1 "ETS Cement") label(2 "Non-ETS Cement") label(3 "ETS Basic Metals") label(4 "Non-ETS Basic Metals") label(5 "ETS Electricity") label(6 "Non-ETS Electricity") label(7 "ETS Other Sectors") label(8 "Non-ETS Other Sectors")  ) title("Evolution `xxx' by sector") note("Maximum distance ${distance}. Truncated at p${truncate}.")
graph export  Evolution_sector2_`xxx'_dist${distance}_trunc${truncate}.png, as(png) replace
}
*Code without collapse:  bysort year : egen mean_ETS_employees= mean(employees) if ETS==1 => y year : egen mean_nonETS_employees= mean(employees) if ETS!=1 => line mean_ETS_employees mean_nonETS_employees year  => graph export EvolutionEmployeesAbsoluteNumbers.png, as(png) replace
*-----------------------------------------------------------------------------------------------------------
*** REGRESSIONS
*-----------------------------------------------------------------------------------------------------------
use matched_long_dist${distance}_trunc${truncate}, clear
gen post=year>2004
gen ETSpost=ETS*post
egen NACE3=group(nace3dig)

foreach xxx in revenue log_revenue assets log_assets employees log_employees ebit ebt {
reg `xxx' ETS post ETSpost  [iweight=ETS_GroupWeight], cluster(firm_id)
outreg2 using  `xxx'_dist${distance}_trunc${truncate}, word title(`xxx') keep(ETSpost post ETS) ctitle(OLS) addnote(Maximum distance $distance % Truncated at $truncate %) replace
reg `xxx' ETS post ETSpost i.NACE3 [iweight=ETS_GroupWeight], cluster(firm_id)
outreg2 using  `xxx'_dist${distance}_trunc${truncate}, word title(`xxx') keep(ETSpost post ETS) ctitle(SectorDummies)
reg `xxx' ETS ETSpost i.NACE3 i.year [iweight=ETS_GroupWeight], cluster(firm_id)
outreg2 using  `xxx'_dist${distance}_trunc${truncate}, word title(`xxx') keep(ETSpost ETS) ctitle(SectorYearDummies)
xtreg `xxx' post ETSpost [iweight=ETS_GroupWeight], fe //ETS omitted because perfect collinearity with fe
outreg2 using  `xxx'_dist${distance}_trunc${truncate}, word title(`xxx') keep(ETSpost post) ctitle(FE)
xtreg `xxx' ETSpost i.year [iweight=ETS_GroupWeight], fe //ETS omitted because perfect collinearity with fe
outreg2 using  `xxx'_dist${distance}_trunc${truncate}, word title(`xxx') keep(ETSpost) ctitle(2wayFE)
xtreg `xxx' ETS post ETSpost, re 
outreg2 using  `xxx'_dist${distance}_trunc${truncate}, word title(`xxx') keep(ETSpost post ETS) ctitle(RE)  
} 
* Regressions with biasadjustment have a problem: the explainatory variables are affected by the treatment.Imagine that revenue would be a fixed proportion of assets: any effect of ETS on both revenue and assets would leave coeficient ETSpost=zero  (as long as the ETS does not affect the proportion between revenue and assets)

foreach xxx in revenue log_revenue assets log_assets employees log_employees ebit ebt {
reg `xxx' ETS post ETSpost  [iweight=ETS_GroupWeight], cluster(firm_id)
outreg2 using  Overview_OLS_dist${distance}_trunc${truncate}, word title(Regressions Overview) keep(ETSpost post ETS) ctitle(`xxx') addnote(Maximum distance $distance % Truncated at $truncate % Standard errors clustered by firm.)
}
foreach xxx in revenue log_revenue assets log_assets employees log_employees ebit ebt {
reg `xxx' i.sector#c.ETSpost i.sector#c.post i.sector#c.ETS i.sector  [iweight=ETS_GroupWeight], cluster(firm_id)
outreg2 using  Sectors_OLS_dist${distance}_trunc${truncate}, word title(Regressions per sector) ctitle(`xxx'OLS) addnote(1=Paper 2=Chemicals 3=Glass 4=Ceramics 5=Cement&Lime 6= Basic Metals 7=Electricity 8=Other Sectors Maximum distance $distance % Truncated at $truncate % Standard errors clustered by firm.)
outreg2 using  Sectors_OLS_FE_dist${distance}_trunc${truncate}, word title(Regressions per sector) ctitle(`xxx'OLS) addnote(1=Paper 2=Chemicals 3=Glass 4=Ceramics 5=Cement&Lime 6= Basic Metals 7=Electricity 8=Other Sectors Maximum distance $distance % Truncated at $truncate % Standard errors clustered by firm.)
xtreg `xxx'  i.sector#c.ETSpost i.sector#c.post [iweight=ETS_GroupWeight],fe vce(robust)
outreg2 using  Sectors_OLS_FE_dist${distance}_trunc${truncate}, word title(Regressions per sector) ctitle(`xxx'FE) addnote(1=Paper 2=Chemicals 3=Glass 4=Ceramics 5=Cement&Lime 6= Basic Metals 7=Electricity 8=Other Sectors Maximum distance $distance % Truncated at $truncate % Standard errors clustered by firm.)
*xtreg `xxx' i.sector#c.ETSpost i.year [iweight=ETS_GroupWeight],fe vce(robust)
*the above specification gives impossible results, because the post versus pre effect is not sector-specific
xtreg `xxx' i.sector#c.ETSpost i.sector#i.year [iweight=ETS_GroupWeight],fe vce(robust)
outreg2 using  Sectors_OLS_FE_dist${distance}_trunc${truncate}, word title(Regressions per sector) ctitle(`xxx'2wayFE) addnote(1=Paper 2=Chemicals 3=Glass 4=Ceramics 5=Cement&Lime 6= Basic Metals 7=Electricity 8=Other Sectors Maximum distance $distance % Truncated at $truncate % Standard errors clustered by firm.)
* Outreg allows option label, but it doesn't seem to work for factor variables, keep or dorp doesn't work with factor variables either
}
gen Large=Small==0&Medium==0
foreach yyy in ETS post ETSpost {
gen `yyy'_Small=`yyy'==1 & Small==1 
gen `yyy'_Medium=`yyy'==1 & Medium==1
gen `yyy'_Large=`yyy'==1 & Small==0 & Medium==0
}
foreach xxx in revenue log_revenue assets log_assets employees log_employees ebit ebt {
reg `xxx' ETSpost_* ETS_* post_* Small Medium Large  [iweight=ETS_GroupWeight], cluster(firm_id) nocons
outreg2 using  Size_OLS_dist${distance}_trunc${truncate}, word title(Regressions according to size) ctitle(`xxx'OLS) addnote(1=Paper 2=Chemicals 3=Glass 4=Ceramics 5=Cement&Lime 6= Basic Metals 7=Electricity 8=Other Sectors Maximum distance $distance % Truncated at $truncate % Standard errors clustered by firm.)
}
br bvdid ETS nace4dig bankrupt if ETS==0 & year==2012 

