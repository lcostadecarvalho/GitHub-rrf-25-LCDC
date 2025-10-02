* RRF 2025 - Processing Data Template	
*-------------------------------------------------------------------------------	
* Loading data
*------------------------------------------------------------------------------- 	
	
	* Load TZA_CCT_baseline.dta
	use "${raw}/TZA_CCT_baseline.dta", clear
	
*-------------------------------------------------------------------------------	
* Checking for unique ID and fixing duplicates
*------------------------------------------------------------------------------- 		

	* Identify duplicates 
	ieduplicates	hhid ///
					using "${outputs}/duplicates.xlsx", ///
					uniquevars(key) ///
					keepvars(submissionday duration) ///
					nodaily
					
	
*-------------------------------------------------------------------------------	
* Define locals to store variables for each level
*------------------------------------------------------------------------------- 							
	
	* IDs
	local ids 		vid hhid enid	
	
	* Unit: household
	local hh_vars 	floor - n_elder ///
					food_cons - submissionday
	
	* Unit: Household-memebr
	local hh_mem	gender age read clinic_visit sick days_sick ///
					treat_fin treat_cost ill_impact days_impact
	
	
	* define locals with suffix and for reshape
	foreach mem in `hh_mem' {
		
		local mem_vars 		"`mem_vars' `mem'_* " // creating a list like gender_* age_* etc starts empty and "appends" in the end
		local reshape_mem	"`reshape_mem' `mem'_ " // creating  a list like gender_ age_ etc 
	}
		
*-------------------------------------------------------------------------------	
* Tidy Data: HH-member 
*-------------------------------------------------------------------------------*

	preserve 

		keep `mem_vars' `ids'

		* tidy: reshape tp hh-mem level 
		reshape long `reshape_mem', i(`ids') j(member)
		
		* clean variable names 
		rename *_ * // lcdc: remove the underscores
		
		* drop missings 
		drop if mi(gender)
		
		* Cleaning using iecodebook
		// recode the non-responses to extended missing
		// add variable/value labels
		// create a template first, then edit the template and change the syntax to 
		// iecodebook template
		iecodebook apply 	using ///
								"${outputs}/hh_mem_codebook.xlsx"
								
		isid hhid member, sort 							
		
		* Save data: Use iesave to save the clean data and create a report 
		iesave 	"${inter}/TZA_CCT_HH_mem.dta", ///
				idvars(hhid member)  version(15) replace ///
				report(path("${outputs}/TZA_CCT_HH_mem_report.csv") replace) 
				
	restore			
	
*-------------------------------------------------------------------------------	
* Tidy Data: HH
*-------------------------------------------------------------------------------	

	preserve 
		
		* Keep HH vars
		keep `ids' `hh_vars'
		
		* Check if data type is string
		ds, has (type string)	
		
		* Fix data types 
		
		gen submissiondate = date(submissionday, "YMD hs")
		format submissiondate %td
		
		* numeric should be numeric
		* dates should be in the date format
		* Categorical should have value labels 
		
				
		* duration should be numeric 
		destring duration, replace
		
		* ar_farm_unit should be categorical 
		encode ar_farm_unit, gen(ar_unit)
	
		* clean crop_other: add info to crop variable
		replace crop_other = proper(crop_other)
		
		* check labelbook for crop to add values for new crops 
		labelbook df_CROP
		
		replace crop = 40 if regex(crop_other, "Coconut") == 1
		replace crop = 41 if regex(crop_other, "Sesame") == 1
		
		* adding value labels for new crops
		label define df_CROP 40 "Coconut" 41 "Sesame", add
				
		
		* Turn numeric variables with negative values into missings
		ds, has(type numeric)
		global numVars `r(varlist)'

		foreach numVar of global numVars {
			
			qui recode 	`numVar' 	(-88 	= .d) // don't know
		}	
		
		* Explore variables for outliers
		sum food_cons nonfood_cons ar_farm, det
		
		* dropping, ordering, labeling before saving
		drop 	ar_farm_unit submissionday crop_other
				
		order 	ar_unit, after(ar_farm)
		
		lab var submissiondate "Date of interview"
		
		isid hhid, sort 
		
		* Save data		
		iesave 	"${data}/Intermediate/TZA_CCT_HH.dta", ///
				idvars(hhid)  version(15) replace ///
				report(path("${outputs}/TZA_CCT_HH_report.csv") 		replace)
	restore
	

*-------------------------------------------------------------------------------	
* Tidy Data: Secondary data
*------------------------------------------------------------------------------- 	
	
	* Import secondary data 
	import delimited "${data}/Raw/TZA_amenity.csv", clear
	
	* reshape wide 
	reshape wide n , i(adm2_en) j(amenity) str
	
	* rename for clarity
	rename n* n_*
	
	encode adm2_en , gen(district) 
	
	* Label vars 
	lab var district "District"
	lab var n_school "No. of schools"
	lab var n_clinic "No. of clinics"
	lab var n_hospital "No. of hospitals"
	
	* Save
	keeporder district n_*
	
	save "${data}/Intermediate/TZA_amenity_tidy.dta", replace

	
****************************************************************************end!
	
