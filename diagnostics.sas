

/******************************************************************************
* STUDY: Heart Failure Beta-Blocker Study
* PURPOSE: Prepare and validate patient cohort data
* DESCRIPTION: This program identifies patients with valid records from 
*              primary care data and creates a clean dataset for analysis
******************************************************************************/

/*============================================================================
* SECTION 1: LIBRARY ASSIGNMENTS
* Define all necessary data libraries for the study
*============================================================================*/

/* Primary care cohort data 
   Contains raw patient data for those identified with HF in primary care */
libname primary "F:\Users\8082650\BB study\primary care cohort - raw data"; 

/* HES cohort data
   Contains raw patient data for those identified with HF through hospital records */
libname HES "F:\Users\8082650\BB study\only HF in HES patients - raw data"; 

/* Codelists library
   Contains medical code lists (medcodeids) and product codes (prodcodeids) 
   used for identifying diagnoses and medications */
libname codelist "F:\Users\8082650\Codelist"; 

/* Prescription data for primary care cohort
   Created using separate "create prescriptions" syntax file */
libname rx_pc "F:\Users\8082650\BB study\prescriptions for primary care cohort"; 

/* Prescription data for HES cohort
   Created using separate "create prescriptions" syntax file */
libname rx_hes "F:\Users\8082650\BB study\prescriptions for hes cohort"; 

/* Diagnosis data for primary care cohort
   Contains specific condition diagnoses */
libname dx_pc "F:\Users\8082650\BB study\diagnoses for primary care cohort"; 

/* Diagnosis data for HES cohort
   Contains specific condition diagnoses */
libname dx_hes "F:\Users\8082650\BB study\diagnoses for hes cohort"; 

/* Output library for processed primary care cohort */
libname c_pc "F:\Users\8082650\BB study\pc cohort";

                                                   /****************DIAGNOSTICS FOR PATIENT FILE************************************/


/****************PROCEDURE FOR PATIENTS IDENTIFIED IN PRIMARY CARE************************************/

/*============================================================================
* SECTION 2: DATA PREPARATION for the patients identified in primary care
* Sort and merge patient and practice data
*============================================================================*/

/* Sort patient data by practice ID for merging */
proc sort data=primary.patient;
    by pracid;
run;

/* Sort practice data by practice ID for merging */
proc sort data=primary.practice;
    by pracid;
run;

/* Merge patient and practice data
   - Keeps all patient records (in=ina)
   - Adds practice last collection date (lcd) from practice file
   - This allows us to determine when practices stopped collecting data */
data patient_new;
    merge primary.patient (in=ina)
          primary.practice (in=inb keep=pracid lcd);
    by pracid;
    if ina;  /* Keep only records that exist in patient file */
run;


/*============================================================================
* SECTION 3: CREATE VALID OBSERVATION PERIODS
* Define entry and exit dates for each patient's follow-up period
*============================================================================*/

data patient_new;
    set patient_new;
    
    /* Initialize entry date as registration start date */
    init = regstartdate;
    
    /* Initialize exit date as practice's last collection date */
    exit = lcd;
    
    /* Create inclusion flag (0 = exclude, 1 = include) */
    include = 0;
    
    /* Adjust exit date based on earliest of:
       1. CPRD death date (if available and before lcd)
       2. Registration end date (if before lcd)
       3. Practice last collection date (default) */
    
    /* If patient died before practice stopped collecting, use death date */
    if cprd_ddate < exit and cprd_ddate <> . then 
        exit = cprd_ddate;
    
    /* If patient left practice before it stopped collecting, use end date */
    if regenddate < exit and regenddate <> . then 
        exit = regenddate;
    
    /* Patient is valid only if entry date precedes exit date */
    if init < exit then 
        include = 1;
    
    /* Format dates for readability */
    format init ddmmyy10. exit ddmmyy10.;
run;


/*============================================================================
* SECTION 4: CREATE FINAL VALID PATIENT DATASET
* Keep only patients with valid observation periods
*============================================================================*/

data primary.patient_valid;
    set patient_new;
    where include = 1;  /* Keep only patients flagged as valid */
run;


/*============================================================================
* SECTION 5: DIAGNOSTIC CHECKS for patient file
* Verify data quality and generate summary statistics
*============================================================================*/

