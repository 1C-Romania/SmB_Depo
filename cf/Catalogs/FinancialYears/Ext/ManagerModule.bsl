Function IsLastYear(Date) Export
	
	Query = New Query;
	Query.Text =  "SELECT TOP 1
	              |	FinancialYears.Ref
	              |FROM
	              |	Catalog.FinancialYears AS FinancialYears
	              |WHERE
	              |	FinancialYears.DateFrom > &DateFrom";
	
	Query.SetParameter("DateFrom", Date);
	Selection = Query.Execute().Select();
	Return Not Selection.Next();
	
EndFunction