
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.Property("FormID")
		OR Parameters.FormID = Undefined Then
		
		ErrorMessage = NStr("en='This data processor is intended to be called from the ""EDF Settings"".
		|You can not call it manually.';ru='Данная обработка предназначена для вызова из ""Настройки ЭДО"".
		|Вызывать ее вручную запрещено.'");
			
		Raise ErrorMessage;
		Return;
		
	EndIf;
	
	CausedFormID = Parameters.FormID;
	//Agreement = Parameters.Agreement;
	//	
	//If
	//	ValueIsFilled(Agreement) And Agreement.AgreementState <> Enum.AgreementStatesED.Acts Then
	//	
	//	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
	//		NStr("en='You can not send a directory for an agreement with the ""%1"" state!';ru='Нельзя отправить каталог для соглашения с состоянием ""%1""!'"), Agreement.AgreementState);
	//	
	//	Raise MessageText;
	//	
	//EndIf;
	
	ImportFilterSettingsByDefault();
	
	If ValueIsFilled(Parameters.Title) Then
		AutoTitle = False;
		Title = Parameters.Title;
	EndIf;
	
	If ValueIsFilled(Parameters.TitleButtonsToMove) Then
		Commands["MoveIntoDocument"].Title = Parameters.TitleButtonsToMove;
		Commands["MoveIntoDocument"].ToolTip = Parameters.TitleButtonsToMove;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Not MoveIntoDocument 
		AND Object.Products.Count() > 0 Then
		
		Cancel = True;
		
		NotifyDescription = New NotifyDescription("BeforeCloseQuestionEnd", ThisObject);
		QuestionText = NStr("en='Selected products will not be sent. 
		|Continue?';ru='Подобранные товары отправлены не будут. 
		|Продолжить?'");
		
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeCloseQuestionEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		Object.Products.Clear();
		Close();
	EndIf;

EndProcedure

// Procedure imports filter settings from the default settings.
//
&AtServer
Procedure ImportFilterSettingsByDefault()
	
	DataCompositionSchema = DataProcessors.ElectronicDocumentsSendDirectory.GetTemplate("Template");
	SettingsComposer.Initialize(
		New DataCompositionAvailableSettingsSource(PutToTempStorage(DataCompositionSchema, ThisForm.UUID)));
	SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
	SettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	
	SavedSettings = CommonSettingsStorage.Load("ElectronicDocumentsSendDirectory", "FilterProducts");
	If TypeOf(SavedSettings) = Type("ValueStorage") Then
		
		SettingsOfFilters = SavedSettings.Get();
		If TypeOf(SettingsOfFilters) = Type("DataCompositionSettings") Then
			SettingsComposer.LoadSettings(SettingsOfFilters);
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure fills the tabular section "Products".
//
&AtServer
Procedure FillProductsTableAtServer(CheckFilling = True)
	
	// Necessary fields for output in the products table on a form.
	SettingsStructure = DataProcessors.ElectronicDocumentsSendDirectory.GetEmptySettingsStructure();
	
	SettingsStructure.MandatoryFields.Add("ProductsAndServices");
	
	If GetFunctionalOption("UseCharacteristics") Then
		SettingsStructure.MandatoryFields.Add("ProductsAndServicesCharacteristic");
	EndIf;
	
	SettingsStructure.MandatoryFields.Add("MeasurementUnit");
	
	SettingsStructure.SettingsComposer = SettingsComposer;
	SettingsStructure.DataCompositionSchemaTemplateName = "Template";
	
	Object.Products.Clear();
	
	// Import of the generated products list.
	ResultStructure = DataProcessors.ElectronicDocumentsSendDirectory.PrepareDataStructure(SettingsStructure);
	For Each TSRow IN ResultStructure.ProductsTable Do
		
		NewRow = Object.Products.Add();
		
		FillPropertyValues(NewRow, TSRow);
		
		If GetFunctionalOption("UseCharacteristics") Then
			NewRow.ProductsAndServicesCharacteristic = TSRow.ProductsAndServicesCharacteristic;
		EndIf;
		
	EndDo;
	
	Items.Products.Refresh();
	
EndProcedure // FillProductsTableAtServer()

&AtServer
Function PutIntoTemporaryStorageAtServer()

	AlcoholicProductsAccounting = GetFunctionalOption("EnterInformationForDeclarationsOnAlcoholicProducts");
	
	ProductsTable = New ValueTable;
	ProductsTable.Columns.Add("ID");
	ProductsTable.Columns.Add("SKU");
	ProductsTable.Columns.Add("Description");
	ProductsTable.Columns.Add("ProductsAndServices");
	ProductsTable.Columns.Add("Characteristic");
	ProductsTable.Columns.Add("BaseUnit");
	ProductsTable.Columns.Add("BaseUnitCode");
	ProductsTable.Columns.Add("BaseUnitDescription");
	ProductsTable.Columns.Add("BaseUnitDescriptionFull");
	ProductsTable.Columns.Add("BaseUnitInternationalAbbreviation");
	ProductsTable.Columns.Add("PackageCode");
	ProductsTable.Columns.Add("PackageDescription");
	If AlcoholicProductsAccounting Then
		ProductsTable.Columns.Add("Properties");
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProductsTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsTable.ProductsAndServicesCharacteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit
	|INTO Tu_Products
	|FROM
	|	&ProductsTable AS ProductsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tu_Products.ProductsAndServices.SKU AS SKU,
	|	Tu_Products.ProductsAndServices.Description AS Description,
	|	Tu_Products.ProductsAndServices AS ProductsAndServices,
	|	Tu_Products.MeasurementUnit.Code AS BaseUnitCode,
	|	Tu_Products.MeasurementUnit.InternationalAbbreviation AS BaseUnitInternationalAbbreviation,
	|	Tu_Products.MeasurementUnit.Description AS BaseUnitDescription,
	|	Tu_Products.MeasurementUnit.DescriptionFull AS BaseUnitDescriptionFull,
	|	Tu_Products.MeasurementUnit.Description AS BalanceStorageUnitDescription,
	|	""1"" AS StorageUnitOfBalanceCoefficient,
	|	Tu_Products.MeasurementUnit AS BaseUnit,
	|	NULL AS PackageCode,
	|	Tu_Products.Characteristic AS Characteristic,
	|	Tu_Products.ProductsAndServices.CountryOfOrigin.Description AS Country,
	|	Tu_Products.ProductsAndServices.AlcoholicProductsKind.Code AS AlcoholicProductsKindCode,
	|	Tu_Products.ProductsAndServices.ImportedAlcoholicProducts AS ImportedAlcoholicProducts,
	|	Tu_Products.ProductsAndServices.AlcoholicProductsManufacturerImporter.TIN AS ManufacturerImporterTIN,
	|	Tu_Products.ProductsAndServices.VolumeDAL AS VolumeDAL
	|FROM
	|	Tu_Products AS Tu_Products
	|WHERE
	|	Not Tu_Products.ProductsAndServices.IsFolder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsAndServicesBarcodes.ProductsAndServices AS Owner,
	|	ProductsAndServicesBarcodes.Characteristic AS Characteristic,
	|	ProductsAndServicesBarcodes.MeasurementUnit.Code,
	|	ProductsAndServicesBarcodes.Barcode
	|FROM
	|	Tu_Products AS Tu_Products
	|		INNER JOIN InformationRegister.ProductsAndServicesBarcodes AS ProductsAndServicesBarcodes
	|		ON Tu_Products.ProductsAndServices = ProductsAndServicesBarcodes.ProductsAndServices
	|			AND Tu_Products.Characteristic = ProductsAndServicesBarcodes.Characteristic
	|TOTALS BY
	|	Owner,
	|	Characteristic";
	
	Query.SetParameter("ProductsTable", Object.Products.Unload());
	
	ResultsArray = Query.ExecuteBatch();
	
	ProductsSelection = ResultsArray[1].Select();
	While ProductsSelection.Next() Do
		TableRow = ProductsTable.Add();
		FillPropertyValues(TableRow, ProductsSelection);
		If AlcoholicProductsAccounting Then
			
			PropertyTable = New ValueTable();
			PropertyTable.Columns.Add("Description");
			PropertyTable.Columns.Add("Value");
			
			NewRow = PropertyTable.Add();
			NewRow.Description = "AlcoholicProductsKindCode";
			NewRow.Value = ProductsSelection.AlcoholicProductsKindCode;
			
			NewRow = PropertyTable.Add();
			NewRow.Description = "ManufacturerImporterTIN";
			NewRow.Value = ProductsSelection.ManufacturerImporterTIN;
			
			NewRow = PropertyTable.Add();
			NewRow.Description = "VolumeDAL";
			NewRow.Value = ProductsSelection.VolumeDAL;
			
			TableRow.Properties = PropertyTable;
			
		EndIf;
	EndDo;
	
	SmallBusinessManagementElectronicDocumentsServer.ProcessProductsTable(ProductsTable);
	
	SelectionOwner = ResultsArray[2].Select(QueryResultIteration.ByGroups);
	If SelectionOwner.Next() Then
		ProductsTable.Columns.Add("Barcodes");
		ProductsSelection = SelectionOwner.Select(QueryResultIteration.ByGroups);
		While ProductsSelection.Next() Do
			
			FilterParameters = New Structure;
			FilterParameters.Insert("ProductsAndServices", ProductsSelection.Owner);
			FilterParameters.Insert("Characteristic", ProductsSelection.Characteristic);
			
			RowArray = ProductsTable.FindRows(FilterParameters);
			
			BarcodesSelection = ProductsSelection.Select();
			BarcodesTable = New ValueTable();
			BarcodesTable.Columns.Add("Barcode");
			BarcodesTable.Columns.Add("MeasurementUnitCode");
			While BarcodesSelection.Next() Do
				NewRow = BarcodesTable.Add();
				FillPropertyValues(NewRow, BarcodesSelection);
			EndDo;
			
			For Each String IN RowArray Do
				String.Barcodes = BarcodesTable;
			EndDo;
		EndDo
	EndIf;
	
	Return PutToTempStorage(ProductsTable, CausedFormID);
	
EndFunction

// Procedure - command handler "MoveIntoDocument".
//
&AtClient
Procedure MoveIntoDocument(Command)
	
	MoveIntoDocument = True;
	
	AddressInTemporaryStorage = PutIntoTemporaryStorageAtServer();
	NotifyChoice(AddressInTemporaryStorage);
	
EndProcedure

// Procedure - command handler "FillProductsTable".
//
&AtClient
Procedure FillProductsTable(Command)
	
	If Object.Products.Count() > 0 Then
		QuestionText = NStr("en='Products table will be refilled. Continue?';ru='Таблица товаров будет перезаполнена. Продолжить?'");
		ShowQueryBox(New NotifyDescription("FillProductsTableEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo,,DialogReturnCode.Yes);
	Else
		FillProductsTableAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillProductsTableEnd(Result, AdditionalParameters) Export
    
    If Object.Products.Count() = 0 OR DialogReturnCode.Yes = Result Then
        FillProductsTableAtServer();
    EndIf;

EndProcedure // FillProductsTable()

&AtClient
Procedure ProductsProductsAndServicesOnChange(Item)
	
	CurrentData = Items.Products.CurrentData;
	If CurrentData <> Undefined Then
		CurrentData.MeasurementUnit = GetOneProductsAndServicesDimensions(CurrentData.ProductsAndServices);
	EndIf;
	
EndProcedure

&AtServer
Function GetOneProductsAndServicesDimensions(ProductsAndServices)

	Return CommonUse.GetAttributeValue(ProductsAndServices, "MeasurementUnit");

EndFunction // GetOneProductsAndServicesDimensions()

&AtClient
Procedure OnClose()
	OnCloseAtServer();
EndProcedure

&AtServer
Procedure OnCloseAtServer()
	CommonSettingsStorage.Save("ElectronicDocumentsSendDirectory", "FilterProducts", 
		New ValueStorage(SettingsComposer.GetSettings()));
EndProcedure



