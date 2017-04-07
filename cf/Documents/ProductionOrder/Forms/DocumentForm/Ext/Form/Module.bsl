
////////////////////////////////////////////////////////////////////////////////
// MODULE VARIABLES

&AtClient
Var WhenChangingStart;

&AtClient
Var WhenChangingFinish;

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure fills inventories by specification.
//
&AtServer
Procedure FillBySpecificationsAtServer()
	
	Document = FormAttributeToValue("Object");
	NodesSpecificationStack = New Array;
	Document.FillTabularSectionBySpecification(NodesSpecificationStack);
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // FillBySpecificationOnServer()

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
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices));
	EndIf;
	
	StructureData.Insert("ProductsAndServicesType", StructureData.ProductsAndServices.ProductsAndServicesType);
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices, StructureData.Characteristic));
	
	Return StructureData;
	
EndFunction // GetDataCharacteristicOnChange()

// It receives data set from the server for the StructuralUnitOnChange procedure.
//
&AtServerNoContext
Function GetDataStructuralUnitOnChange(Warehouse)
	
	If Warehouse.TransferSource.StructuralUnitType = Enums.StructuralUnitsTypes.Warehouse
		OR Warehouse.TransferSource.StructuralUnitType = Enums.StructuralUnitsTypes.Department Then
		
		Return Warehouse.TransferSource;
		
	Else
		
		Return Undefined;
		
	EndIf;	
	
EndFunction // GetDataStructuralUnitOnChange()	

// Gets the data set from the server for the StructuralUnitsOnChangeReserve procedure.
//
&AtServerNoContext
Function GetDataStructuralUnitReserveOnChange(Warehouse)
	
	If Warehouse.TransferRecipient.StructuralUnitType = Enums.StructuralUnitsTypes.Warehouse
		OR Warehouse.TransferRecipient.StructuralUnitType = Enums.StructuralUnitsTypes.Department Then
		
		Return Warehouse.TransferRecipient;
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	Return Warehouse.TransferRecipient;
	
EndFunction // GetDataStructuralUnitOnChange()

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(Attribute = "BasisDocument")
	
	Document = FormAttributeToValue("Object");
	Document.Filling(Object[Attribute], );
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
EndProcedure // FillByDocument()

// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetVisibleAndEnabled()
	
	If Object.OperationKind = Enums.OperationKindsProductionOrder.Disassembly Then
		
		// Reserve.
		Items.InventoryStructuralUnitReserve.Visible = False;
		Items.InventoryReserve.Visible = False;
		Items.InventoryChangeReserve.Visible = False;
		Items.ProductionStructuralUnitReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		Items.ProductsReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		
		For Each StringInventory IN Object.Inventory Do
			StringInventory.Reserve = 0;
		EndDo;
		
		// Products and services type.
		NewParameter = New ChoiceParameter("Filter.ProductsAndServicesType", Enums.ProductsAndServicesTypes.InventoryItem);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.ProductsProductsAndServices.ChoiceParameters = NewParameters;
		
	Else
		
		// Reserve.
		Items.InventoryStructuralUnitReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		Items.InventoryReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		Items.InventoryChangeReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		Items.ProductionStructuralUnitReserve.Visible = False;
		Items.ProductsReserve.Visible = False;
		
		For Each StringProducts IN Object.Products Do
			StringProducts.Reserve = 0;
		EndDo;
		
		// Products and services type.
		NewArray = New Array();
		NewArray.Add(Enums.ProductsAndServicesTypes.InventoryItem);
		NewArray.Add(Enums.ProductsAndServicesTypes.Work);
		NewArray.Add(Enums.ProductsAndServicesTypes.Service);
		ArrayInventoryWork = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.ProductsAndServicesType", ArrayInventoryWork);
		NewParameter2 = New ChoiceParameter("Additionally.TypeRestriction", ArrayInventoryWork);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewArray.Add(NewParameter2);
		NewParameters = New FixedArray(NewArray);
		Items.ProductsProductsAndServices.ChoiceParameters = NewParameters;
		
	EndIf;
	
EndProcedure // SetVisibleAndEnabled()

// Procedure sets selection mode and selection list for the form units.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetModeAndChoiceList()
	
	If Not Constants.FunctionalOptionAccountingByMultipleDepartments.Get()
		AND Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
		
		Items.StructuralUnit.ListChoiceMode = True;
		Items.StructuralUnit.ChoiceList.Add(Catalogs.StructuralUnits.MainDepartment);
		Items.StructuralUnit.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
		
		Items.ProductionStructuralUnitReserve.ListChoiceMode = True;
		Items.ProductionStructuralUnitReserve.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
		Items.ProductionStructuralUnitReserve.ChoiceList.Add(Catalogs.StructuralUnits.MainDepartment);
		
		Items.InventoryStructuralUnitReserve.ListChoiceMode = True;
		Items.InventoryStructuralUnitReserve.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
		Items.InventoryStructuralUnitReserve.ChoiceList.Add(Catalogs.StructuralUnits.MainDepartment);
		
	EndIf;
	
EndProcedure // SetModeAndChoiceList()

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
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode IN StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("ProductsAndServices,Characteristic,MeasurementUnit",BarcodeData.ProductsAndServices,BarcodeData.Characteristic,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.ProductsAndServices = BarcodeData.ProductsAndServices;
				NewRow.Characteristic = BarcodeData.Characteristic;
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

// Procedure fills the column Reserve by free balances on stock.
//
&AtServer
Procedure FillColumnReserveByBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByBalances();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // FillColumnReserveByBalancesAtServer()

// Function checks reservation use in the document 
//
&AtServerNoContext
Function ReservationUsed(ObjectOperationKind, ObjectCustomerOrder, TabularSectionName)
	
	If Constants.FunctionalOptionInventoryReservation.Get()
		AND ValueIsFilled(ObjectCustomerOrder) Then
		
		If TabularSectionName = "Inventory" AND ObjectOperationKind = Enums.OperationKindsProductionOrder.Assembly Then
			Return True;
		ElsIf TabularSectionName = "Products" AND ObjectOperationKind = Enums.OperationKindsProductionOrder.Disassembly Then
			Return True;
		Else
			Return False;
		EndIf;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction // ReservationUsed()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR WORK WITH THE SELECTION

// Procedure - handler of the Action event of the Pick TS Inventory command.
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName 	= "Inventory";
	AreCharacteristics 	= True;
	AreBatches 			= False;
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 			Object.Date);
	SelectionParameters.Insert("Company", 		Counterparty);
	SelectionParameters.Insert("StructuralUnit", Object.StructuralUnitReserve);
	
	SelectionParameters.Insert("SpecificationsUsed",	True);
	SelectionParameters.Insert("BatchesUsed", 		False);
	SelectionParameters.Insert("ShowPriceColumn", 		False);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsProductionOrder.Assembly") Then
		SelectionParameters.Insert("ThisIsReceiptDocument", False);
		SelectionParameters.Insert("AvailableStructuralUnitEdit", True);
	Else
		SelectionParameters.Insert("ThisIsReceiptDocument", True);
		SelectionParameters.Insert("AvailableStructuralUnitEdit", False);
	EndIf;
	SelectionParameters.Insert("ReservationUsed", ReservationUsed(Object.OperationKind, Object.CustomerOrder, TabularSectionName));
	
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
	
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	
	OpenForm("CommonForm.PickForm", SelectionParameters, ThisForm);
	
EndProcedure // Selection()

// Procedure - handler of the Action event of the Pick TS Products command.
//
&AtClient
Procedure ProductsPick(Command)
	
	TabularSectionName 	= "Products";
	AreCharacteristics 	= True;
	AreBatches 			= False;
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 			Object.Date);
	SelectionParameters.Insert("Company",		Counterparty);
	SelectionParameters.Insert("StructuralUnit", Object.StructuralUnitReserve);
	
	SelectionParameters.Insert("SpecificationsUsed",	True);
	SelectionParameters.Insert("BatchesUsed", 		False);
	SelectionParameters.Insert("ShowPriceColumn",		False);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsProductionOrder.Assembly") Then
		SelectionParameters.Insert("ThisIsReceiptDocument", True);
		SelectionParameters.Insert("AvailableStructuralUnitEdit", False);
	Else
		SelectionParameters.Insert("ThisIsReceiptDocument", False);
		SelectionParameters.Insert("AvailableStructuralUnitEdit", True);
	EndIf;
	SelectionParameters.Insert("ReservationUsed", ReservationUsed(Object.OperationKind, Object.CustomerOrder, TabularSectionName));
	
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
	
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	
	OpenForm("CommonForm.PickForm", SelectionParameters, ThisForm);
	
EndProcedure // ProductsPick()

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow IN TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If TabularSectionName = "Products" Then
			
			If ValueIsFilled(ImportRow.ProductsAndServices) Then
				
				NewRow.ProductsAndServicesType = ImportRow.ProductsAndServices.ProductsAndServicesType;
				
			EndIf;
			
		EndIf;
		
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
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	Items.CustomerOrder.ReadOnly = ValueIsFilled(Object.BasisDocument);
	
	Items.Inventory.ChildItems.InventoryReserve.Visible = ValueIsFilled(Object.CustomerOrder);
	
	SetVisibleAndEnabled();
	SetModeAndChoiceList();
	
	If ValueIsFilled(Object.Ref) Then
		NotifyWorkCalendar = False;
	Else
		NotifyWorkCalendar = True;
	EndIf; 
	DocumentModified = False;
	
	If Not Constants.UseProductionOrderStates.Get() Then
		
		Items.StateGroup.Visible = False;
		
		InProcessStatus = Constants.ProductionOrdersInProgressStatus.Get();
		CompletedStatus = Constants.ProductionOrdersCompletedStatus.Get();
		
		Items.Status.ChoiceList.Add("In process", "In process");
		Items.Status.ChoiceList.Add("Completed", "Completed");
		Items.Status.ChoiceList.Add("Canceled", "Canceled");
		
		If Object.OrderState.OrderStatus = Enums.OrderStatuses.InProcess AND Not Object.Closed Then
			Status = "In process";
		ElsIf Object.OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
			Status = "Completed";
		Else
			Status = "Canceled";
		EndIf;
		
	Else
		
		Items.GroupStatuses.Visible = False;
		
	EndIf;
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, , "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
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
	
	// StandardSubsystems.ChangesProhibitionDates
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.ChangesProhibitionDates
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // OnReadAtServer()

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	WhenChangingStart = Object.Start;
	WhenChangingFinish = Object.Finish;
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
EndProcedure // OnOpen()

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	If DocumentModified Then
		NotifyWorkCalendar = True;
		DocumentModified = False;
	EndIf;
	
EndProcedure // AfterWrite()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties 
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
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
		
		InventoryAddressInStorage	= Parameter;
		CurrentPagesProducts= (Items.Pages.CurrentPage = Items.TSProducts);
		TabularSectionName		= ?(CurrentPagesProducts, "Products", "Inventory");
		
		GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, False);
		
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose()
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure // OnClose()

// Procedure-handler of the BeforeWriteAtServer event.
// Performs initial attributes forms filling.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Modified Then
		DocumentModified = True;
	EndIf;
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // BeforeWriteAtServer()

// Procedure - BeforeWrite event handler.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentProductionOrderPosting");
	// StandardSubsystems.PerformanceEstimation
	
EndProcedure // BeforeWrite()

// Procedure - event handler BeforeClose form.
//
&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If NotifyWorkCalendar Then
		Notify("ChangedProductionOrder", Object.Responsible);
	EndIf;
	