/* Check gender distribution in valid cohort */
proc freq data = primary.patient_valid;
    tables gender acceptable;
    title "Distribution of Gender and Acceptable in Valid Patient Cohort";
run;

/* Generate summary statistics for key variables
   Output results to a dataset for formatting */
ods output summary = means_out;

proc means data = primary.patient_valid n nmiss min max;
    var init exit yob;  /* Entry date, exit date, year of birth */
    title "Summary Statistics for Key Date Variables";
run;

/* Display formatted summary statistics
   Ensures dates are shown in readable format */
proc print data = means_out;
    format init_min init_max
           exit_min exit_max ddmmyy10.;
    title "Formatted Summary Statistics with Date Ranges";
run;


/****************PROCEDURE FOR THE PATIENTS IDENTIFIED IN HES************************************/

/*============================================================================
* SECTION 6: In HES we need to select the patients with acceptable = 1 
*============================================================================*/

data hes.patient_acceptable;
set hes.patient;
if acceptable = 1;
run;

/*============================================================================
* SECTION 7: DATA PREPARATION for the patients identified in primary care
* Sort and merge patient and practice data 
*============================================================================*/

/* Sort patient data by practice ID for merging */
proc sort data=hes.Patient_acceptable;
by pracid;
run;


/* Sort patient data by practice ID for merging */
proc sort data=hes.practice;
by pracid;
run;

/* Merge patient and practice data
   - Keeps all patient records (in=ina)
   - Adds practice last collection date (lcd) from practice file
   - This allows us to determine when practices stopped collecting data */

data patient_accept_new;
merge hes.Patient_acceptable (in=ina) hes.practice (in=inb keep= pracid lcd);
by pracid;
if ina;
run;

/*============================================================================
* SECTION 8: CREATE VALID OBSERVATION PERIODS
* Define entry and exit dates for each patient's follow-up period
*============================================================================*/

data patient_new;
    set patient_new;
    
    /* Initialize entry date as registration start date */
    init = regstartdate;
    
    /* Initialize exit date as practice's last collection date */
    exit = lcd;
    
    /* Create inclusion flag (0 = exclude, 1 = include) */
    include = 0;
    
    /* Adjust exit date based on earliest of:
       1. CPRD death date (if available and before lcd)
       2. Registration end date (if before lcd)
       3. Practice last collection date (default) */
    
    /* If patient died before practice stopped collecting, use death date */
    if cprd_ddate < exit and cprd_ddate <> . then 
        exit = cprd_ddate;
    
    /* If patient left practice before it stopped collecting, use end date */
    if regenddate < exit and regenddate <> . then 
        exit = regenddate;
    
    /* Patient is valid only if entry date precedes exit date */
    if init < exit then 
        include = 1;
    
    /* Format dates for readability */
    format init ddmmyy10. exit ddmmyy10.;
run;



/*============================================================================
* SECTION 9: CREATE FINAL VALID PATIENT DATASET
* Keep only patients with valid observation periods
*============================================================================*/

data hes.patient_valid;
set hes.patient_accept_new;
where include=1; /* Keep only patients flagged as valid */
run;



/*============================================================================
* SECTION 10: DIAGNOSTIC CHECKS for patient file
* Verify data quality and generate summary statistics
*============================================================================*/

/* Check gender distribution in valid cohort */
proc freq data = hes.patient_valid;
    tables gender acceptable;
    title "Distribution of Gender and Acceptable in Valid Patient Cohort";
run;

/* Generate summary statistics for key variables
   Output results to a dataset for formatting */
ods output summary = means_out;

proc means data = hes.patient_valid n nmiss min max;
    var init exit yob;  /* Entry date, exit date, year of birth */
    title "Summary Statistics for Key Date Variables";
run;

/* Display formatted summary statistics
   Ensures dates are shown in readable format */
proc print data = means_out;
    format init_min init_max
           exit_min exit_max ddmmyy10.;
    title "Formatted Summary Statistics with Date Ranges";
run;


*in the diagnostics we see that one patient has gender = 3 -> we have to exclude this patient;

data hes.patient_valid_gender;
set hes.patient_valid;
if gender = 1 | gender = 2;
run;



/**********************************ignore this - have incorporated directly the obsdate checks in the "create diagnoses" syntax file*****************/

                                   /**********************DIAGNOSTICS FOR DIAGNOSES FILES************************************/

/*************************PATIENTS IDENTIFIED IN PC************************************/

*HF diagnoses in primary care;
*we will use the dx_pc.hf, created in the create diagnoses syntax file and we will see the distribution of obsdates;


ods output summary = means_out;

proc means data = dx_pc.hf n nmiss min max;
    var obsdate;  /* HF diagnosis date*/
    title "Summary Statistics for obsdate in dx_pc.hf";
run;

/* Display formatted summary statistics
   Ensures dates are shown in readable format */
proc print data = means_out;
    format obsdate_min obsdate_max ddmmyy10.;
    title "summary statistics for obsdate in dx_pc.hf with date ranges";
run; 

*we notice that there are missing obsdates (n=406), and obsdates with irrational values (min = 01/01/1900 and max = 31/12/9999);
*for this reason, we will also run the proc freq to see how many patients have these irrational values;

proc freq data = dx_pc.hf;
tables obsdate;
run;

*5 observations with obsdate = 01/01/1900 and 1 observation with obsdate = 31/12/9999 (all the other values are plausible (1921 - 2024)
-> exclude from the dx_pc.hf the observations with missing obsdate and with these irrational values;

data dx_pc.hf_valid_obsdate;
set dx_pc.hf;
if obsdate ne . and '08DEC1921'd =< obsdate < '19SEP2024'd ;
run;

*check if we exclude patients as well or only observations;

proc sort data = dx_pc.hf;
by patid;
run;

data hf_unique_patid;
set dx_pc.hf;
by patid; 
if first.patid;
run;


proc sort data = dx_pc.hf_valid_obsdate;
by patid;
run;

data hf_unique_patid_valid;
set dx_pc.hf_valid_obsdate;
by patid; 
if first.patid;
run;


*we don't exclude any patients: both the hf_unique_patid and the hf_unique_patid_valid consist of 27,742 patients;


*HF diagnoses in HES;
*we will use the dx_pc.hf_sc dataset, created in the "create dataset with first HF diagnosis" syntax and run the diagnostics on the event date;

 
ods output summary = means_out;

proc means data = dx_pc.hf_sc n nmiss min max;
    var eventdate;  /* HF hospitalization date */
    title "Summary Statistics for eventdate in dx_pc.hf_sc";
run;

/* Display formatted summary statistics
   Ensures dates are shown in readable format */
proc print data = means_out;
    format eventdate_min eventdate_max ddmmyy10.;
    title "summary statistics for eventdate in dx_pc.hf_sc with date ranges";
run; 

*the dates range from 31/03/1997 to 31/03/2023 and we have no missing event dates, therefore we don't need to do anything;

*we will run the proc freq to scan through all the eventdates;

proc freq data = dx_pc.hf_sc;
tables eventdate;
run;


/*************************PATIENTS IDENTIFIED IN HES***********************************/

*HF diagnoses;
*we will use the dx_hes.hf dataset, created in the "create dataset with first HF diagnosis" syntax and run the diagnostics on the event date;


ods output summary = means_out;

proc means data = dx_hes.hf n nmiss min max;
    var eventdate;  /* HF hospitalization date */
    title "Summary Statistics for eventdate in dx_hes.hf";
run;

/* Display formatted summary statistics
   Ensures dates are shown in readable format */
proc print data = means_out;
    format eventdate_min eventdate_max ddmmyy10.;
    title "summary statistics for eventdate in dx_hes.hf with date ranges";
run; 

*the dates range from 21/01/1997 to 31/03/2023 and we have 1 missing event date;
*we will exclude the 1 missing event date;

data dx_hes.hf_valid_eventdate;
set dx_hes.hf;
if eventdate ne .;
run;

*we will run the proc freq to scan through all the eventdates;

proc freq data = dx_hes.hf_valid_eventdate;
tables eventdate;
run;

*and we will check if we excluded a patient as well;
proc sort data = dx_hes.hf_valid_eventdate;
by patid;
run;

data hf_hes_unique;
set dx_hes.hf_valid_eventdate;
by patid;
if first.patid;
run;



*the total number of patients is 44,610 so we haven't excluded any patient;
