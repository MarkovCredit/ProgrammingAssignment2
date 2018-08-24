ALTER procedure [dbo].[Report_StaticPool]
AS
BEGIN

--=============================================
-- Author:      Hiro Nakamura
-- Create date: 11/09/2016
-- Databases:   CIG_Sandbox
-- Description: Static Pool Report
--				Craete StaticPool_CumulativeLoss table (Loss by Program, Year, Month, Age)
--            
-- History:
--
--=============================================

declare @AgeCount	int = 72
declare @EndDate	date = eomonth(dateadd(m, -1, getdate()))
declare @StartDate  date = '1/1/2010'

declare @Program			varchar(20)
declare @PurchaseYear		int
declare @PurchaseMonth		int
declare @PurchaseQuarter	varchar(20)
declare @Age				int	  
declare @AmountFinanced		decimal(12,2)
declare @ChargeoffAmount	decimal(12,2)
declare @NetRecovery		decimal(12,2)
declare @Loss				decimal(12,2)
declare @AccumulatingLoss	decimal(12,2)
declare @LossPercent		decimal(12,6)
declare @AccumulatingLossPercent decimal(12,6)
declare @AmountFinancedInPeriod	decimal(12,2)

declare @CurrBK				varchar(30)

--Delete last month data 
delete from StaticPool_CumulativeLoss 

--Craete Age table 0 - 72
declare @tblAge as table
	(	Age		int	)

set @Age = 0
while @Age <= @AgeCount
begin
	insert into @tblAge 
	select @Age
	set @Age = @Age + 1
end 

--Insert Program, Year, Month, Age to table
insert into StaticPool_CumulativeLoss
select lc.code as 'Program'
     , year(cast(ld2.userdef45 as date)) as 'PurchaseYear'
     , month(cast(ld2.userdef45 as date)) as 'PurchaseMonth'
     , a.Age as 'Age'
     , 'Q' +  cast(datepart(q, cast(ld2.userdef45 as date)) as varchar(1)) as 'PurchaseQuarter'
     , sum(iif((year(@EndDate) - year(cast(ld2.userdef45 as date))) * 12 + (month(@EndDate) - month(cast(ld2.userdef45 as date))) >= a.Age, l.original_note_amount, 0)) as 'AmountFinanced'
     , sum(iif((year(@EndDate) - year(cast(ld2.userdef45 as date))) * 12 + (month(@EndDate) - month(cast(ld2.userdef45 as date))) >= a.Age, 1, 0)) as 'Deals'
	 , 0 as 'ChargeOffAmount'
	 , 0 as 'NetRecovery'
	 , 0 as 'Loss'
	 , 0 as 'AccumulatingLoss'
  from NLS_loanacct l (nolock)
  join NLS_loanacct_detail_2 ld2 (nolock) on ld2.acctrefno = l.acctrefno
  join NLS_loan_class lc (nolock) on lc.codenum = l.loan_class1_no
  join @tblAge a on a.Age between 0 and @AgeCount
 where cast(ld2.userdef45 as date) between @StartDate and @EndDate
   and l.acctrefno not in (select ls.acctrefno  from NLS.dbo.loanacct_statuses ls where ls.status_code_no in (198))	--Exclude UNWIND
 group by  
       lc.code
     , 'Q' +  cast(datepart(q, cast(ld2.userdef45 as date)) as varchar(1))
     , year(cast(ld2.userdef45 as date))
     , month(cast(ld2.userdef45 as date))
     , a.Age
 order by
       Program 
 	 , PurchaseYear
	 , PurchaseMonth
	 , Age

--Update Chargeoff amount
update StaticPool_CumulativeLoss
   set ChargeoffAmount = t1.ChargeoffAmount
  from StaticPool_CumulativeLoss loss
  join (select lc.code as 'Program'
             , year(cast(ld2.userdef45 as date)) as 'PurchaseYear'
             , month(cast(ld2.userdef45 as date)) as 'PurchaseMonth'
             , datediff(month, cast(ld2.userdef45 as date), SVco.CODate) as 'Age'
		  	 , sum(SVco.COGrossAmount)as 'ChargeoffAmount'
		  from NLS_loanacct l (nolock)
		  join NLS_loanacct_detail_2 ld2 (nolock) on ld2.acctrefno = l.acctrefno
		  join NLS_loan_class lc (nolock) on lc.codenum = l.loan_class1_no
		  join [CIG_Service].dbo.Contract SVc (nolock) on cast(SVc.NLSLoanNo as varchar(10)) = l.loan_number
		  join [CIG_Service].dbo.Dealer SVd (nolock) on SVd.DealerId = SVc.DealerId
		  join [CIG_Service].dbo.COContract SVco (nolock) on SVco.ContractId = SVc.ContractId
		 where cast(ld2.userdef45 as date) between @StartDate and @EndDate		--Purchase date afetr 1/1/2010
		   and datediff(month, cast(ld2.userdef45 as date), SVco.CODate) <= @AgeCount	--Chargeoff age less than 72
		 group by
               lc.code
             , year(cast(ld2.userdef45 as date))
             , month(cast(ld2.userdef45 as date))
		  	 , datediff(month, cast(ld2.userdef45 as date), SVco.CODate)
		) t1 on t1.Program = loss.Program 
		    and t1.PurchaseYear = loss.PurchaseYear 
			and t1.PurchaseMonth = loss.PurchaseMonth 
			and t1.Age = loss.Age

