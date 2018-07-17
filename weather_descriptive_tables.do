
*DESCRIPTIVE TABLES (calculated using sampling weights):

*run first part of three-part model to generate flag to mark the estimation subsample (outcome chosen here is arbitrary)
gsem(foodatallwalk <- meanrh sumprecip meanwindspd meantemp i.month incom2 hhsize2 ///
i.own2 i.gend2 i.hisp2 i.ntvty2 i.lic2 i.emply2 i.disab2 i.educa2 age2 i.resty3 i.dow hhveh, probit), vce(clus sampn)

*mark estimation sample
g esample=e(sample)==1

*survey set data
svyset sampno [pweight= expperwgt], strata(strata) single(centered)

*continuous variables
svy, subpop(esample): mean  meanrh sumprecip meanwindspd meantemp incom2 hhsize2 age2 hhveh totalmiles
outreg using wordtbl, stat(b se) bdec(3) ctitle("Variable","Mean or Percent", "Std Error")  title("Table 1: Descriptive Statistics") nostars nosubstat

*categorical variables
foreach var of varlist month own2 gend2 hisp2 ntvty2 lic2 emply2 disab2 educa2 resty3 dow incom2{
	svy, subpop(esample): tab `var'
	outreg using wordtbl, stat(b) bdec(3) append nostars nosubstat
	}
