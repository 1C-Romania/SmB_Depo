
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENTS PROCESSING OF THE OBJECT

Procedure Filling(FillingData, StandardProcessing)
	
	If FillingData = Undefined Then
		NewFinansialYearDateFrom = GetNewFinansialYearDateFrom();
		If NewFinansialYearDateFrom <> '00010101' Then
			DateFrom = NewFinansialYearDateFrom;
		EndIf;	
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	DateTo = EndOfDay(DateTo);
	
	If Not DataExchange.Load Then
				
		If DateTo <= DateFrom Then
			CommonAtClientAtServer.NotifyUser( NStr("en='Date from should be less than date to.';pl='Data rozpoczecia roku finansowego musi być mniejsza od daty zakończenia.';ru='Дата начала финансового года должна быть меньше, чем дата конца.'"),ThisObject,,,Cancel);
		EndIf;
		
		If Cancel Then
			Return;
		EndIf;
		
		If IsNew() Then
			
			NewFinansialYearDateFrom = GetNewFinansialYearDateFrom();
			If NewFinansialYearDateFrom <> '00010101' And NewFinansialYearDateFrom <> DateFrom Then
				CommonAtClientAtServer.NotifyUser( NStr("en='The finansial year should start just after the previous one.';pl='Rok finansowy powinien się zaczynać odrazu po poprzednim.';ru='Новый финансовый год должен начинаться сразу после предыдущего года.'"), ThisObject,,,Cancel);
			EndIf;
			
		Else
			
			If DateFrom <> Ref.DateFrom Then
				CommonAtClientAtServer.NotifyUser( NStr("en='You can set date from only for new finansial year.';pl='Można ustawić datę rozpoczęcia tylko dla nowego roku finansowego.';ru='Дату начала можно установить только для нового финансового года.'"), ThisObject,,,Cancel);
			EndIf;
			
			If DateTo <> Ref.DateTo And Not Catalogs.FinancialYears.IsLastYear(DateFrom) Then
				CommonAtClientAtServer.NotifyUser( NStr("en='You can change date to only for the last finansial year.';pl='Można zmieniać datę do tylko dla ostatniego roku finansowego.';ru='Возможно изменить дату только последнего финансового года.'"), ThisObject,,,Cancel);
			EndIf;
			
		EndIf;
		
		If Cancel Then
			Return;
		EndIf;
		
		Query = New Query;
		Query.Text =  "SELECT TOP 1
		              |	Bookkeeping.Period AS Period
		              |FROM
		              |	AccountingRegister.Bookkeeping AS Bookkeeping
		              |
		              |ORDER BY
		              |	Period DESC";
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			If Selection.Period > EndOfDay(DateTo) Then
				CommonAtClientAtServer.NotifyUser(NStr("en='There are documents after date to. Last document date is';pl='Wprowadzono już dokumenty po dacie do. Data ostatniego dokumentu';ru='Существуют документы с более поздней датой. Дата последнего документа'") + " " + Selection.Period, ThisObject,,,Cancel);
			EndIf;
		EndIf;
		
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	Query = New Query;
	Query.Text =  "SELECT TOP 1
	              |	Bookkeeping.Period AS Period
	              |FROM
	              |	AccountingRegister.Bookkeeping AS Bookkeeping
	              |WHERE
	              |	Bookkeeping.Period BETWEEN &DateFrom AND &DateTo";
	
	Query.SetParameter("DateFrom", DateFrom);
	Query.SetParameter("DateTo", DateTo);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		CommonAtClientAtServer.NotifyUser(NStr("en='There are documents after date to. Last document date is';pl='Wprowadzono już dokumenty po dacie do. Data ostatniego dokumentu';ru='Существуют документы с более поздней датой. Дата последнего документа'") + " " + Selection.Period, ThisObject,,,Cancel);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OTHER PROCEDURES

Function GetNewFinansialYearDateFrom() Export
	
	Query = New Query;
	Query.Text =  "SELECT TOP 1
	              |	FinancialYears.Ref,
	              |	FinancialYears.DateTo AS DateTo
	              |FROM
	              |	Catalog.FinancialYears AS FinancialYears
	              |
	              |ORDER BY
	              |	DateTo DESC";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return EndOfDay(Selection.DateTo) + 1;
	Else
		Return '00010101';
	EndIf;
	
EndFunction


