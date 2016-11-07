#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Function returns the key of the register record.
//
Function GetRecordKey(ParametersStructure) Export

	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	ProductsAndServicesPricesSliceLast.Period
		|FROM
		|	InformationRegister.ProductsAndServicesPrices.SliceLast(
		|			&ToDate,
		|			PriceKind = &PriceKind
		|				AND ProductsAndServices = &ProductsAndServices
		|				AND Characteristic = &Characteristic) AS ProductsAndServicesPricesSliceLast";
	
	Query.SetParameter("ToDate", 			ParametersStructure.Period);
	Query.SetParameter("ProductsAndServices", 		ParametersStructure.ProductsAndServices);
	Query.SetParameter("Characteristic", 	ParametersStructure.Characteristic);
	Query.SetParameter("PriceKind", 			ParametersStructure.PriceKind);
	
	ReturnStructure = New Structure("RecordExists, Period, PriceKind, ProductsAndServices, Characteristic", False);
	FillPropertyValues(ReturnStructure, ParametersStructure);
	
	ResultTable = Query.Execute().Unload();
	If ResultTable.Count() > 0 Then
		
		ReturnStructure.Period 				= ResultTable[0].Period;
		ReturnStructure.WriteExist		= True;
		
	EndIf; 

	Return ReturnStructure;

EndFunction // GetRecordKey()

// Sets register record by transferred data
//
Procedure SetChangeBasicSalesPrice(FillingData) Export
	
	RecordManager = CreateRecordManager();
	FillPropertyValues(RecordManager, FillingData);
	RecordManager.Author = Users.AuthorizedUser();
	RecordManager.Write(True);
	
EndProcedure // SetChangeBasicSalePrice()

// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	
	Return Result;
	
EndFunction // GetLockedObjectAttributes()

#EndRegion

#Region DataImportFromExternalSources

Procedure WhenDefiningDefaultValue(CatalogRef, AttributeName, IncomingData, RowMatched, UpdateData, DefaultValue)
	
	If RowMatched 
		AND Not ValueIsFilled(IncomingData) Then
		
		DefaultValue = CatalogRef[AttributeName];
		
	EndIf;
	
EndProcedure

Procedure OnDefineDataImportSamples(DataLoadSettings, UUID) Export
	
	Sample_xlsx = GetTemplate("DataImportTemplate_xlsx");
	DataImportTemplate_xlsx = PutToTempStorage(Sample_xlsx, UUID);
	DataLoadSettings.Insert("DataImportTemplate_xlsx", DataImportTemplate_xlsx);
	
	DataLoadSettings.Insert("DataImportTemplate_mxl", "DataImportTemplate_mxl");
	
	Sample_csv = GetTemplate("DataImportTemplate_csv");
	DataImportTemplate_csv = PutToTempStorage(Sample_csv, UUID);
	DataLoadSettings.Insert("DataImportTemplate_csv", DataImportTemplate_csv);
	
EndProcedure

Procedure DataImportFieldsFromExternalSource(ImportFieldsTable, FillingObjectFullName) Export
	
	//
	// The group of fields complies with rule: at least one field in the group must be selected in columns
	//
	
	TypeDescriptionString25 = New TypeDescription("String", , , , New StringQualifiers(25));
	TypeDescriptionString100 = New TypeDescription("String", , , , New StringQualifiers(100));
	TypeDescriptionString200 = New TypeDescription("String", , , , New StringQualifiers(200));
	TypeDescriptionNumber15_2 = New TypeDescription("Number", , , , New NumberQualifiers(15, 2, AllowedSign.Nonnegative));
	TypeDescriptionDate = New TypeDescription("Date", , , , New DateQualifiers(DateFractions.Date));
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsAndServices");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Barcode", 	"Barcode", 	TypeDescriptionString200, TypeDescriptionColumn, "ProductsAndServices", 1, , True);
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "SKU", 	"SKU", 		TypeDescriptionString25, TypeDescriptionColumn, "ProductsAndServices", 2, , True);
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsAndServicesDescription","Products and services (name)", TypeDescriptionString100, TypeDescriptionColumn, "ProductsAndServices", 3, , True);
	
	If GetFunctionalOption("UseCharacteristics") Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsAndServicesCharacteristics");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Characteristic", "Characteristic (name)", TypeDescriptionString25, TypeDescriptionColumn);
		
	EndIf;
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.UOMClassifier");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "MeasurementUnit", "Unit of Measure", TypeDescriptionString25, TypeDescriptionColumn);
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.PricesKinds");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "PriceKind", "Price kind (description)", TypeDescriptionString100, TypeDescriptionColumn);
	
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Price", "Price", TypeDescriptionString25, TypeDescriptionNumber15_2, , , True);
	
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Date", "Date (start of use)", TypeDescriptionString25, TypeDescriptionDate);
	
