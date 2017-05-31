
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Key.IsEmpty() Then
		If Object.DateFrom <> '00010101' Then
			Items.DateFrom.ReadOnly = True;
		EndIf;
	Else
		Items.DateFrom.ReadOnly = True;
		If Not Catalogs.FinancialYears.IsLastYear(Object.DateFrom) Then
			Items.DateTo.ReadOnly = True;
		EndIf;
	EndIf;	

EndProcedure
