/*
  ONS Census 2021: population processing example
  Source data: RM121, Sex by age, England and Wales (ONS).

  This program imports the accompanying CSV, assigns broad age bands,
  performs simple quality checks, and creates England-and-Wales totals and
  percentages by sex and age band.

  In SAS Studio: upload both files to the same folder, then replace data_dir
  below with that folder's path.
*/

%let data_dir=/Users/alex/Documents/Codex/2026-11-19/ca/outputs;

filename onsin "&data_dir./ons_rm121_sex_by_age_2021.csv";

/* Import explicitly so the program does not depend on PROC IMPORT guessing
   column types or variable names from the CSV headers. */
data ons_population;
    infile onsin dsd dlm=',' firstobs=2 lrecl=1048576 truncover;
    length la_code $9 la_name $80 sex $6 age_band $30 age_group $6;
    informat sex_code age_code population best32.;
    format population comma15.;

    input la_code :$9.
          la_name :$80.
          sex_code :best32.
          sex :$6.
          age_code :best32.
          age_band :$30.
          population :best32.;

    /* Convert the ONS 23 age categories into common reporting bands. */
    select (age_code);
        when (1, 2)                     age_group = '0-4';
        when (3, 4, 5, 6)               age_group = '5-15';
        when (7, 8, 9)                  age_group = '16-24';
        when (10, 11, 12, 13, 14, 15,
              16, 17)                   age_group = '25-64';
        when (18, 19, 20, 21, 22, 23)   age_group = '65+';
        otherwise                       age_group = 'Unknown';
    end;

    if missing(la_code) or missing(sex) or missing(population) then delete;
run;

/* Quality check: there should be no missing or negative counts. */
proc sql;
    title 'Data-quality check';
    select count(*) as records format=comma12.,
           sum(missing(age_group)) as missing_age_groups,
           sum(population < 0) as negative_counts
    from ons_population;
quit;

/* Aggregate the local-authority records to England-and-Wales totals. */
proc summary data=ons_population nway;
    class sex age_group;
    var population;
    output out=population_by_age_sex(drop=_type_ _freq_) sum=population;
run;

proc sql;
    create table population_results as
    select a.sex,
           a.age_group,
           a.population format=comma15. as population,
           100 * a.population / b.total_population
               as percent_of_sex format=5.1
    from population_by_age_sex as a
    inner join
      (select sex, sum(population) as total_population
       from population_by_age_sex
       group by sex) as b
    on a.sex = b.sex
    order by sex, a.age_group;
quit;

title 'England and Wales population by sex and broad age group, Census 2021';
proc print data=population_results noobs label;
    label age_group='Age group'
          percent_of_sex='Percent within sex';
run;

proc sgplot data=population_by_age_sex;
    vbar age_group / response=population group=sex groupdisplay=cluster;
    yaxis grid label='Population';
    xaxis label='Age group';
    title 'Population totals by sex and broad age group';
run;

title;
