
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// It receives data set from server for the DateOnChange procedure.
//
&AtServerNoContext
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	StructureData = New Structure();
	StructureData.Insert("DATEDIFF", SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange));
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

// Gets data set from server.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", SmallBusinessServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
	If StructureData.Property("PriceKind") Then
		StructureData.Insert("DocumentCurrency", Constants.AccountingCurrency.Get());
		Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
	Else
		StructureData.Insert("Price", 0);
	EndIf;
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

&AtServerNoContext
// It receives data set from server for the CharacteristicOnChange procedure.
//
Function GetDataCharacteristicOnChange(StructureData)
	
	If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
	EndIf;
	
	StructureData.Insert("DocumentCurrency", Constants.AccountingCurrency.Get());
	Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
	StructureData.Insert("Price", Price);
	
	Return StructureData;
	
EndFunction // GetDataCharacteristicOnChange()

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure;
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction // GetDataMeasurementUnitOnChange()	

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument()
	
	Document = FormAttributeToValue("Object");
	Document.Filling(Object.BasisDocument, );
	ValueToFormAttribute(Document, "Object");
	Modified = True;	
	
EndProcedure // FillByDocument()

// Procedure recalculates in the document tabular section after
// making changes in the "Prices and currency" form. The columns are recalculated as follows: price, amount.
//
&AtClient
Procedure ProcessChangesOnButtonPrices()
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("RefillPrices", False);
	ParametersStructure.Insert("WereMadeChanges", False);
	ParametersStructure.Insert("PriceKind", Object.PriceKind);
	
	StructurePricesAndCurrency = Undefined;
	
	OpenForm("Document.InventoryReceipt.Form.PriceKindChoiceForm", ParametersStructure,,,,, New NotifyDescription("ProcessChangesByPricesEndButton", ThisObject));
	
EndProcedure

&AtClient
Procedure ProcessChangesByPricesEndButton(Result, AdditionalParameters) Export
    
    // 2. Open the form "Prices and Currency".
    StructurePricesAndCurrency = Result;
    
    // 3. Refill the tabular section "Inventory" if changes were made to the form "Prices and Currency".
    If TypeOf(StructurePricesAndCurrency) = Type("Structure")
        AND StructurePricesAndCurrency.WereMadeChanges Then
        
        Object.PriceKind = StructurePricesAndCurrency.PriceKind;
        
        // Recalculate prices by kind of prices.
        If StructurePricesAndCurrency.RefillPrices Then
            RefillTabularSectionPricesByPriceKind();
        EndIf;
        
    EndIf;
    
    // Generate the price label.
    LabelStructure = New Structure("PriceKind", Object.PriceKind);
    PricePresentation = GeneratePriceLabel(LabelStructure);

EndProcedure // ProcessChangesOnButtonPrices()

// Function returns the "Prices" label text.
//
&AtClientAtServerNoContext
Function GeneratePriceLabel(LabelStructure)
	
	LabelText = "";
	
	// Prices kind.
	If ValueIsFilled(LabelStructure.PriceKind) Then
		//===============================
		//©# (Begin)	AlekS [2016-09-13]
		//LabelText = LabelText + NStr("en='%PriceKind%';ru='%PriceKind%'");
		//LabelText = StrReplace(LabelText, "%PriceKind%", TrimAll(String(LabelStructure.PriceKind)));
		LabelText = TrimAll(String(LabelStructure.PriceKind));
		//©# (End)		AlekS [2016-09-13]
		//===============================
	Else
		LabelText = LabelText + NStr("en='specify kind of prices';ru='укажите вид цен'");
	EndIf;
	
	Return LabelText;
	
EndFunction // GeneratePriceLabel()

// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
// 
&AtServerNoContext
Procedure GetTabularSectionPricesByPriceKindAtServer(DataStructure, DocumentTabularSection)
	
	DataStructure.Insert("DocumentCurrency", Constants.AccountingCurrency.Get());
	SmallBusinessServer.GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
	
EndProcedure // GetTabularSectionPricesByPriceKindAtServer()

&AtClient
// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
// 
Procedure RefillTabularSectionPricesByPriceKind()
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;
	
	DataStructure.Insert("Date", Object.Date);
	DataStructure.Insert("Company", SubsidiaryCompany);
	DataStructure.Insert("PriceKind", Object.PriceKind);
	For Each TSRow IN Object.Inventory Do
		
		TSRow.Price = 0;
		
		If Not ValueIsFilled(TSRow.ProductsAndServices) Then
			Continue;
		EndIf;
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("ProductsAndServices", TSRow.ProductsAndServices);
		TabularSectionRow.Insert("Characteristic", TSRow.Characteristic);
		TabularSectionRow.Insert("MeasurementUnit", TSRow.MeasurementUnit);
		TabularSectionRow.Insert("Price", 0);
		
		DocumentTabularSection.Add(TabularSectionRow);
		
	EndDo;
		
	GetTabularSectionPricesByPriceKindAtServer(DataStructure, DocumentTabularSection);
		
	For Each TSRow IN DocumentTabularSection Do

		SearchStructure = New Structure;
		SearchStructure.Insert("ProductsAndServices", TSRow.ProductsAndServices);
		SearchStructure.Insert("Characteristic", TSRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit", TSRow.MeasurementUnit);
		
		SearchResult = Object.Inventory.FindRows(SearchStructure);
		
		For Each ResultRow IN SearchResult Do
			
			ResultRow.Price = TSRow.Price;
			ResultRow.Amount = ResultRow.Quantity * ResultRow.Price;
			
		EndDo;
		
	EndDo;
	
EndProcedure // RefillTabularSectionPricesByPriceKind()

// Peripherals
// Procedure gets data by barcodes.
//
&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	// Transform weight barcodes.
	For Each CurBarcode IN StructureData.BarcodesArray Do
		
		InformationRegisters.ProductsAndServicesBarcodes.ConvertWeightBarcode(CurBarcode);
		
	EndDo;
	
	DataByBarCodes = InformationRegisters.ProductsAndServicesBarcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode IN StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() <> 0 Then
			
			StructureProductsAndServicesData = New Structure();
			StructureProductsAndServicesData.Insert("ProductsAndServices", BarcodeData.ProductsAndServices);
			If ValueIsFilled(StructureData.PriceKind) Then
				StructureProductsAndServicesData.Insert("ProcessingDate", StructureData.Date);
				StructureProductsAndServicesData.Insert("Company", StructureData.Company);
				StructureProductsAndServicesData.Insert("Characteristic", BarcodeData.Characteristic);
				StructureProductsAndServicesData.Insert("DocumentCurrency", Constants.AccountingCurrency.Get());
				StructureProductsAndServicesData.Insert("PriceKind", StructureData.PriceKind);
				If ValueIsFilled(BarcodeData.MeasurementUnit)
					AND TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
					StructureProductsAndServicesData.Insert("Factor", BarcodeData.MeasurementUnit.Factor);
				Else
					StructureProductsAndServicesData.Insert("Factor", 1);
				EndIf;
			EndIf;
			
			BarcodeData.Insert("StructureProductsAndServicesData", GetDataProductsAndServicesOnChange(StructureProductsAndServicesData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.ProductsAndServices.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure // GetDataByBarCodes()

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("PriceKind", Object.PriceKind);
	StructureData.Insert("Date", Object.Date);
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode IN StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("ProductsAndServices,Characteristic,Batch,MeasurementUnit",BarcodeData.ProductsAndServices,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.ProductsAndServices = BarcodeData.ProductsAndServices;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsAndServicesData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsAndServicesData.Price;
				NewRow.Amount = NewRow.Quantity * NewRow.Price;
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				FoundString.Amount = FoundString.Quantity * FoundString.Price;
				Items.Inventory.CurrentRow = FoundString.GetID();
			EndIf;
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;

EndFunction // FillByBarcodesData()

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisForm, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.ProductsAndServicesBarcodes.Form.ProductsAndServicesBarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisForm,,,,Notification
		);
		
		Return;
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure // BarcodesAreReceived()

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement IN ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement IN ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		UnknownBarcodes = FillByBarcodesData(BarcodesArray);
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode IN UnknownBarcodes Do
		
		MessageString = NStr("en='Data by barcode is not found: %1%; quantity: %2%';ru='Данные по штрихкоду не найдены: %1%; количество: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

// End Peripherals

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

// Receives the flag of Order warehouse.
//
&AtServer
Procedure SetCellVisible()
	
	If Not ValueIsFilled(Object.StructuralUnit) 
		OR Object.StructuralUnit.OrderWarehouse
		OR Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Retail Then
		Items.Cell.Enabled = False;
	Else
		Items.Cell.Enabled = True;
	EndIf;
	
EndProcedure // SetCellVisible()	

&AtServer
// The procedure sets the form attributes
// visible on the option Use subsystem Production.
//
// Parameters:
// No.
//
Procedure SetVisibleByFOUseProductionSubsystem()
	
	// Production.
	If Constants.FunctionalOptionUseSubsystemProduction.Get() Then
		
		// Setting the method of structural unit selection depending on FO.
		If Not Constants.FunctionalOptionAccountingByMultipleDepartments.Get()
			AND Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
			
			Items.StructuralUnit.ListChoiceMode = True;
			Items.StructuralUnit.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
			Items.StructuralUnit.ChoiceList.Add(Catalogs.StructuralUnits.MainDepartment);
			
		EndIf;
		
	Else
		
		If Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
			
			NewArray = New Array();
			NewArray.Add(Enums.StructuralUnitsTypes.Warehouse);
			NewArray.Add(Enums.StructuralUnitsTypes.Retail);
			ArrayTypesOfStructuralUnits = New FixedArray(NewArray);
			NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayTypesOfStructuralUnits);
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			
			Items.StructuralUnit.ChoiceParameters = NewParameters;
			
		Else
			
			Items.StructuralUnit.Visible = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure // SetVisibleByFDUseProductionSubsystem()

///////////////////////////////////////////////////////////////////////////////
// PICK BUTTON CLICK PROCERSSING PROCEDURES

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName 	= "Inventory";
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 				Object.Date);
	SelectionParameters.Insert("Company", 			SubsidiaryCompany);
	SelectionParameters.Insert("AmountIncludesVAT",		False);
	SelectionParameters.Insert("DocumentOrganization", 	Object.Company);
	SelectionParameters.Insert("StructuralUnit", 	Object.StructuralUnit);
	SelectionParameters.Insert("ShowPriceColumn",	False);
	SelectionParameters.Insert("ThisIsReceiptDocument",	True);
	
	ProductsAndServicesType = New ValueList;
	For Each ArrayElement IN Items[TabularSectionName + "ProductsAndServices"].ChoiceParameters Do
		If ArrayElement.Name = "Filter.ProductsAndServicesType" Then
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				For Each FixArrayItem IN ArrayElement.Value Do
					ProductsAndServicesType.Add(FixArrayItem);
				EndDo; 
			Else
				ProductsAndServicesType.Add(ArrayElement.Value);
			EndIf;
		EndIf;
	EndDo;
	SelectionParameters.Insert("ProductsAndServicesType", 		ProductsAndServicesType);
	
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	
	OpenForm("CommonForm.PickForm", SelectionParameters, ThisForm);
	
EndProcedure // ExecutePick()

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	//Transfer the received positions from the selection to PM
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow IN TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
	EndDo;
	
EndProcedure // GetInventoryFromStorage()

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en='Enter barcode';ru='Введите штрихкод'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
    
    CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
    
    
    If Not IsBlankString(CurBarcode) Then
        BarcodesReceived(New Structure("Barcode, Quantity", CurBarcode, 1));
    EndIf;

EndProcedure // SearchByBarcode()

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en='It is required to select a line to get weight for it.';ru='Необходимо выбрать строку, для которой необходимо получить вес.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NOTifyDescription, UUID);
		
	EndIf;
	
EndProcedure // GetWeight()

&AtClient
Procedure GetWeightEnd(Weight, Parameters) Export
	
	TabularSectionRow = Parameters;
	
	If Not Weight = Undefined Then
		If Weight = 0 Then
			MessageText = NStr("en='Electronic scales returned zero weight.';ru='Электронные весы вернули нулевой вес.'");
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
			TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure // ImportDataFromDCT()

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	If TypeOf(Parameters.Basis) = Type("DocumentRef.InventoryReconciliation") Then
		
		Query = New Query(
		"SELECT TOP 1
		|	InventoryReconciliation.Quantity - InventoryReconciliation.QuantityAccounting AS Quantity
		|FROM
		|	Document.InventoryReconciliation.Inventory AS InventoryReconciliation
		|WHERE
		|	InventoryReconciliation.Ref = &BasisDocument
		|	AND InventoryReconciliation.Quantity - InventoryReconciliation.QuantityAccounting > 0");
		
		Query.SetParameter("BasisDocument", Parameters.Basis);
		
		QueryResult = Query.Execute();
		If QueryResult.IsEmpty() Then
			DoNotOpenForm = True;
			Return;
		EndIf;
		
	EndIf;
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	AccountingCurrency = Constants.AccountingCurrency.Get();
	
	SetCellVisible();
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	// Generate the price label.
	LabelStructure = New Structure("PriceKind", Object.PriceKind);
	PricePresentation = GeneratePriceLabel(LabelStructure);
	
	// FO Use Production subsystem.
	SetVisibleByFOUseProductionSubsystem();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// Peripherals
	UsePeripherals = SmallBusinessReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
EndProcedure // OnCreateAtServer()

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure // OnReadAtServer()

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	If DoNotOpenForm Then
		Cancel = True;
	EndIf;
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
EndProcedure // OnOpen()

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose()
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals

EndProcedure // OnClose()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			//Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;
			
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
	If EventName = "SelectionIsMade" 
		AND ValueIsFilled(Parameter) 
		//Check for the form owner
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		InventoryAddressInStorage = Parameter;
		
		GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
		
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - handler of clicking the FillByBasis button.
//
&AtClient
Procedure FillByBasis(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en='Document will be completely refilled by ""Basis""! Continue?';ru='Документ будет полностью перезаполнен по ""Основанию""! Продолжить?'"), QuestionDialogMode.YesNo, 0);	

EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocument();		
    EndIf;

EndProcedure  // FillExecute()

&AtClient
// Procedure is called by clicking "Prices" button
// with command of tabular section panel.
//
Procedure EditPrices(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPrices();
	Modified = True;
	
EndProcedure // EditPrices()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure // DateOnChange()

// Procedure - event handler OnChange of the Company input field.
// IN procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure // CompanyOnChange()

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	SetCellVisible();
	
EndProcedure // StructuralUnitOnChange()

// Procedure - event handler Field opening StructuralUnit.
//
&AtClient
Procedure StructuralUnitOpening(Item, StandardProcessing)
	
	If Items.StructuralUnit.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // StructuralUnitOpening()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTION ATTRIBUTE EVENT HANDLERS

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure InventoryProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("Company", Object.Company);
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		
	EndIf;
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
EndProcedure // InventoryProductsAndServicesOnChange()

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	If ValueIsFilled(Object.PriceKind) Then
		
		TabularSectionRow = Items.Inventory.CurrentData;
		
		StructureData = New Structure();
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("Company", Object.Company);
		StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
		StructureData = GetDataCharacteristicOnChange(StructureData);
		
		TabularSectionRow.Price = StructureData.Price;
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
		
	EndIf;
	
EndProcedure // InventoryCharacteristicOnChange()

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure InventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
		OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;	
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;	
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	// Price.
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf; 		
	
	// Amount.
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
EndProcedure // InventoryMeasurementUnitChoiceProcessing()

// Procedure - OnChange event handler of the
// Quantity input field in the Inventory tabular section line.
// Recalculates the amount in the tabular section line.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
EndProcedure // GoodsUnitNumberOnChange()

// Procedure - OnChange event handler of the
// Price input field in the Inventory tabular section line.
// Recalculates the amounts in the tabular section line.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;

EndProcedure

// Procedure - OnChange event handler of the
// Amount input field in the Inventory tabular section line.
// Recalculates prices in the tabular section line.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Price = ?(TabularSectionRow.Quantity = 0, 0, TabularSectionRow.Amount / TabularSectionRow.Quantity);

EndProcedure // InventoryAmountOnChange()

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion

//Rise { Aghabekyan 2017-02-11
#Region CopyPasteRows

&AtClient
Procedure InventoryCopyRows(Command)
	CopyRowsTabularPart("Inventory");   
EndProcedure

&AtClient
Procedure CopyRowsTabularPart(TabularPartName)
	
	If TabularPartCopyClient.CanCopyRows(Object[TabularPartName],Items[TabularPartName].CurrentData) Then
		CountOfCopied = 0;
		CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied);
		TabularPartCopyClient.NotifyUserCopyRows(CountOfCopied);
	EndIf;
	
EndProcedure

&AtServer 
Procedure CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied)
	
	TabularPartCopyServer.Copy(Object[TabularPartName], Items[TabularPartName].SelectedRows, CountOfCopied);
	
EndProcedure

&AtClient
Procedure InventoryPasteRows(Command)
	PasteRowsTabularPart("Inventory"); 
EndProcedure

&AtClient
Procedure PasteRowsTabularPart(TabularPartName)
	
	CountOfCopied = 0;
	CountOfPasted = 0;
	PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted);
	TabularPartCopyClient.NotifyUserPasteRows(CountOfCopied, CountOfPasted);
	
EndProcedure

&AtServer
Procedure PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted)
	
	TabularPartCopyServer.Paste(Object, TabularPartName, Items, CountOfCopied, CountOfPasted);
	ProcessPastedRowsAtServer(TabularPartName, CountOfPasted);
	
EndProcedure

&AtServer
Procedure ProcessPastedRowsAtServer(TabularPartName, CountOfPasted)
	
	Count = Object[TabularPartName].Count();
	
	For iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - iterator];
		
		StructData = New Structure;     	
		StructData.Insert("ProductsAndServices",  Row.ProductsAndServices); 		
		StructData = GetDataProductsAndServicesOnChange(StructData); 
		
		If Not ValueIsFilled(Row.MeasurementUnit) Then
			Row.MeasurementUnit = StructData.MeasurementUnit;
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion
//Rise } Aghabekyan 2017-02-11











