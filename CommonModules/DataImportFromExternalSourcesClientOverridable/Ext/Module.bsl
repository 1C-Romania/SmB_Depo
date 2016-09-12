Procedure FillInParentFieldInDataMappingTable(Value, DataMatchingTable, DataLoadSettings)
	
	If DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties" Then
		
		CheckedFieldName = "Counterparty";
		PopulatedFieldName = "Parent";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.ProductsAndServices" Then
		
		CheckedFieldName = "ProductsAndServices";
		PopulatedFieldName = "Parent";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "InformationRegister.ProductsAndServicesPrices" Then
		
		CheckedFieldName = "PriceKind";
		PopulatedFieldName = "PriceKind";
		
	EndIf;

	For Each TableRow IN DataMatchingTable Do
		
		If PopulatedFieldName = "Parent" Then
			
			CommonValueIsFilled = ValueIsFilled(TableRow[CheckedFieldName]);
			If Not CommonValueIsFilled Then
				
				TableRow[PopulatedFieldName] = Value;
				
			EndIf;
			
		ElsIf PopulatedFieldName = "PriceKind" Then
			
			TableRow[PopulatedFieldName] = Value;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure OnSetGeneralValue(Form, DataLoadSettings, DataMatchingTable) Export
	
	AdditionalSettings = New Structure("Form, DataLoadSettings, DataMatchingTable", Form, DataLoadSettings, DataMatchingTable);
	NotifyDescription 		= New NotifyDescription("WhenProcessingCommonValueSelectionResult", ThisObject, AdditionalSettings);
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Multiselect", False);
	OpenParameters.Insert("CloseOnChoice", True);
	OpenParameters.Insert("ChoiceFoldersAndItems", FoldersAndItems.Folders);
	
	If DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties" Then
		
		GroupChoiceFormName = "Catalog.Counterparties.FolderChoiceForm";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.ProductsAndServices" Then
		
		GroupChoiceFormName = "Catalog.ProductsAndServices.FolderChoiceForm";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "InformationRegister.ProductsAndServicesPrices" Then
		
		OpenParameters.ChoiceFoldersAndItems = FoldersAndItems.Items;
		GroupChoiceFormName = "Catalog.PriceKinds.ChoiceForm";
		
	EndIf;
	
	OpenForm(GroupChoiceFormName, OpenParameters, ThisObject, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

Procedure OnClearGeneralValue(Form, DataLoadSettings, DataMatchingTable) Export
	
	If DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties" 
		OR DataLoadSettings.FillingObjectFullName = "Catalog.ProductsAndServices" Then
		
		Form.Items.CommonValueCatalog.Title = NStr("en='< not indicated  >';ru='< не указана >'");
		FillInParentFieldInDataMappingTable(Undefined, DataMatchingTable, DataLoadSettings);
		
	ElsIf DataLoadSettings.FillingObjectFullName = "InformationRegister.ProductsAndServicesPrices" Then
		
		Form.Items.CommonValueIR.Title = NStr("en='< not indicated  >';ru='< не указана >'");
		FillInParentFieldInDataMappingTable(DataImportFromExternalSourcesOverridable.DefaultPriceKind(), DataMatchingTable, DataLoadSettings);
		
	EndIf;
	
EndProcedure

Procedure WhenProcessingCommonValueSelectionResult(Result, AdditionalSettings) Export
	
	Form = AdditionalSettings.Form;
	DataLoadSettings = AdditionalSettings.DataLoadSettings;
	DataMatchingTable = AdditionalSettings.DataMatchingTable;
	
	If DataMatchingTable.Count() > 0 
		AND ValueIsFilled(Result) Then
		
		FillInParentFieldInDataMappingTable(Result, DataMatchingTable, DataLoadSettings);
		If DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties"
			OR DataLoadSettings.FillingObjectFullName = "Catalog.ProductsAndServices" Then
			
			Form.Items.CommonValueCatalog.Title = NStr("en='< ';ru='< '") + String(Result) + NStr("en=' >';ru=' >'");
			
		ElsIf DataLoadSettings.FillingObjectFullName = "InformationRegister.ProductsAndServicesPrices" Then
			
			Form.Items.CommonValueIR.Title = NStr("en='< ';ru='< '") + String(Result) + NStr("en=' >';ru=' >'");
			
		EndIf;
		
	EndIf;
	
EndProcedure
