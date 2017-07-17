#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Event handler procedure ChoiceDataGetProcessor.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
		
		If ValueIsFilled(Parameters.Filter.Owner) Then
			
			OwnerType = Parameters.Filter.Owner.ProductsAndServicesType;
			
			If (OwnerType = Enums.ProductsAndServicesTypes.Operation
				OR OwnerType = Enums.ProductsAndServicesTypes.WorkKind
				OR OwnerType = Enums.ProductsAndServicesTypes.Service
				OR (NOT Constants.FunctionalOptionUseSubsystemProduction.Get() AND OwnerType = Enums.ProductsAndServicesTypes.InventoryItem)
				OR (NOT Constants.FunctionalOptionUseWorkSubsystem.Get() AND OwnerType = Enums.ProductsAndServicesTypes.Work)) Then
			
				Message = New UserMessage();
				LabelText = NStr("en='BOM is not specified for products and services of the %EtcProductsAndServices% type.';ru='Для номенклатуры типа %ТПНоменклатура% спецификация не указывается!'");
				LabelText = StrReplace(LabelText, "%EtcProductsAndServices%", OwnerType);
				Message.Text = LabelText;
				Message.Message();
				Cancel = True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure // ChoiceDataGetProcessor()

#EndRegion

#Region DataImportFromExternalSources

Procedure DataImportFieldsFromExternalSource(ImportFieldsTable, FillingObjectFullName) Export
	
	//
	// The group of fields complies with rule: at least one field in the group must be selected in columns
	//
	
	TypeDescriptionString25 = New TypeDescription("String", , , , New StringQualifiers(25));
	TypeDescriptionString100 = New TypeDescription("String", , , , New StringQualifiers(100));
	TypeDescriptionString150 = New TypeDescription("String", , , , New StringQualifiers(150));
	TypeDescriptionString200 = New TypeDescription("String", , , , New StringQualifiers(200));
	TypeDescriptionNumber15_2 = New TypeDescription("Number", , , , New NumberQualifiers(15, 2, AllowedSign.Nonnegative));
	TypeDescriptionNumber15_3 = New TypeDescription("Number", , , , New NumberQualifiers(15, 3, AllowedSign.Nonnegative));
	
	TypeDescriptionColumn = New TypeDescription("EnumRef.SpecificationContentRowTypes");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ContentRowType", "Row type", TypeDescriptionString25, TypeDescriptionColumn);
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsAndServices");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Barcode", "Barcode", TypeDescriptionString200, TypeDescriptionColumn, "ProductsAndServices", 1, , True);
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "SKU", "SKU", TypeDescriptionString25, TypeDescriptionColumn, "ProductsAndServices", 2, , True);
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsAndServicesDescription", "Products and services (name)", TypeDescriptionString100, TypeDescriptionColumn, "ProductsAndServices", 3, , True);
	
	If GetFunctionalOption("UseCharacteristics") Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsAndServicesCharacteristics");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Characteristic", "Characteristic (name)", TypeDescriptionString150, TypeDescriptionColumn);
		
	EndIf;
	
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Quantity", "Quantity", TypeDescriptionString25, TypeDescriptionNumber15_3, , , True);
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.UOMClassifier");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "MeasurementUnit", "Unit of Measure", TypeDescriptionString25, TypeDescriptionColumn);
	
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CostPercentage", "Cost percentage", TypeDescriptionString25, TypeDescriptionNumber15_2);
	
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsQuantity", "Quantity of finished goods", TypeDescriptionString25, TypeDescriptionNumber15_3);
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.Specifications");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Specification", "Specification (description)", TypeDescriptionString100, TypeDescriptionColumn);
	
EndProcedure

Procedure OnDefineDataImportSamples(DataLoadSettings, UUID) Export
	
	Sample_csv = GetTemplate("DataImportTemplate_csv");
	DataImportTemplate_csv = PutToTempStorage(Sample_csv, UUID);
	DataLoadSettings.Insert("DataImportTemplate_csv", DataImportTemplate_csv);
	
	DataLoadSettings.Insert("DataImportTemplate_mxl", "DataImportTemplate_mxl");
	
	Sample_xlsx = GetTemplate("DataImportTemplate_xlsx");
	DataImportTemplate_xlsx = PutToTempStorage(Sample_xlsx, UUID);
	DataLoadSettings.Insert("DataImportTemplate_xlsx", DataImportTemplate_xlsx);
	
EndProcedure

Procedure MatchImportedDataFromExternalSource(DataMatchingTable, AdditionalParameters) Export
	
	// DataMatchingTable - Type FormDataCollection
	For Each FormTableRow IN DataMatchingTable Do
		
		// Products and services by Barcode, SKU, Description
		DataImportFromExternalSourcesOverridable.CompareProductsAndServices(FormTableRow.ProductsAndServices, FormTableRow.Barcode, FormTableRow.SKU, FormTableRow.ProductsAndServicesDescription);
		
		// StringType by StringType.Description
		DataImportFromExternalSourcesOverridable.MapRowType(FormTableRow.ContentRowType, FormTableRow.ContentRowType_IncomingData, Enums.SpecificationContentRowTypes.Material);
		
		If GetFunctionalOption("UseCharacteristics") Then
			
			If ValueIsFilled(FormTableRow.ProductsAndServices) Then
				
				// Characteristic by Owner and Name
				DataImportFromExternalSourcesOverridable.MapCharacteristic(FormTableRow.Characteristic, FormTableRow.ProductsAndServices, FormTableRow.Barcode, FormTableRow.Characteristic_IncomingData);
				
			EndIf;
			
		EndIf;
		
		// Quantity
		DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.Quantity, FormTableRow.Quantity_IncomingData, 1);
		
		// UOM by Description 
		DefaultValue = ?(ValueIsFilled(FormTableRow.ProductsAndServices), FormTableRow.ProductsAndServices.MeasurementUnit, Catalogs.UOMClassifier.pcs);
		DataImportFromExternalSourcesOverridable.MapUOM(FormTableRow.ProductsAndServices, FormTableRow.MeasurementUnit, FormTableRow.MeasurementUnit_IncomingData, DefaultValue);
		
		// Cost percentage
		DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.CostPercentage, FormTableRow.CostPercentage_IncomingData, 1);
		
		// Quantity of finished goods
		DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.ProductsQuantity, FormTableRow.ProductsQuantity_IncomingData, 1);
		
		// Specifications by owner, description
		DataImportFromExternalSourcesOverridable.MapSpecification(FormTableRow.Specification, FormTableRow.Specification_IncomingData, FormTableRow.ProductsAndServices);
		
		CheckDataCorrectnessInTableRow(FormTableRow);
		
	EndDo;
	
EndProcedure

Procedure CheckDataCorrectnessInTableRow(FormTableRow, FillingObjectFullName = "") Export
	
	ServiceFieldName = DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible();
	
	FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.ProductsAndServices) 
		AND  ValueIsFilled(FormTableRow.ContentRowType) 
		AND FormTableRow.Quantity <> 0;
	
EndProcedure

#EndRegion

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf
