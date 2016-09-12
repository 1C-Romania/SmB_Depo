
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// The procedure fills in the "Inventory by standards" tabular section.
//
Procedure FillTabularSectionInventoryByStandards()
	
	Document = FormAttributeToValue("Object");
	Document.RunInventoryFillingByStandards();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // FillTabularSectionInventoryByStandards()	

// The procedure fills in the "Inventory by balance" tabular section.
//
Procedure FillTabularSectionInventoryByBalance()
	
	Document = FormAttributeToValue("Object");
	Document.RunInventoryFillingByBalance();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // FillTabularSectionInventoryByBalance()

// The procedure fills in the "InventoryAllocation by standards" tabular section.
//
Procedure FillTabularSectionInventoryDistributionByStandards()
	
	Document = FormAttributeToValue("Object");
	Document.RunInventoryDistributionByStandards();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // FillTabularSectionInventoryDistributionByStandards()

// The procedure fills in the "InventoryAllocation by quantity" tabular section.
//
Procedure FillTabularSectionInventoryDistributionByCount()
	
	Document = FormAttributeToValue("Object");
	Document.RunInventoryDistributionByCount();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // FillTabularSectionCostingByCount()

// The procedure fills in the Costs tabular section.
//
Procedure FillTabularSectionCostsByBalance()
	
	Document = FormAttributeToValue("Object");
	Document.RunExpenseFillingByBalance();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // FillTabularSectionCostsByBalance()

// The procedure fills in the ExpensesAllocation tabular section.
//
Procedure FillTabularSectionCostingByCount()
	
	Document = FormAttributeToValue("Object");
	Document.RunCostingByCount();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // FillTabularSectionCostingByCount()

// The procedure fills in the Production tabular section.
//
Procedure FillTabularSectionProductsByOutput()
	
	Document = FormAttributeToValue("Object");
	Document.RunProductsFillingByOutput();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // FillTabularSectionProductsByOutput()	

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
				NewRow.Specification = BarcodeData.StructureProductsAndServicesData.Specification;
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
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
Procedure SetCellVisible(CellName, Warehouse)
	
	Items[CellName].Visible = Not Warehouse.OrderWarehouse;
	
EndProcedure // SetCellVisible()	

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR WORK WITH THE SELECTION

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure ProductsPick(Command)
	
	TabularSectionName 	= "Products";
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 				Object.Date);
	SelectionParameters.Insert("Company", 			SubsidiaryCompany);
	SelectionParameters.Insert("StructuralUnit", 	Object.StructuralUnit);
	
	SelectionParameters.Insert("SpecificationsUsed", True);
	
	SelectionParameters.Insert("ShowPriceColumn",	False);
	SelectionParameters.Insert("ThisIsReceiptDocument", 	True);
	
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
	SelectionParameters.Insert("ProductsAndServicesType", ProductsAndServicesType);
	
	BatchStatus = New ValueList;
	For Each ArrayElement IN Items[TabularSectionName + "Batch"].ChoiceParameters Do
		If ArrayElement.Name = "Filter.Status" Then
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				For Each FixArrayItem IN ArrayElement.Value Do
					BatchStatus.Add(FixArrayItem);
				EndDo;
			Else
				BatchStatus.Add(ArrayElement.Value);
			EndIf;
		EndIf;
	EndDo;
	
	SelectionParameters.Insert("BatchStatus", BatchStatus);
	
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	
	OpenForm("CommonForm.PickForm", SelectionParameters, ThisForm);
	
EndProcedure // ExecutePick()

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName 	= "Inventory";
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 				Object.Date);
	SelectionParameters.Insert("Company", 			SubsidiaryCompany);
	SelectionParameters.Insert("StructuralUnit", 	Object.StructuralUnit);
	
	SelectionParameters.Insert("SpecificationsUsed", True);	
	SelectionParameters.Insert("ReservationUsed", True);
	
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
	SelectionParameters.Insert("ProductsAndServicesType",	   ProductsAndServicesType);
		
	BatchStatus = New ValueList;
	For Each ArrayElement IN Items[TabularSectionName + "Batch"].ChoiceParameters Do
		If ArrayElement.Name = "Filter.Status" Then
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				For Each FixArrayItem IN ArrayElement.Value Do
					BatchStatus.Add(FixArrayItem);
				EndDo;
			Else
				BatchStatus.Add(ArrayElement.Value);
			EndIf;
		EndIf;
	EndDo;
	
	SelectionParameters.Insert("BatchStatus", BatchStatus);
	
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	
	OpenForm("CommonForm.PickForm", SelectionParameters, ThisForm);
	
EndProcedure // ExecutePick()

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

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow IN TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		
		If TabularSectionName = "Inventory" Then
			NewRow.ConnectionKey = SmallBusinessServer.CreateNewLinkKey(ThisForm);
		EndIf;
		
		FillPropertyValues(NewRow, ImportRow);
		
	EndDo;
	
EndProcedure // GetInventoryFromStorage()

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
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	Items.Cell.Visible = Not Object.StructuralUnit.OrderWarehouse;
	
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
		TabularSectionName 	= ?(Items.Pages.CurrentPage = Items.GroupProducts, "Products", "Inventory");
		
		GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
		
	EndIf;
	
EndProcedure // NotificationProcessing()

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

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices));
	EndIf;
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices, StructureData.Characteristic));
	
	Return StructureData;
	
EndFunction // GetDataCharacteristicOnChange()

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	SetCellVisible("Cell", Object.StructuralUnit);
	
EndProcedure // StructuralUnitOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM TABULAR SECTIONS COMMAND PANELS ACTIONS

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure InventoryFillByStandards(Command)
	
	If Object.Inventory.Count() <> 0 Then

		QuestionText = NStr("en='The ""Inventory"" tabular section will be refilled.';ru='Табличная часть ""Запасы"" будет перезаполнена!'") + Chars.LF;
		If Object.InventoryDistribution.Count() <> 0 Then
			QuestionText = QuestionText + NStr("en='Tabular section ""inventory distribution""  will be cleared!';ru='Табличная часть ""Распределение запасов"" будет очищена!'") + Chars.LF;
		EndIf;	
		QuestionText = QuestionText + NStr("en='Continue?';ru='Продолжить?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("InventoryFillByStandardsEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	InventoryFillByStandardsFragment();
EndProcedure

&AtClient
Procedure InventoryFillByStandardsEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    InventoryFillByStandardsFragment();

EndProcedure

&AtClient
Procedure InventoryFillByStandardsFragment()
    
    FillTabularSectionInventoryByStandards();

EndProcedure // InventoryFillByStandards()

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure InventoryFillByBalances(Command)
	
	If Object.Inventory.Count() <> 0 Then

		QuestionText = NStr("en='The ""Inventory"" tabular section will be refilled.';ru='Табличная часть ""Запасы"" будет перезаполнена!'") + Chars.LF;
		If Object.InventoryDistribution.Count() <> 0 Then
			QuestionText = QuestionText + NStr("en='Tabular section ""inventory distribution""  will be cleared!';ru='Табличная часть ""Распределение запасов"" будет очищена!'") + Chars.LF;
		EndIf;	
		QuestionText = QuestionText + NStr("en='Continue?';ru='Продолжить?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("InventoryFillByBalancesEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	InventoryFillByBalancesFragment();
EndProcedure

&AtClient
Procedure InventoryFillByBalancesEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    InventoryFillByBalancesFragment();

EndProcedure

&AtClient
Procedure InventoryFillByBalancesFragment()
    
    FillTabularSectionInventoryByBalance();

EndProcedure // InventoryFillByBalances()

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure InventoryDistributeByStandards(Command)
	
	If Object.InventoryDistribution.Count() <> 0 Then

		Response = Undefined;


		ShowQueryBox(New NotifyDescription("InventoryDistributeByStandardsEnd", ThisObject), NStr("en='The ""Inventory allocation"" tabular section will be refilled. Continue?';ru='Табличная часть ""Распределение запасов"" будет перезаполнена! Продолжить?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	InventoryDistributeByStandardsFragment();
EndProcedure

&AtClient
Procedure InventoryDistributeByStandardsEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    InventoryDistributeByStandardsFragment();

EndProcedure

&AtClient
Procedure InventoryDistributeByStandardsFragment()
    
    FillTabularSectionInventoryDistributionByStandards();
    
    If Object.Inventory.Count() <> 0 Then
        
        If Items.Inventory.CurrentRow = Undefined Then
            Items.Inventory.CurrentRow = 0;
        EndIf;	
        
        TabularSectionName = "Inventory";
        SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "InventoryDistribution");
        
    EndIf;

EndProcedure // InventoryDistributeByStandards()

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure InventoryDistributeByQuantity(Command)
	
	If Object.InventoryDistribution.Count() <> 0 Then

		Response = Undefined;


		ShowQueryBox(New NotifyDescription("InventoryDistributeByQuantityEnd", ThisObject), NStr("en='The ""Inventory allocation"" tabular section will be refilled. Continue?';ru='Табличная часть ""Распределение запасов"" будет перезаполнена! Продолжить?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	InventoryDistributeByQuantityFragment();
EndProcedure

&AtClient
Procedure InventoryDistributeByQuantityEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    InventoryDistributeByQuantityFragment();

EndProcedure

&AtClient
Procedure InventoryDistributeByQuantityFragment()
    
    FillTabularSectionInventoryDistributionByCount();
    
    If Object.Inventory.Count() <> 0 Then
        
        If Items.Inventory.CurrentRow = Undefined Then
            Items.Inventory.CurrentRow = 0;
        EndIf;
        
        TabularSectionName = "Inventory";
        SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "InventoryDistribution");
        
    EndIf;

EndProcedure // InventoryDistributeByCount()

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CostsFillByBalance(Command)
	
	If Object.Costs.Count() <> 0 Then

		QuestionText = NStr("en='Tabular section ""Costs"" will be refilled!';ru='Табличная часть ""Затраты"" будет перезаполнена!'") + Chars.LF;
		QuestionText = QuestionText + NStr("en='Tabular section ""Expenses distribution"" will be refilled! Do you want to continue operation?';ru='Табличная часть ""Распределение расходов"" будет очищена!'") + Chars.LF;
		QuestionText = QuestionText + NStr("en='Continue?';ru='Продолжить?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("CostsFillByBalanceEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	CostsFillByBalanceFragment();
EndProcedure

&AtClient
Procedure CostsFillByBalanceEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    CostsFillByBalanceFragment();

EndProcedure

&AtClient
Procedure CostsFillByBalanceFragment()
    
    FillTabularSectionCostsByBalance();

EndProcedure // CostsFillByBalance()

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CostsDistributeByQuantity(Command)
	                  
	If Object.CostAllocation.Count() <> 0 Then

		Response = Undefined;


		ShowQueryBox(New NotifyDescription("AllocateCostsByQuantityEnd", ThisObject), NStr("en='The ""Expenses allocation"" tabular section will be refilled. Continue?';ru='Табличная часть ""Распределение расходов"" будет перезаполнена! Продолжить?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	AllocateCostsByQuantityFragment();
EndProcedure

&AtClient
Procedure AllocateCostsByQuantityEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    AllocateCostsByQuantityFragment();

EndProcedure

&AtClient
Procedure AllocateCostsByQuantityFragment()
    
    FillTabularSectionCostingByCount();
    
    If Object.Costs.Count() <> 0 Then
        
        If Items.Costs.CurrentRow = Undefined Then
            Items.Costs.CurrentRow = 0;
        EndIf;
        
        TabularSectionName = "Costs";
        SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "CostAllocation");
        
    EndIf;

EndProcedure // DistributeCount()

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure ProductsFillByOutput(Command)
	
	If Object.Products.Count() <> 0 Then

		Response = Undefined;


		ShowQueryBox(New NotifyDescription("ProductsFillByOutputEnd", ThisObject), NStr("en='The ""Production"" tabular section will be refilled. Continue?';ru='Табличная часть ""Продукция"" будет перезаполнена! Продолжить?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	ProductsFillByOutputFragment();
EndProcedure

&AtClient
Procedure ProductsFillByOutputEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    ProductsFillByOutputFragment();

EndProcedure

&AtClient
Procedure ProductsFillByOutputFragment()
    
    FillTabularSectionProductsByOutput();

EndProcedure // ProductsFillByOutput()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTIONS EVENT HANDLERS

// Procedure - OnActivating event handler of the Costs tabular section.
//
&AtClient
Procedure CostsOnActivateRow(Item)
	
	TabularSectionName = "Costs";
	SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "CostAllocation");
	
EndProcedure

// Procedure - OnStartEdit event handler of the Costs tabular section.
//
&AtClient
Procedure CostsOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Costs";
	If NewRow Then

		SmallBusinessClient.AddConnectionKeyToTabularSectionLine(ThisForm);
		SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "CostAllocation");
		
	EndIf;

EndProcedure

// Procedure - BeforeDeleting event handler of the Costs tabular section.
//
&AtClient
Procedure CostsBeforeDelete(Item, Cancel)

	TabularSectionName = "Costs";
	SmallBusinessClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "CostAllocation");

EndProcedure

// Procedure - OnStartEdit event handler of the CostAllocation tabular section.
//
&AtClient
Procedure CostingOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Costs";
	If NewRow Then
		SmallBusinessClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
	EndIf;

EndProcedure

// Procedure - BeforeStartAdding event handler of the CostAllocation tabular section.
//
&AtClient
Procedure CostingBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	TabularSectionName = "Costs";
	Cancel = SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
EndProcedure

// Procedure - OnActivating event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnActivateRow(Item)
	
	TabularSectionName = "Inventory";
	SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "InventoryDistribution");
	
EndProcedure

// Procedure - OnStartEdit event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Inventory";
	If NewRow Then

		SmallBusinessClient.AddConnectionKeyToTabularSectionLine(ThisForm);
		SmallBusinessClient.SetFilterOnSubordinateTabularSection(ThisForm, "InventoryDistribution");
		
	EndIf;

EndProcedure

// Procedure - handler of event BeforeDelete of tabular section Inventory.
//
&AtClient
Procedure InventoryBeforeDelete(Item, Cancel)

	TabularSectionName = "Inventory";
	SmallBusinessClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "InventoryDistribution");

EndProcedure

// Procedure - OnStartEdit event handler of the InventoryAllocation tabular section.
//
&AtClient
Procedure InventoryDistributionOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Inventory";
	If NewRow Then
		SmallBusinessClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
	EndIf;

EndProcedure

// Procedure - BeforeStartEditing event handler of the InventoryAllocation tabular section.
//
&AtClient
Procedure InventoryDistributionBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	TabularSectionName = "Inventory";
	Cancel = SmallBusinessClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE PRODUCTS TABULAR SECTION ATTRIBUTES

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure ProductsProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Specification = StructureData.Specification;

EndProcedure // InventoryProductsAndServicesOnChange()

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure ProductsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure // ProductsCharacteristicOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE INVENTORY TABULAR SECTION ATTRIBUTES

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure InventoryProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure // InventoryProductsAndServicesOnChange()

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure // InventoryCharacteristicOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF INVENTORY ALLOCATION TS ATTRIBUTES

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure InventoryDistributionProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.InventoryDistribution.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure // InventoryDistributionProductsAndServicesOnChange()

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryDistributionCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.InventoryDistribution.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure // InventoryDistributionCharacteristicOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF COSTS ALLOCATION TS ATTRIBUTES

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure CostAllocationProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.CostAllocation.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure // CostAllocationProductsAndServicesOnChange()

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure CostingCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.CostAllocation.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure // CostingCharacteristicOnChange()

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


// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
