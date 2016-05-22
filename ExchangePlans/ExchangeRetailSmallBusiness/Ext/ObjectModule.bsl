#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Procedure - event handler "BeforeWrite".
//
Procedure BeforeWrite(Cancel)
	
	If Not UseCompaniesFilter Then
		Companies.Clear();
	EndIf;
	If Not UseFilterByWarehouses Then
		Warehouses.Clear();
	EndIf;
	ExportModeOnDemand = Enums.ExchangeObjectsExportModes.ExportIfNecessary;
	
EndProcedure

#EndIf
