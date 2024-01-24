********************************************************************
*** Brodeur, A., Clark, A., Fleche, S., & Powdthavee, N. (2022, August 5). COVID-19, Stay-Home Orders and Well-Being: Evidence from Google Trends. Retrieved from osf.io/4ywjc ***
********************************************************************

	*Change path below

	global data INPUTDATADIR

	**********************************************************
	*****			CREATE DATABASE						******
	**********************************************************

	local varlist VARLIST
	local reglist REGLIST
	
	foreach var of local varlist {
		
	/* Merge Weekly and Daily DataBases*/

	foreach i of local reglist {
	global sub_file "`var'/`i'"
	di "Value of global merged: $sub_file"
	insheet using "$data/$sub_file/weekly_timeline.csv", delimiter(",") clear
	drop in 1/2
	rename v1 date
	label var date "Date (String)"
	rename v2 w_`var'_20_21
	label var w_`var'_20_21 "Weekly queries: 20-21"
	save "$data/$sub_file/weekly_search_20_21_(`i').dta", replace

	insheet using "$data/$sub_file/daily_20_20_timeline.csv", delimiter(",") clear
	drop in 1/2
	rename v1 date
	label var date "Date (String)"
	rename v2 d_`var'_20_20
	label var d_`var'_20_20 "Daily queries: 2020"
	save "$data/$sub_file/daily_search_20_20_(`i').dta", replace

	insheet using "$data/$sub_file/daily_21_21_timeline.csv", delimiter(",") clear
	drop in 1/2
	rename v1 date
	label var date "Date (String)"
	rename v2 d_`var'_21_21
	label var d_`var'_21_21 "Daily queries: 2021"
	save "$data/$sub_file/daily_search_21_21_(`i').dta", replace

	use "$data/$sub_file/weekly_search_20_21_(`i').dta", clear
	merge 1:1 date using "$data/$sub_file/daily_search_20_20_(`i').dta"
	drop _merge
	merge 1:1 date using "$data/$sub_file/daily_search_21_21_(`i').dta"
	drop _merge
	sort date
	drop if d_`var'_20_20=="" & d_`var'_21_21==""
	replace w_`var'_20_21=w_`var'_20_21[_n-1] if w_`var'_20_21==""
	
	destring *`var'*, replace force
	save "$data/$sub_file/daily_search_20_21_(`i').dta", replace
	}

	/* Create Country, Year, Month, Week, Day Variables*/

	foreach i of local reglist {
	global sub_file "`var'/`i'"
    di "Value of global vars: $sub_file"
	use "$data/$sub_file/daily_search_20_21_(`i').dta", clear
	gen edate=date(date, "YMD")
	format edate %d
	gen year=year(edate)
	gen month=month(edate)
	gen week=week(edate)

	sort year date
	bysort year week: gen day_w=_n

	drop if month==12 /*Keep from January 1st to April 1st*/
	drop if date=="2020-02-29" /* 2020: bissextile*/

	sort year date
	bysort year: gen day=_n

	label var year "Year"
	label var month "Month"
	label var week "Week"
	label var day "Day"
	label var day_w "Day of the week"
	drop edate

	gen country = "`i'" 
	label var country "Country"

	save "$data/$sub_file/daily_search_20_21_(`i').dta", replace
	}

	/* Rescale Daily data using Weekly Data*/

	foreach i of local reglist {
	global sub_file "`var'/`i'"
    di "Value of global rescale: $sub_file"
	use "$data/$sub_file/daily_search_20_21_(`i').dta", clear
	destring *`var'*, replace force
	
	replace d_`var'_20_20=. if d_`var'_20_20==0
	replace d_`var'_21_21=. if d_`var'_21_21==0
	replace w_`var'_20_21=. if w_`var'_20_21==0

	bysort week: egen m_d_`var'_20_20=mean(d_`var'_20_20)
	bysort week: egen m_d_`var'_21_21=mean(d_`var'_21_21)
	
	gen d_`var'_20_21=.
	replace d_`var'_20_21=d_`var'_20_20*(w_`var'_20_21/m_d_`var'_20_20)
	replace d_`var'_20_21=d_`var'_21_21*(w_`var'_20_21/m_d_`var'_21_21) if d_`var'_20_21==.
	
	egen max_d_`var'_20_21=max(d_`var'_20_21)
	
	replace d_`var'_20_21=[d_`var'_20_21/max_d_`var'_20_21]*100
	drop max_*  m_*
	label var d_`var'_20_21 "Daily queries (adjusted): 18-20" 

	save "$data/$sub_file/daily_search_20_21_(`i').dta", replace
	}
	
	use "$data/`var'/FIRSTREG/daily_search_20_21_(FIRSTREG).dta", clear
	local reglist1 REG1LIST
	foreach i of local reglist1 {
	global sub_file "`var'/`i'"
    di "Value of global data subs: $sub_file"
	append using "$data/$sub_file/daily_search_20_21_(`i').dta"
	}
	order country date year month week day day_w d_`var'_20_21 d_`var'_20_20 d_`var'_21_21 w_`var'_20_21

	/* Merge with Dates of Lockdown for all Countries */

	merge m:1 country using "$data/EventsData_EVENTSDTAFILE.dta"
	di "Value of global data subs: `country'"
	drop _merge
	order country_name country date year month week day date_* d_`var'_20_21 d_`var'_20_20 d_`var'_21_21 w_`var'_20_21
	sort country year day
	gen event_day=day if date==date_event_ann
	bysort country: egen m_event_day=mean(event_day)
	replace event_day=m_event_day
	drop m_event_day
	bysort country: gen days_since_event=day-event_day 
	drop event_day
	label var days_since_event "Days elapsed since the event"
	gen post_event=0 
	replace post_event=1 if days_since_event>=0 & days_since_event!=.
	label var post_event "Period after event"

	order country_name country date year month week day day_w date_* days_since_event* post_event* d_`var'_20_21 d_`var'_20_20 d_`var'_21_21 w_`var'_20_21
	sort country year day


	save "$data/`var'/daily_`var'_20_21_all_full.dta", replace
		
	bysort year days_since_event: egen m_`var'_20_21=wtmean(d_`var'_20_21), weight(pop)
	save "$data/`var'/daily_`var'_20_21_all_full_mean.dta", replace

	}

	