--Update Recoveries
update StaticPool_CumulativeLoss
   set NetRecovery = t2.NetRecovery
  from StaticPool_CumulativeLoss loss
  join (select lc.code as 'Program'
             , year(cast(ld2.userdef45 as date)) as 'PurchaseYear'
             , month(cast(ld2.userdef45 as date)) as 'PurchaseMonth'
             , datediff(month, cast(ld2.userdef45 as date), cast(SVcp.EOM_Date as date)) as 'Age'	--Recovery age from purchase
             , sum(isnull(SVcp.TotalRecovery, 0) - isnull(SVcp.TotalExpense, 0)) as 'NetRecovery'
          from NLS_loanacct l (nolock)
		  join NLS_loanacct_detail_2 ld2 (nolock) on ld2.acctrefno = l.acctrefno
		  join NLS_loan_class lc (nolock) on lc.codenum = l.loan_class1_no
          join CIG_Service.dbo.Contract SVc (nolock) on cast(SVc.NLSLoanNo as varchar(10)) = l.loan_number
          join CIG_Service.dbo.Dealer SVd (nolock) on SVd.DealerId = SVc.DealerId
          join CIG_Service.dbo.COContractPeriod SVcp (nolock) on SVcp.ContractId = SVc.ContractId
		 where cast(ld2.userdef45 as date) between @StartDate and @EndDate		--Purchase date afetr 1/1/2010
		   and datediff(month, cast(ld2.userdef45 as date), cast(SVcp.EOM_Date as date)) <= @AgeCount	--Recovery age less than 72
         group by
               lc.code
             , year(cast(ld2.userdef45 as date))
             , month(cast(ld2.userdef45 as date))
             , datediff(month, cast(ld2.userdef45 as date), cast(SVcp.EOM_Date as date))
         having sum(isnull(TotalRecovery, 0) - isnull(TotalExpense, 0)) != 0
		) t2 on t2.Program = loss.Program 
		    and t2.PurchaseYear = loss.PurchaseYear 
			and t2.PurchaseMonth = loss.PurchaseMonth 
			and t2.Age = loss.Age

-----------------------------------------------------------------------------------------------------------------
--Create table for the report by requested summary level
declare @tblLoss table
(	  Program			varchar(20)
	, PurchaseYear		int	
	, PurchaseMonth		int
	, Age				int
	, PurchaseQuarter	varchar(10)
	, Deals				int
	, AmountFinanced	money
	, Loss				money
	, AccumulatingLoss	money
)

insert into @tblLoss
select '' as 'Program'
	 , l.PurchaseYear
	 , l.PurchaseMonth
	 , l.Age
	 , l.PurchaseQuarter as 'PurchaseQuarter'
	 , sum(l.Deals) as 'Deals'
	 , sum(l.AmountFinanced) as 'AmountFinanced'
	 , sum(l.ChargeoffAmount) - sum(l.NetRecovery) as 'Loss'
	 , 0 as 'AccumulatingLoss'
  from StaticPool_CumulativeLoss l
 group by
	   l.PurchaseYear
	 , l.PurchaseMonth
	 , l.PurchaseQuarter
	 , l.Age
 order by 
	   l.PurchaseYear
	 , l.PurchaseMonth
	 , l.Age

--Calculate Loss and Accumulating Loss
declare csrLoss cursor for
select l.Program
     , l.PurchaseYear
	 , l.PurchaseMonth
	 , l.PurchaseQuarter
     , l.Age
	 , l.AmountFinanced
	 , l.Loss
  from @tblLoss l
 order by 
       l.Program
     , l.PurchaseYear
	 , l.PurchaseMonth
	 , l.PurchaseQuarter
     , l.Age

open csrLoss
fetch next from csrLoss into @Program, @PurchaseYear, @PurchaseMonth, @PurchaseQuarter, @Age, @AmountFinanced, @Loss

set @CurrBK = ''

while @@FETCH_STATUS = 0
begin
	--Purchase year month break
	if @CurrBK <> @Program + cast(@PurchaseYear as varchar(4)) + cast(@PurchaseMonth as varchar(2)) + @PurchaseQuarter
	begin 
		set @AccumulatingLoss = 0
        set @AmountFinancedInPeriod = 0
        set @CurrBK = @Program + cast(@PurchaseYear as varchar(4)) + cast(@PurchaseMonth as varchar(2)) + @PurchaseQuarter
	end 

	--If Age is 0, set amount financed for the period
	if @Age = 0
	begin 
		set @AmountFinancedInPeriod = @AmountFinanced
	end 

	set @AccumulatingLoss = @AccumulatingLoss + @Loss

print @Loss
	update @tblLoss
	   set AccumulatingLoss = @AccumulatingLoss
	 where Program = @Program
       and PurchaseYear = @PurchaseYear
	   and PurchaseMonth = @PurchaseMonth
	   and PurchaseQuarter = @PurchaseQuarter
       and Age = @Age

	fetch next from csrLoss into @Program, @PurchaseYear, @PurchaseMonth, @PurchaseQuarter, @Age, @AmountFinanced, @Loss

end 

close csrLoss
deallocate csrLoss

-------------------------------------------------------------------
select l.*
  from @tblLoss l 
 where (year(@EndDate) - l.PurchaseYear) * 12 + (month(@EndDate) - l.PurchaseMonth) >= l.Age
 order by 
       l.PurchaseYear
	 , l.PurchaseMonth
	 , l.PurchaseQuarter
	 , l.Age


END