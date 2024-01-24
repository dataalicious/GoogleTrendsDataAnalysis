********************************************************************
***COVID-19, Lockdowns and Well-Being: Evidenc from Google Trends***
********************************************************************

* This do-file creates the final datasets for Europe

	*Change path below

	global data INPUTDATADIR

	**********************************************************
	*****			CREATE DATABASE						******
	**********************************************************

	local varlist VARLIST
	
	foreach var of local varlist {
		
		use "$data/`var'/daily_`var'_20_21_all_full.dta", clear
		drop if country == "world"
		drop if country == "US"
		
		bysort year days_since_event: egen m_`var'_20_21=wtmean(d_`var'_20_21), weight(pop)

		save "$data/`var'/daily_`var'_20_21_all_full_mean.dta", replace
		
		}
