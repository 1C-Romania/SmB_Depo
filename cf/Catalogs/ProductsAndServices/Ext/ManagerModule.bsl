#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	Result.Add("ProductsAndServicesType");
	
	Return Result;
	
EndFunction // GetLockedObjectAttributes()

// Returns the list of
// attributes allowed to be changed with the help of the group change data processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	EditableAttributes = New Array;
	
	EditableAttributes.Add("ProductsAndServicesType");
	EditableAttributes.Add("EstimationMethod");
	EditableAttributes.Add("VATRate");
	EditableAttributes.Add("BusinessActivity");
	EditableAttributes.Add("Warehouse");
	EditableAttributes.Add("Cell");
	EditableAttributes.Add("InventoryGLAccount");
	EditableAttributes.Add("ExpensesGLAccount");
	EditableAttributes.Add("ProductsAndServicesCategory");
	EditableAttributes.Add("PriceGroup");
	EditableAttributes.Add("CountryOfOrigin");
	EditableAttributes.Add("ReplenishmentMethod");
	EditableAttributes.Add("ReplenishmentDeadline");
	EditableAttributes.Add("Vendor");

	
	Return EditableAttributes;
	
EndFunction

// Returns the basic sale price for the specified items by the specified price kind.
//
// Products and services (Catalog.ProductsAndServices) - products and services which price shall be calculated (obligatory for filling);
// PriceKind (Catalog.PriceKinds or Undefined) - If Undefined, we calculate the basic price kind using Catalogs.PriceKinds.GetBasicSalePriceKind() method;
//
Function GetMainSalePrice(PriceKind, ProductsAndServices, MeasurementUnit = Undefined) Export
	
	If Not ValueIsFilled(ProductsAndServices) 
		OR Not AccessRight("Read", Metadata.InformationRegisters.ProductsAndServicesPrices) Then
		
		Return 0;
		
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED
	|	ProductsAndServicesPricesSliceLast.Price AS MainSalePrice
	|FROM
	|	InformationRegister.ProductsAndServicesPrices.SliceLast(
	|			,
	|			PriceKind = &PriceKind
	|				AND ProductsAndServices = &ProductsAndServices
	|				AND Characteristic = VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|				AND Actuality
	|				AND &ParameterMeasurementUnit) AS ProductsAndServicesPricesSliceLast");
	
	Query.SetParameter("PriceKind", 
		?(ValueIsFilled(PriceKind), PriceKind, Catalogs.PriceKinds.GetMainKindOfSalePrices())
		);
	
	Query.SetParameter("ProductsAndServices", 
		ProductsAndServices
		);
		
	If ValueIsFilled(MeasurementUnit) Then
		
		Query.Text = StrReplace(Query.Text, "&ParameterMeasurementUnit", "MeasurementUnit = &MeasurementUnit");
		Query.SetParameter("MeasurementUnit", MeasurementUnit);
		
	Else
		
		Query.Text = StrReplace(Query.Text, "&ParameterMeasurementUnit", "TRUE");
		
	EndIf;
	
	Selection = Query.Execute().Select();
	
	Return ?(Selection.Next(), Selection.MainSalePrice, 0);
	
EndFunction //GetBasicSalePrice()

#EndRegion

#Region DataLoadFromFile

// Sets data import from file parameters
//
// Parameters:
//     Parameters - Structure - Parameters list. Fields: 
//         * Title - String - Window title 
//         * MandatoryColumns - Array - List of columns names mandatory for filling
//         * DataTypeColumns - Map, Key - Column name, Value - Data type description 
//
Procedure DefineDataLoadFromFileParameters(Parameters) Export
	
	Parameters.Title = "ProductsAndServices";
	
	TypeDescriptionBarcode =  New TypeDescription("String",,,, New StringQualifiers(13));
	SKUTypeDescription =  New TypeDescription("String",,,, New StringQualifiers(25));
	TypeDescriptionName =  New TypeDescription("String",,,, New StringQualifiers(100));
	Parameters.DataTypeColumns.Insert("Barcode", TypeDescriptionBarcode);
	Parameters.DataTypeColumns.Insert("Description", TypeDescriptionName);

EndProcedure