EndProcedure

Procedure MatchImportedDataFromExternalSource(DataMatchingTable, AdditionalParameters) Export
	
	UpdateData = AdditionalParameters.DataLoadSettings.UpdateExisting;
	
	// DataMatchingTable - Type FormDataCollection
	For Each FormTableRow IN DataMatchingTable Do
		
		// Products and services by Barcode, SKU, Description
		DataImportFromExternalSourcesOverridable.CompareProductsAndServices(FormTableRow.ProductsAndServices, FormTableRow.Barcode, FormTableRow.SKU, FormTableRow.ProductsAndServicesDescription);
		ThisStringIsMapped = ValueIsFilled(FormTableRow.ProductsAndServices);
		
		If GetFunctionalOption("UseCharacteristics") Then
			
			If ThisStringIsMapped Then
				
				// Characteristic by Owner and Name
				DataImportFromExternalSourcesOverridable.MapCharacteristic(FormTableRow.Characteristic, FormTableRow.ProductsAndServices, FormTableRow.Barcode, FormTableRow.Characteristic_IncomingData);
				
			EndIf;
			
		EndIf;
		
		// MeasurementUnits by Description (also consider the option to bind user MU)
		DefaultValue = Catalogs.UOMClassifier.pcs;
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "MeasurementUnit", FormTableRow.MeasurementUnit_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.MapUOM(FormTableRow.ProductsAndServices, FormTableRow.MeasurementUnit, FormTableRow.MeasurementUnit_IncomingData, DefaultValue);
		
		// PriceKinds by description
		DefaultValue = Catalogs.Counterparties.GetMainKindOfSalePrices();
		DataImportFromExternalSourcesOverridable.MapPriceKind(FormTableRow.PriceKind, FormTableRow.PriceKind_IncomingData, DefaultValue);
		
		// Price
		DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.Price, FormTableRow.Price_IncomingData);
		
		// Date
		DataImportFromExternalSourcesOverridable.ConvertStringToDate(FormTableRow.Date, FormTableRow.Date_IncomingData);
		If Not ValueIsFilled(FormTableRow.Date) Then
			
			FormTableRow.Date = BegOfDay(CurrentDate());
			
		EndIf;
		
		CheckDataCorrectnessInTableRow(FormTableRow);
		
	EndDo;
	
EndProcedure

Procedure CheckDataCorrectnessInTableRow(FormTableRow, FillingObjectFullName = "") Export
	
	ServiceFieldName = DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible();
	FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.PriceKind)
		AND Not FormTableRow.PriceKind.CalculatesDynamically
		AND ValueIsFilled(FormTableRow.ProductsAndServices)
		AND FormTableRow.Price > 0
		AND ValueIsFilled(FormTableRow.MeasurementUnit)
		AND ValueIsFilled(FormTableRow.Date)
		;
	
	If FormTableRow[ServiceFieldName] Then
		
		RecordSet = InformationRegisters.ProductsAndServicesPrices.CreateRecordSet();
		RecordSet.Filter.Period.Set(BegOfDay(FormTableRow.Date));
		RecordSet.Filter.PriceKind.Set(FormTableRow.PriceKind);
		RecordSet.Filter.ProductsAndServices.Set(FormTableRow.ProductsAndServices);
		
		If GetFunctionalOption("UseCharacteristics") Then
			
			RecordSet.Filter.Characteristic.Set(FormTableRow.Characteristic);
			
		EndIf;
		
		RecordSet.Read();
		
		FormTableRow._RowMatched = (RecordSet.Count() > 0);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf