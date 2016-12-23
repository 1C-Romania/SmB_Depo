
&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences);
	
	// StandardSubsystems.GroupObjectsChange
	If Items.Find("ListBatchObjectChanging") <> Undefined Then
		
		YouCanEdit = AccessRight("Edit", Metadata.Catalogs.ProductsAndServices);
		CommonUseClientServer.SetFormItemProperty(Items, "ListBatchObjectChanging", "Visible", YouCanEdit);
		
	EndIf;
	// End StandardSubsystems.GroupObjectChange
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.ProductsAndServices, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
EndProcedure // OnCreateAtServer()

&AtClient
Procedure ChangeSelected(Command)
	
	GroupObjectsChangeClient.ChangeSelected(Items.List);
	
EndProcedure

&AtClient
Procedure Attachable_ClickOnInformationLink(Item)
	
	InformationCenterClient.ClickOnInformationLink(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ReferenceClickAllInformationLinks(Item)
	
	InformationCenterClient.ReferenceClickAllInformationLinks(ThisForm.FormName);
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.DataImportFromExternalSources
&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TemplateNameWithTemplate", "LoadFromFile");
	DataLoadSettings.Insert("SelectionRowDescription", New Structure("FullMetadataObjectName, Type", "ProductsAndServices", "AppliedImport"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		If ImportResult.ActionsDetails = "ChangeDataImportFromExternalSourcesMethod" Then
		
			DataImportFromExternalSources.ChangeDataImportFromExternalSourcesMethod(DataLoadSettings.DataImportFormNameFromExternalSources);
			
			NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
			DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
			
		ElsIf ImportResult.ActionsDetails = "ProcessPreparedData" Then
			
			ProcessPreparedData(ImportResult);
			Items.List.Refresh();
			ShowMessageBox(,NStr("en='The data import is completed.';ru='Загрузка данных завершена.'"));
			
		EndIf;
		
	ElsIf ImportResult = Undefined Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	Try
		
		BeginTransaction();
		
		UpdateExisting = ImportResult.DataLoadSettings.UpdateExisting;
		CreateIfNotMatched = ImportResult.DataLoadSettings.CreateIfNotMatched;
		DataMatchingTable = ImportResult.DataMatchingTable;
		For Each TableRow IN DataMatchingTable Do
			
			ImportToApplicationIsPossible = TableRow[DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible()];
			
			CoordinatedStringStatus = (TableRow._RowMatched AND UpdateExisting) 
				OR (NOT TableRow._RowMatched AND CreateIfNotMatched);
			
			If ImportToApplicationIsPossible AND CoordinatedStringStatus Then
				
				If TableRow._RowMatched Then
					
					CatalogItem = TableRow.ProductsAndServices.GetObject();
					
				Else
					
					CatalogItem = Catalogs.ProductsAndServices.CreateItem();
					CatalogItem.Parent = TableRow.Parent;
					
				EndIf;
				
				CatalogItem.Description = TableRow.ProductsAndServicesDescription;
				CatalogItem.DescriptionFull = TableRow.ProductsAndServicesDescription;
				FillPropertyValues(CatalogItem, TableRow, , "Code, Parent");
				CatalogItem.Write();
				
			EndIf;
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		WriteLogEvent(NStr("en='Data Import';ru='Загрузка данных'"), EventLogLevel.Error, Metadata.Catalogs.ProductsAndServices, , ErrorDescription());
		RollbackTransaction();
		
	EndTry;
	
EndProcedure
// End StandardSubsystems.DataImportFromExternalSource

// StandardSubsystems.PerformanceEstimation
&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If Not Group Then
		KeyOperation = "FormCreatingProductsAndServices";
		PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	EndIf;

EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	If Not Item.CurrentData.IsFolder Then
		KeyOperation = "FormOpeningProductsAndServices";
		PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	EndIf;
	
EndProcedure
// End StandardSubsystems.PerformanceEstimation

#EndRegion














