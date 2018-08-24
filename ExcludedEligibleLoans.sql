declare @allLoan table
(
loan_number int
)

insert into @allLoan
select 
cmss.NLSLoanNo
from cig_service.dbo.contractmonthlysnapshot cmss

     inner join CIG_service.dbo.contract c on c.ContractId = cmss.ContractId 
and cmss.EOM_Date  between '2016-12-31' and '2016-12-31'
and ContractStatusId in (0,1,4)
and CurrentBalance > 5

declare @partialLargeLoan table
(
loan_number int
)

insert into @partialLargeLoan
select 
la.loan_number AS Loan_Number
from loanacct  la with(nolock) 
join loanacct_detail ld with(nolock) on la.acctrefno =  ld.acctrefno 
join loanacct_detail_2 ld2 with(nolock) on ld.acctrefno =  ld2.acctrefno 
where 
      la.loan_group_no In (2,10) 
  and cast(ld2.userdef45 as date) <= DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1) --end of last month
      and (cast(ld.userdef26 as decimal (12,0))) < 31   
      and DATEDIFF(day, cast(ld.userdef20 as date),cast(ld.userdef21 as date)) < 46
      and cast(la.current_principal_balance as decimal (12,2)) > 1000               
      and DATEDIFF(m,DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1), la.curr_maturity_date) >= 6 --fix 
      and la.acctrefno not in (select ls.acctrefno  from loanacct_statuses ls where ls.status_code_no in    
      (112,141,164,201,193,213,142,161,191,198,208,196,199,217,218)) --- exclude dealer compliance status 218 on 12312015
      and la.acctrefno not in (
                     select distinct acctrefno from task t 
                           inner join loanacct lv on t.NLS_refno = lv.acctrefno 
                           where t.task_template_no = 2 and t.status_code_id not in (1,10,11,12,13,37,38,39,42)
              )
  and la.acctrefno in 
(
select lr.acctrefno
from loanacct_rate lr 
join 
(
select acctrefno,max(row_id) as rowId from loanacct_rate with(nolock) 
 group by acctrefno
 ) a on lr.acctrefno = a.acctrefno and lr.row_id = a.rowid
 where lr.interest_type = 0
)      
         and cast(isnull(ld2.userdef33,0.00) as float) < 100.00


select 
la.loan_number AS Loan_Number,
ld2.userdef45 as PurchaseDate,
cast(ld.userdef20 as date) as ContractDate,
year(cast(ld.userdef20 as date)) as Yr,
cast(ld.userdef14 as decimal (12,2)) as AmtFinanced,
cast(ld.userdef16 as decimal (12,2)) as InterestRate,
cast(ld.userdef18 as decimal (12,0)) as OriginalTerm,
cast(ld.userdef10 as decimal (12,0)) as PaidTerm,
cast(ld.userdef18 as decimal (12,0))-cast(ld.userdef10 as decimal (12,0)) as RemainningTerm,
cast(ld.userdef17 as decimal(10,2)) as RegPmtAmt,
cast(la.current_principal_balance as decimal (12,2)) as CurrentBalance,
cast(ld.userdef21 as date) as FirstPmtDate,
la.curr_maturity_date as MaturityDate,
DATEDIFF(day, cast(ld.userdef20 as date),cast(ld.userdef21 as date)) as DaysToFirstPmt,
ld.userdef11 as LastPaidDate,
ld.userdef03 as NextDueDate,
(cast(ld.userdef26 as decimal (12,0))) as DaysPastDue, 
cast(dealer_detail.userdef17 as nvarchar) as DealerID,
cast(dealer.payee as nvarchar(10)) as DealerName,
cast(dealer.state as nvarchar) as DealerState,
cast(dealer_detail.userdef07 as nvarchar) AS DealerType,
cvh.VIN,   
cvh.year as VehicleYear,
cvh.make as VehicleMake,
cvh.model as VehicleModel,
cvh.original_miles as VehicleMileage,
cvh.original_value as VehicleBookvalue,  
case when cvh.title_status = 0 then 'Not Received'
    when cvh.title_status = 1 then 'Submitted'
    when cvh.title_status = 2 then 'Perfected'
    when cvh.title_status = 3 then 'Received Needs Attention'
    when cvh.title_status = 4 then 'Received'
    when cvh.title_status = 5 then 'Released'
    when cvh.title_status = 6 then 'Lien Posted'
    when cvh.title_status = 7 then 'Unsecured'
    when cvh.title_status = 8 then 'Custodian'
    when cvh.title_status = 9 then 'Custodian-Return Requested'
    when cvh.title_status = 10 then 'Service Released'
    when cvh.title_status = 11 then 'Lien Sold'
    when cvh.title_status = 12 then 'Other'
    else 'Blank' end as TitleStatus,
   
case when cvh.title_type = 0 then 'None'
    when cvh.title_type = 1 then 'Paper'
    when cvh.title_type = 2 then 'Electronic'
    when cvh.title_type = 3 then 'Lien'
    when cvh.title_type = 4 then 'Validated Registration'
    else 'Others' End as TitleType,
     
lclass.code_description as Program,
cast(ld2.userdef29 as decimal (12,0))as Fico,
cast(ld2.userdef35 as decimal (12,2))as LTV,
cast(isnull(ld2.userdef33,0.00) as float) AS DTI, 
cast(ld2.userdef34 as float) as PTI,
case when isnull(cif_demo.userdef02,'')='' then 0 else cast(cif_demo.userdef02 as decimal) end as ResYears,
case when isnull(cif_demo.userdef03,'')='' then 0 else cast(cif_demo.userdef03 as decimal) end as ResMonths,
case when isnull(cif_demo.userdef09,'')='' then 0 else cast(cif_demo.userdef09 as decimal) end as JobYears,
case when isnull(cif_demo.userdef10,'')='' then 0 else cast(cif_demo.userdef10 as decimal) end as JobMonths,
cast(ld2.userdef30 as decimal) as RVScore,
la.loan_group_no,
cast(la.status_code_no as nvarchar) as StatusCode
, cast(cl.userdef03 as nvarchar) as Deals
, cast(cl.userdef04 as nvarchar) as DocIssues
, CIG_Sandbox.dbo.NLS_GetContractStatusDescString(la.acctrefno) as SubstatusDesc
, CIG_Sandbox.dbo.NLS_GetContractStatusCodesString(la.acctrefno) as SubstatusNumber


from loanacct  la with(nolock) 
join loanacct_detail ld with(nolock) on la.acctrefno =  ld.acctrefno 
join loanacct_detail_2 ld2 with(nolock) on ld.acctrefno =  ld2.acctrefno 
join loanacct_collateral_link lcl with(nolock) on lcl.acctrefno = la.acctrefno 
join collateral_vehicle cvh with(nolock) on lcl.collateral_id = cvh.collateral_id
join collateral_location cl with(nolock) on cl.collateral_id = lcl.collateral_id
left join cif_demographics cif_demo with(nolock) on cif_demo.cifno=la.cifno
left join loan_class lclass with(nolock) on lclass.codenum = la.loan_class1_no
join cif_vendor dealer with(nolock) on dealer.cifno = la.dealer_cifno
join cif_detail dealer_detail with(nolock) on dealer_detail.cifno = dealer.cifno

  
where 
      la.loan_number in (select al.loan_number from @allLoan al left join @partialLargeLoan pl on pl.loan_number = al.loan_number where pl.loan_number is null)
Order by PurchaseDate desc 




