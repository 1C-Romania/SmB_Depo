#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure BeforeWrite(Cancel)
	
	If IsNew() Then
		
		If Not UseCompaniesFilter AND Companies.Count() <> 0 Then
			Companies.Clear();
		ElsIf Companies.Count() = 0 AND UseCompaniesFilter Then
			UseCompaniesFilter = False;
		EndIf;
		
		If Not UseDocumentTypesFilter AND DocumentKinds.Count() <> 0 Then
			DocumentKinds.Clear();
		ElsIf DocumentKinds.Count() = 0 AND UseDocumentTypesFilter Then
			UseDocumentTypesFilter = False;
		EndIf;
		
		If Not ValueIsFilled(ExportModeOnDemand) Then
			ExportModeOnDemand = Enums.ExchangeObjectsExportModes.ExportIfNecessary;
		EndIf;
		
		If ManualExchange Then
			SynchronizationModeData = Enums.ExchangeObjectsExportModes.ExportManually;
		Else
			SynchronizationModeData = Enums.ExchangeObjectsExportModes.AlwaysExport;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndIf
