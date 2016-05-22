#Region ExportImportDataInService

// Procedure-processor of the BeforeObjectImport for the data
// export/import mechanism in the Parameters description service see commentary to DataExportImportOverridable.OnDataImportHandlersRegistration
// 
Procedure BeforeObjectImport(Container, Object, Artifacts, Cancel) Export
	
	// Disable registration of counterparties duplicates on data load/export in service
	If TypeOf(Object) = Type("CatalogObject.Counterparties") Then
		Object.AdditionalProperties.Insert("RegisterCounterpartiesDuplicates", False);
	ElsIf TypeOf(Object) = Type("CatalogObject.AutomaticDiscounts") Then
		Object.AdditionalProperties.Insert("RegisterServiceAutomaticDiscounts", False);
	EndIf; 
	
EndProcedure

#EndRegion