EndProcedure

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
        
        If Object.OperationKind = PredefinedValue("Enum.OperationKindsProductionOrder.Disassembly") Then
            
            If Not ValueIsFilled(Object.CustomerOrder) Then
                
                For Each StringInventory IN Object.Products Do
                    StringInventory.Reserve = 0;
                EndDo;
                Items.Products.ChildItems.ProductsReserve.Visible = False;
                
            Else
                
                If Items.Products.ChildItems.ProductsReserve.Visible = False Then
                    Items.Products.ChildItems.ProductsReserve.Visible = True;
                EndIf;
                
            EndIf;
            
        Else
            
            If Not ValueIsFilled(Object.CustomerOrder) Then
                
                For Each StringInventory IN Object.Inventory Do
                    StringInventory.Reserve = 0;
                EndDo;
                
                Items.Inventory.ChildItems.InventoryReserve.Visible = False;
                Items.InventoryChangeReserve.Visible = False;
                
            Else
                
                If Not Items.Inventory.ChildItems.InventoryReserve.Visible Then
                    Items.Inventory.ChildItems.InventoryReserve.Visible = True;
                    Items.InventoryChangeReserve.Visible = True;
                EndIf;
                
            EndIf;
            
        EndIf;
        
    EndIf;

EndProcedure  // FillExecute()

