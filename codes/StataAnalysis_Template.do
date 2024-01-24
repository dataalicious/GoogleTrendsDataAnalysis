*** THIS IS A MODIFIED VERSION OF CODE FOUND ON https://osf.io/4ywjc/ *** 
***Brodeur, A., Clark, A., Fleche, S., & Powdthavee, N. (2022, August 5). COVID-19, Stay-Home Orders and Well-Being: Evidence from Google Trends. Retrieved from osf.io/4ywjc ***
********************************************************************
*** Ronaldo effect on Google trends Searches ***
********************************************************************


*Change the path below:

global data INPUTDATADIR
global results RESULTSDIR

	**********************************************************
	*****			MAIN ANALYSIS						******
	**********************************************************

	
	/* Figure 1: Google Trends in Coca Cola Before and After Ronaldo Rejected him*/
	
	local varlist VARLIST
	foreach var of local varlist {

		use "$data/`var'/daily_`var'_20_21_all_full.dta", clear
		drop if country == "world"
		drop if days_since_event==0 
		drop if days_since_event<-60
		keep if days_since_event!=.
		
		bysort year days_since_event: egen m_`var'_20_21=wtmean(d_`var'_20_21), weight(pop)

		twoway (connected m_`var'_20_21 days_since_event if year==2020, msize(vsmall) lcolor(gs10) mcolor(gs10)) ///
		(connected m_`var'_20_21 days_since_event if year==2021, msize(vsmall) /*lcolor(black) mcolor(black)*/), ///
		xline(0, lpattern(solid) lcolor(cranberry)) legend(order(1 "2020" 2 "2021")) /*ylabel(0(50)100)*/ ///
		ytitle("`var'") xlabel(-56 -49 -42 -35 -28 -21 -14 -7 0 7 14 21 28) xscale(range(-60 30)) ///
		saving("$results/`var'/`var'_DID.gph", replace) 
		
		}

		
	/* Figure 2: The Effects of Ronaldo on Searches */
	
	local varlist VARLIST
	
	foreach var of local varlist {
	
		use "$data/`var'/daily_`var'_20_21_all_full.dta", clear
		drop if days_since_event==0
		drop if country == "world"
		drop if country == "US"
		keep if days_since_event!=.

		replace year=year-2021
		gen post_event_year=post_event*year
		label var post_event_year "Period after lockdown *Year"
		
		sort country year day
		reghdfe d_`var'_20_21 post_event_year post_event [pw=pop] , absorb(country year week day_w) vce(cluster day) verbose(4) 
		eststo DID_`var'
		estadd local countryFE "Yes", replace
		estadd local timeFE "Yes", replace
		}
	
		coefplot (DID_VARNAME1, keep(post_event_year) color(cranberry) asequation(VARNAME1) ciopts(lcolor(cranberry) recast(rcap)))  ///
		(DID_VARNAME2, keep(post_event_year) color(cranberry) asequation(VARNAME2) ciopts(lcolor(cranberry) recast(rcap))) ///
		,label asequation swapnames xline(0, lcolor(black)) recast(bar) ci(90) legend(off) xtitle("DID Estimates")  ///
		headings(VARNAME1= "{bf:Treatment}" VARNAME2= "{bf:Control}")
		graph export "$results/All_figures_and_tables/DID_Estimates.png", replace
	

	/* Figure 3: Duration of the Effects of the event on searches*/
	
	local varlist VARLIST
	foreach var of local varlist {
			
		use "$data/`var'/daily_`var'_20_21_all_full.dta", clear
		keep if days_since_event!=.
		drop if country == "world"

		replace year=year-2020
		gen post_event_year=post_event*year
		label var post_event_year "Period after event *Year"
		
		gen event_week=week if date==date_event_ann
		bysort country: egen m_event_week=mean(event_week)
		replace event_week=m_event_week
		drop m_event_week
		bysort country: gen weeksinceevent=week-event_week
		drop event_week
		
		xi gen i.weeksinceevent*year, noomit
		
		drop if weeksinceevent<-4
		
		replace _IweeXyear_9=0
		
		sort country year day

		reghdfe d_`var'_20_21 _IweeXyear_9-_IweeXyear_16  _Iweeksince*  ///
		[pw=pop] , ///
		absorb(country year week day_w) vce(cluster day)
		eststo DID_event`var'
		estadd local countryFE "Yes", replace
		estadd local timeFE "Yes", replace
		
		coefplot DID_event`var', keep(_IweeXyear_*) recast(connected) color(cranberry) ciopts(lcolor(cranberry) ) vertical  ///
		label yline(0, lcolor(black))  ci(95) legend(off) xtitle("Weeks elapsed since the event") ///
		xline(5, lpattern(dash) lcolor(black)) ///
		rename(_IweeXyear_9= "-4" _IweeXyear_10= "-3" _IweeXyear_11="-2" _IweeXyear_12="-1" _IweeXyear_13="0" ///
		_IweeXyear_14="1" _IweeXyear_15="2" _IweeXyear_16="3") omitted ytitle("`var'") ///
		saving("$results/`var'/`var'_DID_Event_.gph", replace)
		
		}
	
	
		/* Table 2 : The Effects of the Ronaldo Event - DiD Estimates (Fig 2.) */
	
		esttab DID_VARNAME1 DID_VARNAME2 ///
		using "$results/All_figures_and_tables/Table1_PanelB(1).tex", replace label keep(post_event_year) ///
		b(2) se(2) r(3) booktabs sfmt(%12.0f) noconstant  nogaps ///
		coeflabel(post_event_year "T_{i,c}*Year_i") ///
		mtitles("Coca Cola" "VARNAME2") ///
		stats(countryFE timeFE N, fmt(. .  0) ///
		label("Country FE" "Year, Week and Day FE"  "Observations")) ///
		nonotes star(* 0.1 ** 0.05 *** 0.01) nonumbers
		

	/* Figure A2: Google Trends Before and After the Event (RDD 2021) */
	
	local varlist VARLIST
	foreach var of local varlist {
	
		use "$data/`var'/daily_`var'_20_21_all_full.dta", clear
		keep if year==2021
		drop if days_since_event==0
		drop if days_since_event<-60
		drop if country == "world"

		bysort days_since_event: egen m_`var'_20_21=wtmean(d_`var'_20_21), weight(pop)

		forvalues i=2/3 {
		gen days_since_event`i'=days_since_event^`i'
		}
		
		reg m_`var'_20_21 days_since_event* if post_event==0 [pw=pop], vce(cluster day)
		predict m_`var'_20_21_before if e(sample)
		reg m_`var'_20_21 days_since_event* if post_event==1 [pw=pop], vce(cluster day)
		predict m_`var'_20_21_after if e(sample)

		twoway (scatter m_`var'_20_21 days_since_event, msize(vsmall) mcolor(black)) ///
		(line m_`var'_20_21_before days_since_event, lpattern(dash) lcolor(black)) ///
		(line m_`var'_20_21_after days_since_event, lpattern(dash) lcolor(black)), ///
		xline(0, lpattern(solid) lcolor(cranberry)) legend(off) ytitle("`var'") ///
		xlabel(-60(30)30) xscale(range(-60 30)) saving("$results/`var'/`var'_RDD_21.gph", replace) 

		}
	
		graph combine "$results/VARNAME1/VARNAME1_RDD_20.gph" "$results/VARNAME2/VARNAME2_RDD_21.gph", ///
		rows(3) cols(2) imargin(0 0 0 0 0 0) iscale(.6) 
		graph export "$results/All_figures_and_tables/RDD_Graphs_2020_A4.png", replace
	

	/* Figure A3: Google Trends Before and After the event (RDD 2021) */
	
	local varlist VARLIST
	foreach var of local varlist {
	
		use "$data/`var'/daily_`var'_20_21_all_full.dta", clear
		keep if year==2020
		drop if days_since_event==0
		drop if days_since_event<-60
		drop if country == "world"

		bysort days_since_event: egen m_`var'_20_21=wtmean(d_`var'_20_21), weight(pop)

		forvalues i=2/3 {
		gen days_since_event`i'=days_since_event^`i'
		}
		
		reg m_`var'_20_21 days_since_event* if post_event==0 [pw=pop], vce(cluster day)
		predict m_`var'_20_21_before if e(sample)
		reg m_`var'_20_21 days_since_event* if post_event==1 [pw=pop], vce(cluster day)
		predict m_`var'_20_21_after if e(sample)

		twoway (scatter m_`var'_20_21 days_since_event, msize(vsmall) mcolor(black)) ///
		(line m_`var'_20_21_before days_since_event, lpattern(dash) lcolor(black)) ///
		(line m_`var'_20_21_after days_since_event, lpattern(dash) lcolor(black)), ///
		xline(0, lpattern(solid) lcolor(cranberry)) legend(off) ytitle("`var'") ///
		xlabel(-60(30)30) xscale(range(-60 30)) saving("$results/`var'/`var'_RDD_20.gph", replace) 

		}
	
		graph combine "$results/VARNAME1/VARNAME1_RDD_20.gph" "$results/VARNAME2/VARNAME2_RDD_20.gph", ///
		rows(3) cols(2) imargin(0 0 0 0 0 0) iscale(.6) 
		graph export "$results/All_figures_and_tables/RDD_Graphs_2020_A4.png", replace
	

	
		/* Figure A4: Google Trends Before and After the event Orders: All Topics*/
	
	local varlist VARLIST
	foreach var of local varlist {

		use "$data/`var'/daily_`var'_20_21_all_full.dta", clear
		drop if days_since_event==0 
		drop if days_since_event<-60
		keep if days_since_event!=.
		
		bysort year days_since_event: egen m_`var'_20_21=wtmean(d_`var'_20_21), weight(pop)

		twoway (connected m_`var'_20_21 days_since_event if year==2020, msize(vsmall) lcolor(gs10) mcolor(gs10)) ///
		(connected m_`var'_20_21 days_since_event if year==2021, msize(vsmall) /*lcolor(black) mcolor(black)*/), ///
		xline(0, lpattern(solid) lcolor(cranberry)) legend(order(1 "2020" 2 "2021")) /*ylabel(0(50)100)*/ ///
		ytitle("`var'") xlabel(-60(30)30) xscale(range(-60 30)) saving("$results/`var'/`var'_DID_A.gph", replace) ///
	
		}
	
		grc1leg "$results/VARNAME1/VARNAME1_DID_A.gph" "$results/VARNAME2/VARNAME2_DID_A.gph", ///
		rows(3) cols(2) imargin(0 0 0 0 0 0) iscale(.6) 
		graph export "$results/All_figures_and_tables/DID_Graphs_A1.png", replace

		
	
	
	/* Table A4: The Effects of the Event - RDD-DiD Estimates */
	
	local varlist VARLIST
	foreach var of local varlist {
		
		use "$data/`var'/daily_`var'_20_21_all_full.dta", clear
		drop if days_since_event==0
		keep if days_since_event!=.
		drop if country == "world"
		
		gen before_lockdown=1-post_event
		replace year=year-2020
		gen post_event_year=post_event*year
		label var post_event_year "Period after event *Year"
		gen before_lockdown_year=before_lockdown*year
				
		gen post_days_since_event=post_event*days_since_event
		gen before_days_since_event=before_lockdown*days_since_event
		gen post_y_days_since_event=post_event_year*days_since_event
		gen before_y_days_since_event=before_lockdown_year*days_since_event
			
		sort country year day
		
 		reghdfe d_`var'_20_21 post_event_year post_event post_y_* before_y_* ///
		post_days* before_days* [pw=pop], absorb(country year week day_w) ///
		vce(cluster day) 
		eststo RDD_DID_`var'
		estadd local countryFE "Yes", replace
		estadd local timeFE "Yes", replace
		
		}		
	
			
		esttab RDD_DID_VARNAME1 RDD_DID_VARNAME2 ///
		using "$results/All_figures_and_tables/Table1_PanelC(1).tex", replace label booktabs  keep(post_event_year) b(2) se(2) r(3) ///
		coeflabel(post_event_year "T_{i,c}*Year_i") ///
		mtitles("CocaCola" "VARNAME2") ///
		stats(countryFE timeFE N, fmt(. . 0)   ///
		label("Country FE" "Year, Week and Day FE" "Observations"))  compress ///
		nonotes star(* 0.1 ** 0.05 *** 0.01) nonumbers
				


		