// Matches imported data to data in IB.
//
// Parameters:
//   ExportableData - ValueTable - values table with the imported data:
//     * MatchedObject   - CatalogRef - Ref to mapped object. Filled in inside the procedure
//     * <other columns> - Arbitrary  - Columns content corresponds to the "LoadFromFile" layout
//
Procedure MapImportedDataFromFile(ExportableData) Export
	
	Query = New Query;
	Query.Text = "SELECT
	               |	ExportableData.Barcode AS Barcode,
	               |	ExportableData.Description AS Description,
	               |	ExportableData.SKU AS SKU,
	               |	ExportableData.ID AS ID
	               |INTO ExportableData
	               |FROM
	               |	&ExportableData AS ExportableData
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	ProductsAndServicesBarcodes.Barcode AS Barcode,
	               |	ProductsAndServicesBarcodes.ProductsAndServices.Ref AS ProductsAndServicesRef,
	               |	ExportableData.ID AS ID
	               |INTO ProductsAndServicesByBarcodes
	               |FROM
	               |	ExportableData AS ExportableData
	               |		LEFT JOIN InformationRegister.ProductsAndServicesBarcodes AS ProductsAndServicesBarcodes
	               |		ON (ProductsAndServicesBarcodes.Barcode LIKE ExportableData.Barcode)
	               |WHERE
	               |	Not ProductsAndServicesBarcodes.ProductsAndServices.Ref IS NULL 
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	ProductsAndServices.Ref AS ProductsAndServicesRef,
	               |	ExportableData.ID AS ID
	               |INTO ProductsAndServicesSKU
	               |FROM
	               |	ExportableData AS ExportableData
	               |		LEFT JOIN Catalog.ProductsAndServices AS ProductsAndServices
	               |			LEFT JOIN ProductsAndServicesByBarcodes AS ProductsAndServicesByBarcodes
	               |			ON (NOT ProductsAndServicesByBarcodes.ProductsAndServicesRef = ProductsAndServices.Ref)
	               |		ON (ProductsAndServices.SKU LIKE ExportableData.SKU)
	               |			AND ((CAST(ProductsAndServices.SKU AS String(25))) <> """")
	               |			AND (NOT ProductsAndServices.SKU IS NULL )
	               |WHERE
	               |	Not ProductsAndServices.Ref IS NULL 
	               |
	               |GROUP BY
	               |	ProductsAndServices.Ref,
	               |	ExportableData.ID
	               |;
	               |
	               |////////////////////////////////////////////////////////////////////////////////
	               |SELECT
	               |	ProductsAndServices.Ref AS Ref,
	               |	ExportableData.ID AS ID,
	               |	ProductsAndServices.ProductsAndServicesType AS ProductsAndServicesType
	               |FROM
	               |	ExportableData AS ExportableData
	               |		LEFT JOIN Catalog.ProductsAndServices AS ProductsAndServices
	               |			LEFT JOIN ProductsAndServicesByBarcodes AS ProductsAndServicesByBarcodes
	               |			ON (NOT ProductsAndServicesByBarcodes.ProductsAndServicesRef = ProductsAndServices.Ref)
	               |			LEFT JOIN ProductsAndServicesSKU AS ProductsAndServicesSKU
	               |			ON (NOT ProductsAndServicesSKU.ProductsAndServicesRef = ProductsAndServices.Ref)
	               |		ON (ProductsAndServices.Description LIKE ExportableData.Description)
	               |WHERE
	               |	Not ProductsAndServices.Ref IS NULL 
	               |
	               |GROUP BY
	               |	ProductsAndServices.Ref,
	               |	ExportableData.ID
	               |
	               |UNION ALL
	               |
	               |SELECT
	               |	ProductsAndServicesByBarcodes.ProductsAndServicesRef,
	               |	ProductsAndServicesByBarcodes.ID,
	               |	ProductsAndServicesByBarcodes.ProductsAndServicesRef.ProductsAndServicesType AS ProductsAndServicesType
	               |FROM
	               |	ProductsAndServicesByBarcodes AS ProductsAndServicesByBarcodes
	               |
	               |UNION ALL
	               |
	               |SELECT
	               |	ProductsAndServicesSKU.ProductsAndServicesRef,
	               |	ProductsAndServicesSKU.ID,
	               |	ProductsAndServicesSKU.ProductsAndServicesRef.ProductsAndServicesType AS ProductsAndServicesType
	               |FROM
	               |	ProductsAndServicesSKU AS ProductsAndServicesSKU";
	 
	Query.SetParameter("ExportableData", ExportableData);
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		Filter = New Structure("ID", SelectionDetailRecords.ID);
		FoundStrings = ExportableData.FindRows(Filter);
		If FoundStrings.Count() > 0 Then
			For IndexOf = 0 To FoundStrings.Count() -1 Do
				If ValueIsFilled(FoundStrings[IndexOf].ProductsAndServicesType) Then 
					ProductsAndServicesType = Undefined;
					For Each ProductsAndServicesTypeMetadata IN Enums.ProductsAndServicesTypes.EmptyRef().Metadata().EnumValues Do
						If ProductsAndServicesTypeMetadata.Name = FoundStrings[IndexOf].ProductsAndServicesType Then
							ProductsAndServicesType = Enums.ProductsAndServicesTypes[ProductsAndServicesTypeMetadata.Name];
							Break;
						EndIf;
					EndDo;
					
					If ProductsAndServicesType <> Undefined AND SelectionDetailRecords.ProductsAndServicesType = ProductsAndServicesType Then
						FoundStrings[IndexOf].MappingObject = SelectionDetailRecords.Ref;
					EndIf;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

Function ValueCatalog(CatalogName, ImportedValue, DefaultValue = Undefined)
	
	Result = ?(ValueIsFilled(ImportedValue), 
		Catalogs[CatalogName].FindByDescription(ImportedValue), DefaultValue);
	If Not ValueIsFilled(Result) Then
		Return DefaultValue;
	EndIf;
	
	Return Result;

EndFunction

Function EnumValue(EnumerationName, ImportedValue, DefaultValue = Undefined)
	
	For Each EnumsVariant IN Enums[EnumerationName] Do
		If String(EnumsVariant) = ImportedValue Then
			Return EnumsVariant;
		EndIf;
	EndDo;
	
	Result = Metadata.Enums[EnumerationName].EnumValues.Find(ImportedValue);
	If Result <> Undefined Then
		Return Enums[EnumerationName][Result.Name];
	EndIf;
	
	Return DefaultValue;

EndFunction

Function ValueAccount(ImportedValue, DefaultValue)
	
	If ValueIsFilled(ImportedValue) Then
		Result = ChartsOfAccounts.Managerial.FindByCode(ImportedValue);
		If Not ValueIsFilled(Result) Then
			Result = ChartsOfAccounts.Managerial.FindByDescription(ImportedValue);
		EndIf;
	Else
		Return DefaultValue;
	EndIf;
	
	If ValueIsFilled(Result) Then
		Return Result;
	EndIf;
	
	Return DefaultValue;
	
EndFunction

// Data import from the file
//
// Parameters:
//   ExportableData - ValuesTable with columns:
//     * MatchedObject       - CatalogRef - Ref to the matched object
//     * StringMatchResult   - String     - Update status, possible options: Created, Updated, Skipped
//     * ErrorDescription    - String     - decryption of data import error
//     * Identifier          - Number     - String unique number 
//     * <other columns>     - Arbitrary  - Imported file strings according to the layout
// ImportParameters    - Structure    - Import parameters 
//     * CreateNew     - Boolean      - It is required to create catalog new items
//     * ZeroExisting  - Boolean      - Whether it is required to update catalog items
// Denial              - Boolean       - Cancel import
Procedure LoadFromFile(ExportableData, ImportParameters, Cancel) Export
	
	SpecificationIsImported = ?(ExportableData.Columns.Find("Specification") <> Undefined, True, False);
	ReplenishmentMethodIsImported = ?(ExportableData.Columns.Find("ReplenishmentMethod")<> Undefined, True, False);
	BusinessActivityIsImported = ?(ExportableData.Columns.Find("BusinessActivity")<> Undefined, True, False);
	
	For Each TableRow IN ExportableData Do
		Try
			If Not ValueIsFilled(TableRow.MappingObject) Then
				If ImportParameters.CreateNew Then 
					BeginTransaction();
					CatalogItem = Catalogs.ProductsAndServices.CreateItem();
					
					CatalogItem.Fill(TableRow);
					TableRow.MappingObject = CatalogItem;
					TableRow.RowMatchResult = "Created";
				Else
					TableRow.RowMatchResult = "Skipped";
					Continue;
				EndIf;
			Else
				If Not ImportParameters.UpdateExisting Then 
					TableRow.RowMatchResult = "Skipped";
					Continue;
				EndIf;
				
				BeginTransaction();
				Block = New DataLock;
				LockItem = Block.Add("Catalog.ProductsAndServices");
				LockItem.SetValue("Ref", TableRow.MappingObject);
				
				CatalogItem = TableRow.MappingObject.GetObject();
				
				TableRow.RowMatchResult = "Updated";
				
				If CatalogItem = Undefined Then
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Products and services with %1 name does not exist.';ru='Номенклатура с наименованием ""%1"" не существует.'"), TableRow.Description);
					Raise MessageText;
				EndIf;
			EndIf;
			
			CatalogItem.Description = TableRow.Description;
			
			If ValueIsFilled(TableRow.CountryOfOrigin) Then
				CatalogItem.CountryOfOrigin = Catalogs.WorldCountries.FindByDescription(TableRow.CountryOfOrigin);
			EndIf;
			
			Parent = Catalogs.ProductsAndServices.FindByDescription(TableRow.Parent, True);
			If Not IsBlankString(TableRow.Parent) Then
				If Parent = Undefined
					OR Parent.IsFolder = False
					OR Parent.IsEmpty() = True Then
					Parent = Catalogs.ProductsAndServices.CreateFolder();
					Parent.Description = TableRow.Parent;
					Parent.Write();
				EndIf;
				
				CatalogItem.Parent = Parent.Ref;
			EndIf;
			
			// functional option
			If SpecificationIsImported AND ValueIsFilled(TableRow.Specification) Then
				CatalogItem.Specification = Catalogs.Specifications.FindByDescription(TableRow.Specification,,, CatalogItem.Ref);
			EndIf;
			
			// functional option
			If ReplenishmentMethodIsImported Then
				CatalogItem.ReplenishmentMethod = EnumValue("InventoryReplenishmentMethods", TableRow.ReplenishmentMethod, 
					Enums.InventoryReplenishmentMethods.Purchase);
				EndIf;
				
			If BusinessActivityIsImported Then
				CatalogItem.BusinessActivity =  ValueCatalog("BusinessActivities", TableRow.BusinessActivity, Catalogs.BusinessActivities.MainActivity);
			EndIf;
			
			CatalogItem.Warehouse               = ValueCatalog("StructuralUnits", TableRow.Warehouse, Catalogs.StructuralUnits.MainWarehouse);
			CatalogItem.PriceGroup        = ValueCatalog("PriceGroups", TableRow.PriceGroup, Catalogs.PriceGroups.EmptyRef());
			CatalogItem.ProductsAndServicesType      = EnumValue("ProductsAndServicesTypes", TableRow.ProductsAndServicesType);
			CatalogItem.VATRate            = ValueCatalog("VATRates", TableRow.VATRate, Catalogs.Companies.MainCompany.DefaultVATRate);
			CatalogItem.Vendor            = ValueCatalog("Counterparties", TableRow.Vendor);
			CatalogItem.ProductsAndServicesCategory = ValueCatalog("ProductsAndServicesCategories", TableRow.ProductsAndServicesCategory, Catalogs.ProductsAndServicesCategories.MainGroup);
			CatalogItem.EstimationMethod          = EnumValue("InventoryValuationMethods", TableRow.EstimationMethod,  Enums.InventoryValuationMethods.ByAverage);
			CatalogItem.DescriptionFull   = ?(ValueIsFilled(TableRow.DescriptionFull), TableRow.DescriptionFull, TableRow.Description);
			
			// Unit of measure
			MeasurementUnit = ValueCatalog("UOMClassifier", TableRow.MeasurementUnit, Undefined);
			If Not ValueIsFilled(MeasurementUnit) Then
				MeasurementUnit = Catalogs.UOM.FindByDescription(TableRow.MeasurementUnit, False, , CatalogItem.Ref);
				If Not ValueIsFilled(MeasurementUnit) Then
					MeasurementUnit = Catalogs.UOMClassifier.pcs
				EndIf;
			EndIf;
			CatalogItem.MeasurementUnit = MeasurementUnit;
			
			CatalogItem.SKU = TableRow.SKU;
			CatalogItem.Comment = TableRow.Definition;
			
			CatalogItem.InventoryGLAccount = ValueAccount(TableRow.InventoryGLAccount, ChartsOfAccounts.Managerial.RawMaterialsAndMaterials);
			CatalogItem.ExpensesGLAccount =  ValueAccount(TableRow.ExpensesGLAccount, ChartsOfAccounts.Managerial.IndirectExpenses);
			
			If CatalogItem.CheckFilling() Then 
				CatalogItem.Write();
				TableRow.MappingObject = CatalogItem.Ref;
				
				// Add bar code
				If ValueIsFilled(TableRow.Barcode) Then
					ProductsAndServicesBarcode = InformationRegisters.ProductsAndServicesBarcodes.CreateRecordManager();
					ProductsAndServicesBarcode.Barcode = TableRow.Barcode;
					ProductsAndServicesBarcode.Period = CurrentDate();
					ProductsAndServicesBarcode.ProductsAndServices = CatalogItem.Ref;
					ProductsAndServicesBarcode.Write();
				EndIf;
				
				CommitTransaction();
				Continue;
			Else
				RollbackTransaction();
				TableRow.RowMatchResult = "Skipped";
				
				UserMessages = GetUserMessages(True);
				If UserMessages.Count()>0 Then 
					MessagesText = "";
					For Each UserMessage IN UserMessages Do
						MessagesText  = MessagesText + UserMessage.Text + Chars.LF;
					EndDo;
					TableRow.ErrorDescription = MessagesText;
				EndIf;
			EndIf;
			
		Except
			Cause = BriefErrorDescription(ErrorInfo());
			RollbackTransaction();
			TableRow.RowMatchResult = "Skipped";
			TableRow.ErrorDescription = "Unable to write as the data is incorrect.";
		EndTry;
	EndDo;
EndProcedure

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
	
	TypeDescriptionString11 = New TypeDescription("String", , , , New StringQualifiers(11));
	TypeDescriptionString25 = New TypeDescription("String", , , , New StringQualifiers(25));
	TypeDescriptionString50 = New TypeDescription("String", , , , New StringQualifiers(50));
	TypeDescriptionString100 = New TypeDescription("String", , , , New StringQualifiers(100));
	TypeDescriptionString150 = New TypeDescription("String", , , , New StringQualifiers(150));
	TypeDescriptionString200 = New TypeDescription("String", , , , New StringQualifiers(200));
	TypeDescriptionNumber10_0 = New TypeDescription("Number", , , , New NumberQualifiers(10, 0, AllowedSign.Nonnegative));
	TypeDescriptionNumber10_3 = New TypeDescription("Number", , , , New NumberQualifiers(10, 3, AllowedSign.Nonnegative));
	TypeDescriptionNumber15_2 = New TypeDescription("Number", , , , New NumberQualifiers(15, 2, AllowedSign.Nonnegative));
	TypeDescriptionNumber15_3 = New TypeDescription("Number", , , , New NumberQualifiers(15, 3, AllowedSign.Nonnegative));
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsAndServices");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Parent", "Group", TypeDescriptionString100, TypeDescriptionColumn, , , , );
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsAndServices");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Code", 		"Code", 			TypeDescriptionString11, TypeDescriptionColumn, "ProductsAndServices", 1, , True);
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Barcode", 	"Barcode", 	TypeDescriptionString200, TypeDescriptionColumn, "ProductsAndServices", 2, , True);
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "SKU", 	"SKU", 		TypeDescriptionString25, TypeDescriptionColumn, "ProductsAndServices", 3, , True);
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsAndServicesDescription","Products and services (name)", TypeDescriptionString100, TypeDescriptionColumn, "ProductsAndServices", 4, True, True);
	// DescriptionFull
	
	TypeDescriptionColumn = New TypeDescription("EnumRef.ProductsAndServicesTypes");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsAndServicesType", "Products and services type", TypeDescriptionString11, TypeDescriptionColumn);
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.UOMClassifier");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "MeasurementUnit", "Unit of Measure", TypeDescriptionString25, TypeDescriptionColumn);
	
	TypeDescriptionColumn = New TypeDescription("EnumRef.InventoryValuationMethods");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "EstimationMethod", "Write off method", TypeDescriptionString25, TypeDescriptionColumn);
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.BusinessActivities");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "BusinessActivity", "Business activity", TypeDescriptionString50, TypeDescriptionColumn, , , , , GetFunctionalOption("AccountingBySeveralBusinessActivities"));
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsAndServicesCategories");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ProductsAndServicesCategory", "Products and services category", TypeDescriptionString100, TypeDescriptionColumn);
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.Counterparties");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Vendor", "Supplier (TIN or name)", TypeDescriptionString100, TypeDescriptionColumn);
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.StructuralUnits");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Warehouse", "Warehouse (name)", TypeDescriptionString50, TypeDescriptionColumn);
	
	TypeDescriptionColumn = New TypeDescription("EnumRef.InventoryReplenishmentMethods");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ReplenishmentMethod", "Replenishment method", TypeDescriptionString50, TypeDescriptionColumn);
	
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ReplenishmentDeadline", "Replenishment deadline", TypeDescriptionString25, TypeDescriptionNumber10_0);
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.VATRates");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "VATRate", "VAT rate", TypeDescriptionString11, TypeDescriptionColumn);
	
	TypeDescriptionColumn = New TypeDescription("ChartOfAccountsRef.Managerial");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "InventoryGLAccount", "Inventory GL Account", TypeDescriptionString11, TypeDescriptionColumn);
	
	TypeDescriptionColumn = New TypeDescription("ChartOfAccountsRef.Managerial");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "ExpensesGLAccount", "Expense GL Account", TypeDescriptionString11, TypeDescriptionColumn);
	
	If GetFunctionalOption("AccountingByCells") Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Cells");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Cell", "Cell (description)", TypeDescriptionString50, TypeDescriptionColumn);
		
	EndIf;
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.PriceGroups");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "PriceGroup", "Price group (description)", TypeDescriptionString50, TypeDescriptionColumn);
	
	TypeDescriptionColumn = New TypeDescription("Boolean");
	If GetFunctionalOption("UseCharacteristics") Then
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "UseCharacteristics", "Use characteristics", TypeDescriptionString25, TypeDescriptionColumn);
		
	EndIf;
	
	If GetFunctionalOption("UseBatches") Then
		
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "UseBatches", "Use batches", TypeDescriptionString25, TypeDescriptionColumn);
		
	EndIf;
	
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "Comment", "Comment", TypeDescriptionString200, TypeDescriptionString200);
	
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "OrderCompletionDeadline", "Order completion deadline", TypeDescriptionString11, TypeDescriptionNumber10_0);
	
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "TimeNorm", "Time norm", TypeDescriptionString25, TypeDescriptionNumber10_3);
	
	TypeDescriptionColumn = New TypeDescription("Boolean");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "FixedCost", "Fixed cost (for works)", TypeDescriptionString25, TypeDescriptionColumn);
	
	TypeDescriptionColumn = New TypeDescription("CatalogRef.WorldCountries");
	DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, "CountryOfOrigin", "Country of origin (code or description)", TypeDescriptionString25, TypeDescriptionColumn);
	
	// AdditionalAttributes
	
EndProcedure

Procedure MatchImportedDataFromExternalSource(DataMatchingTable, AdditionalParameters) Export
	
	UpdateData = AdditionalParameters.DataLoadSettings.UpdateExisting;
	
	// DataMatchingTable - Type FormDataCollection
	For Each FormTableRow IN DataMatchingTable Do
		
		// Products and services by Barcode, SKU, Description
		DataImportFromExternalSourcesOverridable.CompareProductsAndServices(FormTableRow.ProductsAndServices, FormTableRow.Barcode, FormTableRow.SKU, FormTableRow.ProductsAndServicesDescription, FormTableRow.Code);
		ThisStringIsMapped = ValueIsFilled(FormTableRow.ProductsAndServices);
		
		// Parent by name
		DefaultValue = Catalogs.ProductsAndServices.EmptyRef();
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "Parent", FormTableRow.Parent_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.MapParent("ProductsAndServices", FormTableRow.Parent, FormTableRow.Parent_IncomingData, DefaultValue);
		
		// Products and services type (we can not correct attributes closed for editing)
		If ThisStringIsMapped Then
			
			FormTableRow.ProductsAndServicesType = FormTableRow.ProductsAndServices.ProductsAndServicesType;
			
		Else
			
			DataImportFromExternalSourcesOverridable.MapProductsAndServicesType(FormTableRow.ProductsAndServicesType, FormTableRow.ProductsAndServicesType_IncomingData, Enums.ProductsAndServicesTypes.InventoryItem);
			
		EndIf;
		
		// MeasurementUnits by Description (also consider the option to bind user MU)
		DefaultValue = Catalogs.UOMClassifier.pcs;
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "MeasurementUnit", FormTableRow.MeasurementUnit_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.MapUOM(FormTableRow.ProductsAndServices, FormTableRow.MeasurementUnit, FormTableRow.MeasurementUnit_IncomingData, DefaultValue);
		
		// EstimationMethod
		DefaultValue = Enums.InventoryValuationMethods.ByAverage;
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "EstimationMethod", FormTableRow.EstimationMethod_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.MapEstimationMethod(FormTableRow.EstimationMethod, FormTableRow.EstimationMethod_IncomingData, DefaultValue);
		
		// BusinessActivity by name
		DefaultValue = Catalogs.BusinessActivities.MainActivity;
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "BusinessActivity", FormTableRow.BusinessActivity_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.MapBusinessActivity(FormTableRow.BusinessActivity, FormTableRow.BusinessActivity_IncomingData, DefaultValue);
		
		// ProductsAndServicesCategory by description
		DefaultValue = Catalogs.ProductsAndServicesCategories.MainGroup;
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "ProductsAndServicesCategory", FormTableRow.ProductsAndServicesCategory_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.MapProductsAndServicesCategory(FormTableRow.ProductsAndServicesCategory, FormTableRow.ProductsAndServicesCategory_IncomingData, DefaultValue);
		
		// Supplier by TIN, Description
		DataImportFromExternalSourcesOverridable.MapSupplier(FormTableRow.Vendor, FormTableRow.Vendor_IncomingData);
		
		// Serial numbers
		If GetFunctionalOption("UseSerialNumbers") Then
			
			DataImportFromExternalSourcesOverridable.ConvertStringToBoolean(FormTableRow.UseSerialNumbers, FormTableRow.UseSerialNumbers_IncomingData);
			FormTableRow.UseSerialNumbers = Not IsBlankString(FormTableRow.SerialNumber_IncomingData);
			
			If ThisStringIsMapped
				And FormTableRow.UseSerialNumbers Then
				
				DataImportFromExternalSourcesOverridable.MapSerialNumber(FormTableRow.ProductsAndServices,
					FormTableRow.SerialNumber, FormTableRow.SerialNumber_IncomingData);
				
			EndIf;
			
		EndIf;
		
		// Warehouse by description
		DefaultValue = Catalogs.StructuralUnits.MainWarehouse;
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "Warehouse", FormTableRow.Warehouse_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.MapStructuralUnit(FormTableRow.Warehouse, FormTableRow.Warehouse_IncomingData, DefaultValue);
		
		// ReplenishmentMethod by description
		DefaultValue = Enums.InventoryReplenishmentMethods.Purchase;
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "ReplenishmentMethod", FormTableRow.ReplenishmentMethod_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.MapReplenishmentMethod(FormTableRow.ReplenishmentMethod, FormTableRow.ReplenishmentMethod_IncomingData, DefaultValue);
		
		// ReplenishmentDeadline
		DefaultValue = 1;
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "ReplenishmentDeadline", FormTableRow.ReplenishmentDeadline_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.ReplenishmentDeadline, FormTableRow.ReplenishmentDeadline_IncomingData, DefaultValue);
		
		// VATRate by description
		DefaultValue = Catalogs.Companies.MainCompany.DefaultVATRate;
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "VATRate", FormTableRow.VATRate_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.MapVATRate(FormTableRow.VATRate, FormTableRow.VATRate_IncomingData, DefaultValue);
		
		// InventoryGLAccount by the code, description
		DefaultValue = ChartsOfAccounts.Managerial.RawMaterialsAndMaterials;
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "InventoryGLAccount", FormTableRow.InventoryGLAccount_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.MapInventoryGLAccount(FormTableRow.InventoryGLAccount, FormTableRow.InventoryGLAccount_IncomingData, DefaultValue);
		
		// CostGLAccount by the code, description
		DefaultValue = ChartsOfAccounts.Managerial.UnfinishedProduction;
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "ExpensesGLAccount", FormTableRow.ExpensesGLAccount_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.MapExpensesGLAccount(FormTableRow.ExpensesGLAccount, FormTableRow.ExpensesGLAccount_IncomingData, DefaultValue);
		
		If GetFunctionalOption("AccountingByCells") Then
			
			// Cell by description
			DefaultValue = Catalogs.Cells.EmptyRef();
			WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "Cell", FormTableRow.Cell_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
			DataImportFromExternalSourcesOverridable.MapCell(FormTableRow.Cell, FormTableRow.Cell_IncomingData, DefaultValue);
			
		EndIf;
		
		// PriceGroup by description
		DefaultValue = Catalogs.PriceGroups.EmptyRef();
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "PriceGroup", FormTableRow.PriceGroup_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.MapPriceGroup(FormTableRow.PriceGroup, FormTableRow.PriceGroup_IncomingData, DefaultValue);
		
		// UseCharacteristics
		If GetFunctionalOption("UseCharacteristics") Then
			
			DataImportFromExternalSourcesOverridable. ConvertStringToBoolean(FormTableRow.UseCharacteristics, FormTableRow.UseCharacteristics_IncomingData);
			
		EndIf;
		
		// UseBatches
		If GetFunctionalOption("UseBatches") Then
			
			DataImportFromExternalSourcesOverridable.ConvertStringToBoolean(FormTableRow.UseBatches, FormTableRow.UseBatches_IncomingData);
			
		EndIf;
		
		// Comment as string
		DataImportFromExternalSourcesOverridable.CopyRowToStringTypeValue(FormTableRow.Comment, FormTableRow.Comment_IncomingData);
		
		// OrderCompletionDeadline
		DefaultValue = 1;
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "OrderCompletionDeadline", FormTableRow.OrderCompletionDeadline_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.OrderCompletionDeadline, FormTableRow.OrderCompletionDeadline_IncomingData, DefaultValue);
		
		// TimeNorm
		DefaultValue = 0;
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "TimeNorm", FormTableRow.TimeNorm_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.ConvertRowToNumber(FormTableRow.TimeNorm, FormTableRow.TimeNorm_IncomingData, DefaultValue);
		
		// FixedCost
		DataImportFromExternalSourcesOverridable.ConvertStringToBoolean(FormTableRow.FixedCost, FormTableRow.FixedCost_IncomingData);
		
		// OriginCountry by the code
		DefaultValue = Catalogs.WorldCountries.EmptyRef();
		WhenDefiningDefaultValue(FormTableRow.ProductsAndServices, "CountryOfOrigin", FormTableRow.CountryOfOrigin_IncomingData, ThisStringIsMapped, UpdateData, DefaultValue);
		DataImportFromExternalSourcesOverridable.MapOriginCountry(FormTableRow.CountryOfOrigin, FormTableRow.CountryOfOrigin_IncomingData, DefaultValue);
		
		CheckDataCorrectnessInTableRow(FormTableRow);
		
	EndDo;
	
EndProcedure

Procedure CheckDataCorrectnessInTableRow(FormTableRow, FillingObjectFullName = "") Export
	
	FormTableRow._RowMatched = ValueIsFilled(FormTableRow.ProductsAndServices);
	
	ServiceFieldName = DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible();
	
	FormTableRow[ServiceFieldName] = FormTableRow._RowMatched
											OR (NOT FormTableRow._RowMatched AND Not IsBlankString(FormTableRow.ProductsAndServicesDescription));
	
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