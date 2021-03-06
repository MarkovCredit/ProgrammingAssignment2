select t1.*, t2.Net_Recovery, t1.Chgoff_Amt - t2.Net_Recovery as Net_chgoff		
from		
(select 		
p.NLSProgramDescription as program,	
sum(colveh.current_value) as MMR,
sum(colveh.original_value) as Book,
d.state,		
YEAR(sc.PurchasedDate) as Yr,		
MONTH(sc.PurchasedDate) as Mo,		
DATEDIFF(MONTH,sc.PurchasedDate, b.Date) as Age,		
sum(sc.LTV/100) as LTV,		
SUM(CASE WHEN DATEDIFF(MONTH,sc.PurchasedDate, b.Date) =CO.ContractPeriod and co.Period = 0 THEN  co.NetCOAmount ELSE 0 END)as Chgoff_Amt,		
SUM(sc.Amount) as AmtFin,		
COUNT(distinct NLSLoanNo)  as Deals,		
Avg(sc.Rate/100) as Apr,		
SUM(sc.ReservedAmount+sc.BuyAmount) as Discount	
		
from CIG_Service.dbo.Contract sc		
inner join CIG_Service.dbo.program p on p.programid = sc.ProgramId 		
inner join CIG_Service.dbo.Dealer d on sc.DealerId = d.DealerId		
inner join nls.dbo.loanacct la on la.loan_number = sc.NLSLoanNo 		
left outer  join CIG_Service.dbo.COContractperiod co on sc.ContractId = co.ContractId  and co.Period = 0 		
left join cig_service.dbo.BusinessEOMDate b on (b.Date >= sc.PurchasedDate and b.Date <= '2015-12-31')	
join NLS_loanacct loanacct on loanacct.loan_number = cast(sc.NLSLoanno as varchar(10))
join NLS_loanacct_collateral_link clink on clink.acctrefno=loanacct.acctrefno
join NLS_collateral_vehicle colveh on colveh.collateral_id=clink.collateral_id
	 
where sc.PurchasedDate between '2014-01-01' and '2015-12-31'  		
 -- and co.EOM_Date <> '2014-04-30' 		
 --and la.acctrefno not in (select acctrefno from NLS.dbo.loanacct_statuses las where las.status_code_no = 198 and las.effective_date between '1/1/2010' and '9/30/2016')		
 and DATEDIFF(MONTH,sc.PurchasedDate, b.Date) >= 0		
group by  p.NLSProgramDescription ,		
          d.state,		
          YEAR(sc.PurchasedDate),		
          MONTH(sc.PurchasedDate),		
          DATEDIFF(MONTH,sc.PurchasedDate, b.Date)) t1		
                     		
join 		
		
(		
select  		
 p.NLSProgramDescription as Program,		
d.state,		
YEAR(sc.PurchasedDate) as Yr,		
MONTH(sc.PurchasedDate) as Mo,		
DATEDIFF(MONTH,sc.PurchasedDate,b.Date) as Age, 
		
SUM(CASE WHEN DATEDIFF(MONTH,sc.PurchasedDate	, b.Date) = CO.ContractPeriod and co.Period <> 0 THEN  (TotalRecovery - TotalExpense) ELSE 0 END)as Net_Recovery	
from CIG_Service.dbo.Contract sc		
inner join CIG_Service.dbo.program p on p.programid = sc.ProgramId 		
inner join CIG_Service.dbo.Dealer d on sc.DealerId = d.DealerId		
inner join nls.dbo.loanacct la on la.loan_number = sc.NLSLoanNo 		
left outer  join CIG_Service.dbo.COContractperiod co on sc.ContractId = co.ContractId 		
left join cig_service.dbo.BusinessEOMDate b on (b.Date >= sc.PurchasedDate and b.Date <= '2015-12-31')		
join NLS_loanacct loanacct on loanacct.loan_number = cast(sc.NLSLoanno as varchar(10))
join NLS_loanacct_collateral_link clink on clink.acctrefno=loanacct.acctrefno
join NLS_collateral_vehicle colveh on colveh.collateral_id=clink.collateral_id 
		
where sc.PurchasedDate between '2014-01-01' and '2015-12-31'  		
and DATEDIFF(MONTH,sc.PurchasedDate, b.Date) >= 0		
and la.acctrefno not in (select acctrefno from NLS.dbo.loanacct_statuses las where las.status_code_no = 198 and las.effective_date between '2014-01-01' and '2015-12-31')		
group by  p.NLSProgramDescription ,		
          d.state,		
          YEAR(sc.PurchasedDate),		
          MONTH(sc.PurchasedDate),		
          DATEDIFF(MONTH,sc.PurchasedDate, b.Date)) t2		
           		
on t1.Program = t2.Program  and t1.state = t2.state and t1.yr=t2.yr and t1.mo = t2.mo and t1.age=t2.age
		
order by t1.Yr, t1.mo, t1.age		