// Procedure - handler of the  FillUsingCustomerOrder click button.
//
&AtClient
Procedure FillUsingCustomerOrder(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillByCustomerOrderEnd", ThisObject), NStr("en='The document will be completely refilled according to ""Customer order""! Continue?';ru='Документ будет полностью перезаполнен по ""Заказу покупателя""! Продолжить выполнение операции?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByCustomerOrderEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocument("CustomerOrder");
    EndIf;

EndProcedure // FillByCustomerOrder()

// Procedure - command handler FillByBalance submenu ChangeReserve.
//
&AtClient
Procedure ChangeReserveFillByBalances(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='Tabular section ""Inventory"" is not filled!';ru='Табличная часть ""Запасы"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	FillColumnReserveByBalancesAtServer();
	
EndProcedure // ChangeReserveFillByBalances()

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='Tabular section ""Inventory"" is not filled!';ru='Табличная часть ""Запасы"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	For Each TabularSectionRow IN Object.Inventory Do
		TabularSectionRow.Reserve = 0;
	EndDo;
	
EndProcedure // ChangeReserveFillByBalances()

////////////////////////////////////////////////////////////////////////////////
// COMMAND ACTIONS OF THE ORDER STATES PANEL

// Procedure - event handler OnChange input field Status.
//
&AtClient
Procedure StatusOnChange(Item)
	
	If Status = "In process" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = False;
	ElsIf Status = "Completed" Then
		Object.OrderState = CompletedStatus;
		Object.Closed = True;
	ElsIf Status = "Canceled" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = True;
	EndIf;
	
	Modified = True;
	
EndProcedure // StatusOnChange()

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

// Procedure - handler of the OnChange event of the BasisDocument input field.
//
&AtClient
Procedure BasisDocumentOnChange(Item)
	
	Items.CustomerOrder.ReadOnly = ValueIsFilled(Object.BasisDocument);
	
EndProcedure // BasisDocumentOnChange()

// Procedure - handler of the OnChange event of the CustomerOrder input field.
//
&AtClient
Procedure CustomerOrderOnChange(Item)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsProductionOrder.Disassembly") Then
		
		Items.ProductionStructuralUnitReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		Items.ProductsReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		
		For Each StringProducts IN Object.Products Do
			StringProducts.Reserve = 0;
		EndDo;
		
	Else
		
		Items.InventoryStructuralUnitReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		Items.InventoryReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		Items.InventoryChangeReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		
		For Each StringInventory IN Object.Inventory Do
			StringInventory.Reserve = 0;
		EndDo;
		
	EndIf;
	
EndProcedure // CustomerOrderOnChange()

// Procedure - handler of the ChoiceProcessing of the OperationKind input field.
//
&AtClient
Procedure OperationKindChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If ValueSelected = PredefinedValue("Enum.OperationKindsProductionOrder.Disassembly") Then
		
		ProductsAndServicesTypeInventory = PredefinedValue("Enum.ProductsAndServicesTypes.InventoryItem");
		For Each StringProducts IN Object.Products Do
			
			If ValueIsFilled(StringProducts.ProductsAndServices)
				AND StringProducts.ProductsAndServicesType <> ProductsAndServicesTypeInventory Then
				
				MessageText = NStr("en='Disassembling operation is invalid for works and services!
		|The %ProductsAndServicesPresentation% products and services could be a work(service) in the %Number% string of the tabular section ""Products""';ru='Операция разборки не выполняется для работ и услуг!
		|В строке №%Номер% табличной части ""Продукция"" номенклатура ""%НоменклатураПредставление%"" является работой (услугой)'");
				MessageText = StrReplace(MessageText, "%Number%", StringProducts.LineNumber);
				MessageText = StrReplace(MessageText, "%ProductsAndServicesPresentation%", String(StringProducts.ProductsAndServices));
				
				SmallBusinessClient.ShowMessageAboutError(Object, MessageText);
				StandardProcessing = False;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure // OperationKindChoiceProcessing()

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	SetVisibleAndEnabled();
	
EndProcedure // OperationKindOnChange()

// Procedure - event handler OnChange input field Start.
//
&AtClient
Procedure StartOnChange(Item)
	
	If Object.Start > Object.Finish AND ValueIsFilled(Object.Finish) Then
		Object.Start = WhenChangingStart;
		Message(NStr("en='Start date can not be later than the end date.';ru='Дата старта не может быть больше даты финиша.'"));
	Else
		WhenChangingStart = Object.Start;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field Finish.
//
&AtClient
Procedure FinishOnChange(Item)
	
	If Hour(Object.Finish) = 0 AND Minute(Object.Finish) = 0 Then
		Object.Finish = EndOfDay(Object.Finish);
	EndIf;
	
	If Object.Finish < Object.Start Then
		Object.Finish = WhenChangingFinish;
		Message(NStr("en='Finish date can not be less than the start date.';ru='Дата финиша не может быть меньше даты старта.'"));
	Else
		WhenChangingFinish = Object.Finish;
	EndIf;
	
EndProcedure // FinishOnChange()

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	If ValueIsFilled(Object.StructuralUnit)
		AND Not ValueIsFilled(Object.StructuralUnitReserve) Then
		
		DataStructuralUnitReserve = GetDataStructuralUnitOnChange(Object.StructuralUnit);
		Object.StructuralUnitReserve = DataStructuralUnitReserve;
		
	EndIf;
	
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

// Procedure - handler of the OnChange event of the StructuralUnitReserve input field.
//
&AtClient
Procedure StructuralUnitReserveOnChange(Item)
	
	If ValueIsFilled(Object.StructuralUnitReserve)
		AND Not ValueIsFilled(Object.StructuralUnit) Then
		
		DataStructuralUnit = GetDataStructuralUnitReserveOnChange(Object.StructuralUnitReserve);
		Object.StructuralUnit = DataStructuralUnit;
		
	EndIf;
	
EndProcedure // StructuralUnitReserveOnChange()

// Procedure - handler of the Opening event of the StructuralUnitReserve input field.
//
&AtClient
Procedure ProductsStructuralUnitReserveOpen(Item, StandardProcessing)
	
	If Items.ProductionStructuralUnitReserve.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnitReserve) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // ProductsStructuralUnitReserveOpening()

// Procedure - handler of the Opening event of the StructuralUnitReserve input field.
//
&AtClient
Procedure InventoryStructuralUnitReserveOpen(Item, StandardProcessing)
	
	If Items.InventoryStructuralUnitReserve.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnitReserve) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // InventoryStructuralUnitReserveOpen()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM TABULAR SECTIONS COMMAND PANELS ACTIONS

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CommandFillBySpecification(Command)
	
	If Object.Inventory.Count() <> 0 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("CommandToFillBySpecificationEnd", ThisObject), NStr("en='Tabular section ""Materials"" will be refilled! Continue?';ru='Табличная часть ""Материалы"" будет перезаполнена! Продолжить?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
		
	EndIf;
	
	CommandToFillBySpecificationFragment();
EndProcedure

&AtClient
Procedure CommandToFillBySpecificationEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    CommandToFillBySpecificationFragment();

EndProcedure

&AtClient
Procedure CommandToFillBySpecificationFragment()
    
    FillBySpecificationsAtServer();

EndProcedure // CommandFillBySpecification()


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
	
	TabularSectionRow.ProductsAndServicesType = StructureData.ProductsAndServicesType;
	
EndProcedure // ProductsProductsAndServicesOnChange()

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

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENTS HANDLERS OF THE ENTERPRISE RESOURCES TABULAR SECTION ATTRIBUTES

// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
&AtClient
Function CalculateDuration(CurrentRow)
	
	DurationInSeconds = CurrentRow.Finish - CurrentRow.Start;
	Hours = Int(DurationInSeconds / 3600);
	Minutes = (DurationInSeconds - Hours * 3600) / 60;
	Duration = Date(0001, 01, 01, Hours, Minutes, 0);
	
	Return Duration;
	
EndFunction // CalculateDuration()

// It receives data set from the server for the EnterpriseResourcesOnStartEdit procedure.
//
&AtClient
Function GetDataEnterpriseResourcesOnStartEdit(DataStructure)
	
	DataStructure.Start = Object.Start - Second(Object.Start);
	DataStructure.Finish = Object.Finish - Second(Object.Finish);
	
	If ValueIsFilled(DataStructure.Start) AND ValueIsFilled(DataStructure.Finish) Then
		If BegOfDay(DataStructure.Start) <> BegOfDay(DataStructure.Finish) Then
			DataStructure.Finish = EndOfDay(DataStructure.Start) - 59;
		EndIf;
		If DataStructure.Start >= DataStructure.Finish Then
			DataStructure.Finish = DataStructure.Start + 1800;
			If BegOfDay(DataStructure.Finish) <> BegOfDay(DataStructure.Start) Then
				If EndOfDay(DataStructure.Start) = DataStructure.Start Then
					DataStructure.Start = DataStructure.Start - 29 * 60;
				EndIf;
				DataStructure.Finish = EndOfDay(DataStructure.Start) - 59;
			EndIf;
		EndIf;
	ElsIf ValueIsFilled(DataStructure.Start) Then
		DataStructure.Start = DataStructure.Start;
		DataStructure.Finish = EndOfDay(DataStructure.Start) - 59;
		If DataStructure.Finish = DataStructure.Start Then
			DataStructure.Start = BegOfDay(DataStructure.Start);
		EndIf;
	ElsIf ValueIsFilled(DataStructure.Finish) Then
		DataStructure.Start = BegOfDay(DataStructure.Finish);
		DataStructure.Finish = DataStructure.Finish;
		If DataStructure.Finish = DataStructure.Start Then
			DataStructure.Finish = EndOfDay(DataStructure.Finish) - 59;
		EndIf;
	Else
		DataStructure.Start = BegOfDay(CurrentDate());
		DataStructure.Finish = EndOfDay(CurrentDate()) - 59;
	EndIf;
	
	DurationInSeconds = DataStructure.Finish - DataStructure.Start;
	Hours = Int(DurationInSeconds / 3600);
	Minutes = (DurationInSeconds - Hours * 3600) / 60;
	Duration = Date(0001, 01, 01, Hours, Minutes, 0);
	DataStructure.Duration = Duration;
	
	Return DataStructure;
	
EndFunction // GetDataEnterpriseResourcesOnStartEdit()

// Procedure - event handler OnStartEdit tabular section EnterpriseResources.
//
&AtClient
Procedure EnterpriseResourcesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		TabularSectionRow = Items.EnterpriseResources.CurrentData;
		
		DataStructure = New Structure;
		DataStructure.Insert("Start", '00010101');
		DataStructure.Insert("Finish", '00010101');
		DataStructure.Insert("Duration", '00010101');
		
		DataStructure = GetDataEnterpriseResourcesOnStartEdit(DataStructure);
		TabularSectionRow.Start = DataStructure.Start;
		TabularSectionRow.Finish = DataStructure.Finish;
		TabularSectionRow.Duration = DataStructure.Duration;
		
	EndIf;
	
EndProcedure // EnterpriseResourcesOnStartEdit()

// Procedure - event handler OnChange input field EnterpriseResource.
//
&AtClient
Procedure EnterpriseResourcesEnterpriseResourceOnChange(Item)
	
	TabularSectionRow = Items.EnterpriseResources.CurrentData;
	TabularSectionRow.Capacity = 1;
	
EndProcedure // EnterpriseResourcesEnterpriseResourceOnChange()

// Procedure - event handler OnChange input field Day.
//
&AtClient
Procedure EnterpriseResourcesDayOnChange(Item)
	
	CurrentRow = Items.EnterpriseResources.CurrentData;
	
	If CurrentRow.Start = '00010101' Then
		CurrentRow.Start = CurrentDate();
	EndIf;
	
	FinishInSeconds = Hour(CurrentRow.Finish) * 3600 + Minute(CurrentRow.Finish) * 60;
	DurationInSeconds = Hour(CurrentRow.Duration) * 3600 + Minute(CurrentRow.Duration) * 60;
	CurrentRow.Finish = BegOfDay(CurrentRow.Start) + FinishInSeconds;
	CurrentRow.Start = CurrentRow.Finish - DurationInSeconds;
	
EndProcedure // EnterpriseResourcesDayOnChange()

// Procedure - event handler OnChange input field Duration.
//
&AtClient
Procedure EnterpriseResourcesDurationOnChange(Item)
	
	CurrentRow = Items.EnterpriseResources.CurrentData;
	DurationInSeconds = Hour(CurrentRow.Duration) * 3600 + Minute(CurrentRow.Duration) * 60;
	If DurationInSeconds = 0 Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
	Else
		CurrentRow.Finish = CurrentRow.Start + DurationInSeconds;
	EndIf;
	If BegOfDay(CurrentRow.Start) <> BegOfDay(CurrentRow.Finish) Then
		CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
	EndIf;
	If CurrentRow.Start >= CurrentRow.Finish Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
		If BegOfDay(CurrentRow.Finish) <> BegOfDay(CurrentRow.Start) Then
			If EndOfDay(CurrentRow.Start) = CurrentRow.Start Then
				CurrentRow.Start = CurrentRow.Start - 29 * 60;
			EndIf;
			CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
		EndIf;
	EndIf;
	
	CurrentRow.Duration = CalculateDuration(CurrentRow);
	
EndProcedure // EnterpriseResourcesDurationOnChange()

// Procedure - event handler OnChange input field Start.
//
&AtClient
Procedure EnterpriseResourcesStartOnChange(Item)
	
	CurrentRow = Items.EnterpriseResources.CurrentData;
	
	If CurrentRow.Start = '00010101' Then
		CurrentRow.Start = BegOfDay(CurrentRow.Finish);
	EndIf;
	
	If CurrentRow.Start >= CurrentRow.Finish Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
		If BegOfDay(CurrentRow.Finish) <> BegOfDay(CurrentRow.Start) Then
			If EndOfDay(CurrentRow.Start) = CurrentRow.Start Then
				CurrentRow.Start = CurrentRow.Start - 29 * 60;
			EndIf;
			CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
		EndIf;
	EndIf;
	
	CurrentRow.Duration = CalculateDuration(CurrentRow);
	
EndProcedure // EnterpriseResourcesStartOnChange()

// Procedure - event handler OnChange input field Finish.
//
&AtClient
Procedure EnterpriseResourcesFinishOnChange(Item)
	
	CurrentRow = Items.EnterpriseResources.CurrentData;
	
	If Hour(CurrentRow.Finish) = 0 AND Minute(CurrentRow.Finish) = 0 Then
		CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
	EndIf;
	If CurrentRow.Start >= CurrentRow.Finish Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
		If BegOfDay(CurrentRow.Finish) <> BegOfDay(CurrentRow.Start) Then
			If EndOfDay(CurrentRow.Start) = CurrentRow.Start Then
				CurrentRow.Start = CurrentRow.Start - 29 * 60;
			EndIf;
			CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
		EndIf;
	EndIf;
	
	CurrentRow.Duration = CalculateDuration(CurrentRow);
	
EndProcedure // EnterpriseResourcesFinishOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TOOLTIP EVENTS HANDLERS

&AtClient
Procedure StatusExtendedTooltipNavigationLinkProcessing(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("DataProcessor.AdministrationPanelSB.Form.SectionProduction");
	
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

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties()
PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm);
EndProcedure

// End StandardSubsystems.Properties

#EndRegion