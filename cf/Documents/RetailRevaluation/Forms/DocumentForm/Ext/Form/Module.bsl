////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Recalculate the price of document tabular section.
//
&AtClient
Procedure RefillTabularSectionPricesByPriceKind()
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				Object.Date);
	DataStructure.Insert("Company",			SubsidiaryCompany);
	DataStructure.Insert("PriceKind",				Object.PriceKind);
	DataStructure.Insert("DocumentCurrency",		Object.DocumentCurrency);
		
	For Each TSRow IN Object.Inventory Do
		TSRow.Price = 0;
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("ProductsAndServices",		TSRow.ProductsAndServices);
		TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
		TabularSectionRow.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		TabularSectionRow.Insert("Price",				0);
		DocumentTabularSection.Add(TabularSectionRow);
	EndDo;
		
	SmallBusinessServer.GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
		
	For Each TSRow IN DocumentTabularSection Do
  		SearchStructure = New Structure;
		SearchStructure.Insert("ProductsAndServices",		TSRow.ProductsAndServices);
		SearchStructure.Insert("Characteristic",		TSRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		SearchResult = Object.Inventory.FindRows(SearchStructure);
		
		For Each ResultRow IN SearchResult Do
			ResultRow.Price = TSRow.Price;
			ResultRow.Amount = ResultRow.Quantity * ResultRow.NewPrice - ResultRow.Quantity * ResultRow.Price;
		EndDo;		
	EndDo;
	
EndProcedure // RefillTabularSectionPricesByPriceKind()

// It receives data set from server for the DateOnChange procedure.
//
&AtServerNoContext
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	StructureData = New Structure;
	
	StructureData.Insert("DATEDIFF", SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange));
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
	If StructureData.Property("PriceKind") Then
		Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
	Else
		StructureData.Insert("Price", 0);
	EndIf;
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.NewPrice - TabularSectionRow.Quantity * TabularSectionRow.Price;
	
EndProcedure // CalculateAmountInTabularSectionLine()

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	If StructureData.Property("PriceKind") Then
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
     		StructureData.Insert("Factor", 1);
		Else
			StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
		EndIf;		
		Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
	Else
		StructureData.Insert("Price", 0);
	EndIf;	
		
	Return StructureData;
	
EndFunction // GetDataCharacteristicOnChange()

// Gets data set from server.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure;
	
	StructureData.Insert("Counterparty", SmallBusinessServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

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

// It receives data set from the server for the StructuralUnitOnChange procedure.
//
&AtServerNoContext
Function GetDataStructuralUnitOnChange(StructuralUnit)
	
	StructureData = New Structure;
	
	StructureData.Insert("RetailPriceKind", StructuralUnit.RetailPriceKind);
	StructureData.Insert("PriceCurrency", StructuralUnit.RetailPriceKind.PriceCurrency);
	StructureData.Insert("MarkupGLAccount", StructuralUnit.MarkupGLAccount);
			
	Return StructureData;
	
EndFunction // GetDataStructuralUnitOnChange()

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
			StructureProductsAndServicesData.Insert("Company", StructureData.Company);
			StructureProductsAndServicesData.Insert("ProductsAndServices", BarcodeData.ProductsAndServices);
			StructureProductsAndServicesData.Insert("Characteristic", BarcodeData.Characteristic);
			If ValueIsFilled(StructureData.PriceKind) Then
				StructureProductsAndServicesData.Insert("ProcessingDate", StructureData.Date);
				StructureProductsAndServicesData.Insert("DocumentCurrency", StructureData.DocumentCurrency);
				StructureProductsAndServicesData.Insert("AmountIncludesVAT", True);
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
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
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
				CalculateAmountInTabularSectionLine(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(FoundString);
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
		
		MessageString = NStr("en='Barcode data is not found: %1%; quantity: %2%';ru='Данные по штрихкоду не найдены: %1%; количество: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
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
		PostingIsAllowed
	);
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	If Object.Inventory.Count() = 0 Then
		NewRow = Object.Inventory.Add();
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPrice.ReadOnly  	= Not AllowedEditDocumentPrices;
	Items.InventoryNewPrice.ReadOnly = Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly 	= Not AllowedEditDocumentPrices;
	
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
	
	LineCount = Object.Inventory.Count();
	
	FilledAtLeastOneColumn = False;
	If LineCount = 1 Then
		FilledAtLeastOneColumn = ValueIsFilled(Object.Inventory[0].ProductsAndServices)
			OR ValueIsFilled(Object.Inventory[0].Characteristic)
			OR ValueIsFilled(Object.Inventory[0].Batch)
			OR ValueIsFilled(Object.Inventory[0].Quantity)
			OR ValueIsFilled(Object.Inventory[0].MeasurementUnit)
			OR ValueIsFilled(Object.Inventory[0].Price)
			OR ValueIsFilled(Object.Inventory[0].NewPrice);
	EndIf;
	
	Items.EditInList.Check = LineCount > 1 OR FilledAtLeastOneColumn;
	
	If LineCount > 0 Then
		Items.Inventory.CurrentRow = Object.Inventory[0].GetID();
	EndIf;
	
	SetEditInListFragmentOption();
	
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
	
EndProcedure // NotificationProcessing()

// Procedure - EditByList command handler.
//
&AtClient
Procedure EditInList(Command)
	
	SetEditInListOption();

EndProcedure // EditByList()

// Procedure - Set edit by list option.
//
&AtClient
Procedure SetEditInListOption()
	
	Items.EditInList.Check = Not Items.EditInList.Check;
	
	LineCount = Object.Inventory.Count();
	
	FilledAtLeastOneColumn = False;
	If LineCount = 1 Then
		FilledAtLeastOneColumn = ValueIsFilled(Object.Inventory[0].ProductsAndServices)
			OR ValueIsFilled(Object.Inventory[0].Characteristic)
			OR ValueIsFilled(Object.Inventory[0].Batch)
			OR ValueIsFilled(Object.Inventory[0].Quantity)
			OR ValueIsFilled(Object.Inventory[0].MeasurementUnit)
			OR ValueIsFilled(Object.Inventory[0].Price)
			OR ValueIsFilled(Object.Inventory[0].NewPrice);
	EndIf;
	
	If Not Items.EditInList.Check
		  AND (LineCount > 1
		 OR FilledAtLeastOneColumn) Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("SetEditInListEndOption", ThisObject), 
			NStr("en='All lines will be hidden. Continue?';ru='Все строки будут свернуты. Продолжить?'"),
			QuestionDialogMode.YesNo
		);
        Return;
	EndIf;
	
	SetEditInListFragmentOption();
EndProcedure

&AtClient
Procedure SetEditInListEndOption(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Items.EditInList.Check = True;
        Return;
    EndIf;
    
    RevaluationAmount = Object.Inventory.Total("Amount");
    
    Object.Inventory.Clear();
    NewRow = Object.Inventory.Add();
    NewRow.Amount = RevaluationAmount;
    
    Items.Inventory.CurrentRow = NewRow.GetID();
    
    SetEditInListFragmentOption();

EndProcedure

&AtServer
Procedure SetEditInListFragmentOption()
	
	If Items.EditInList.Check Then
		Items.Inventory.Visible = True;
		Items.InventoryTotalAmount.Visible = True;
		Items.Amount.Visible = False; 
		Items.DecorationSplitter.Visible = False;
	Else
		Items.Inventory.Visible = False;
		Items.InventoryTotalAmount.Visible = False;
		Items.Amount.Visible = True;
		Items.DecorationSplitter.Visible = True;
	EndIf;
	
EndProcedure // SetEditByListOption()

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
		
		ShowMessageBox(Undefined, NStr("en='Select a line for which the weight should be received.';ru='Необходимо выбрать строку, для которой необходимо получить вес.'"));
		
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
			CalculateAmountInTabularSectionLine(TabularSectionRow);
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
	
	StructureData = GetDataStructuralUnitOnChange(Object.StructuralUnit);
	Object.PriceKind = StructureData.RetailPriceKind;
	Object.DocumentCurrency = StructureData.PriceCurrency;
	Object.Correspondence = StructureData.MarkupGLAccount;
	
	LineCount = Object.Inventory.Count();
	
	FilledAtLeastOneColumn = False;
	If LineCount = 1 Then
		FilledAtLeastOneColumn = ValueIsFilled(Object.Inventory[0].ProductsAndServices)
			OR ValueIsFilled(Object.Inventory[0].Characteristic)
			OR ValueIsFilled(Object.Inventory[0].Batch)
			OR ValueIsFilled(Object.Inventory[0].Quantity)
			OR ValueIsFilled(Object.Inventory[0].MeasurementUnit)
			OR ValueIsFilled(Object.Inventory[0].Price)
			OR ValueIsFilled(Object.Inventory[0].NewPrice);
	EndIf;
	
	If LineCount > 1 OR FilledAtLeastOneColumn Then 
		RefillTabularSectionPricesByPriceKind();
	EndIf;
	
EndProcedure // StructuralUnitOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE INVENTORY TABULAR SECTION ATTRIBUTES

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure InventoryProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", SubsidiaryCompany);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	 Object.Date);
		StructureData.Insert("DocumentCurrency",  Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", True);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
					
	EndIf;
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = StructureData.Price;
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryProductsAndServicesOnChange()

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
		
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices",   TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	 Object.Date);
		StructureData.Insert("DocumentCurrency",	 Object.DocumentCurrency);
		StructureData.Insert("Price",			 TabularSectionRow.Price);
		StructureData.Insert("PriceKind",			 Object.PriceKind);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
	EndIf;
				
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price = StructureData.Price;
				
	CalculateAmountInTabularSectionLine();
	
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
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryMeasurementUnitChoiceProcessing()

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryQuantityOnChange()

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryPriceOnChange()

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.NewPrice = TabularSectionRow.Amount / TabularSectionRow.Quantity + TabularSectionRow.Price;
	EndIf;
	
EndProcedure // InventoryAmountOnChange()

// Procedure - event  handler OnChange input field NewPrice.
//
&AtClient
Procedure InventoryNewPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();

EndProcedure // InventoryNewPriceOnChange()

// Procedure - handler of event BeforeDelete of tabular section Inventory.
//
&AtClient
Procedure InventoryBeforeDelete(Item, Cancel)
	
	If Object.Inventory.Count() = 1 Then
		Cancel = True;
	EndIf;
	
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