	select 					
    c.loan_class_desc as program,						
	YEAR(c.PurchaseDate) as Yr,					
	MONTH(c.PurchaseDate) as Mo,					
	DATEDIFF(MONTH,c.PurchaseDate, cmss.EOM_Date) as Age,					
	sum(case when cmss.DaysPastDue > 30 and cmss.ContractStatusId in (0,1,4) then cmss.CurrentBalance else 0 end) as DqBal,		--0=Active Purchased, 1=Active Rollover, 4=Buyback			
	sum(case when  cmss.ContractStatusId in (0,1,4) then cmss.CurrentBalance else 0 end) as CurBal,					
	sum(c.[LTV%]/100) as LTV,					
	SUM(c.AmtFinanced) as AmtFin,					
	COUNT(loan_number) as Deals,					
	CAST(Avg(c.InterestRate) as decimal(4,2)) as Apr,					
	SUM(c.Discount+c.BuyFee) as Discount					
						
	from cig_service.dbo.contractmonthlysnapshot cmss					
						
     inner join CIG_service.dbo.contract sc on sc.ContractId = cmss.ContractId 						
	 inner join CIG_Sandbox.dbo.loanview c on c.loan_number = sc.NLSLoanNo					
						
	--[CIG_Service].[dbo].[ContractMonthlySnapShot] cmss					
						
	--inner join CIG_Service.dbo.Contract sc on sc.ContractId = cmss.ContractId					
	--inner join CIG_Sandbox.dbo.loanview c on c.loan_number = sc.NLSLoanNo					
	-- left join cig_service.dbo.BusinessEOMDate b on (b.Date >= c.PurchaseDate and b.Date <= GETDATE())					
						
	where c.PurchaseDate between '2010-01-01' and '2016-09-30'  					
	 --and co.EOM_Date = '2014-04-30' 					
	 and c.CIGLoanStatus not in ('u')					
	 and DATEDIFF(MONTH,c.PurchaseDate, cmss.EOM_Date) >= 0					
						
	 group by c.loan_class_desc,					
	          YEAR(c.PurchaseDate),					
	          MONTH(c.PurchaseDate),					
	          DATEDIFF(MONTH,c.PurchaseDate, cmss.EOM_Date)					
