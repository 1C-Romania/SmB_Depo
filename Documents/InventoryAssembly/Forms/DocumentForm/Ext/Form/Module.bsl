
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure fills in Inventory by specification.
//
&AtServer
Procedure FillBySpecificationsAtServer()
	
	Document = FormAttributeToValue("Object");
	NodesSpecificationStack = New Array;
	Document.FillTabularSectionBySpecification(NodesSpecificationStack);
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // FillMaterialCostsOnServerSpecification()

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
Function GetDataStructuralUnitOnChange(StructureData)
	
	If StructureData.Division.TransferRecipient.StructuralUnitType = Enums.StructuralUnitsTypes.Warehouse
		OR StructureData.Division.TransferRecipient.StructuralUnitType = Enums.StructuralUnitsTypes.Division Then
		
		StructureData.Insert("ProductsStructuralUnit", StructureData.Division.TransferRecipient);
		StructureData.Insert("ProductsCell", StructureData.Division.TransferRecipientCell);
		
	Else
		
		StructureData.Insert("ProductsStructuralUnit", Undefined);
		StructureData.Insert("ProductsCell", Undefined);
		
	EndIf;
	
	If StructureData.Division.TransferSource.StructuralUnitType = Enums.StructuralUnitsTypes.Warehouse
		OR StructureData.Division.TransferSource.StructuralUnitType = Enums.StructuralUnitsTypes.Division Then
		
		StructureData.Insert("InventoryStructuralUnit", StructureData.Division.TransferSource);
		StructureData.Insert("CellInventory", StructureData.Division.TransferSourceCell);
		
	Else
		
		StructureData.Insert("InventoryStructuralUnit", Undefined);
		StructureData.Insert("CellInventory", Undefined);
		
	EndIf;
	
	StructureData.Insert("DisposalsStructuralUnit", StructureData.Division.RecipientOfWastes);
	StructureData.Insert("DisposalsCell", StructureData.Division.DisposalsRecipientCell);
	
	StructureData.Insert("OrderWarehouse", Not StructureData.Division.OrderWarehouse);
	StructureData.Insert("OrderWarehouseOfProducts", Not StructureData.Division.TransferRecipient.OrderWarehouse);
	StructureData.Insert("OrderWarehouseWaste", Not StructureData.Division.RecipientOfWastes.OrderWarehouse);
	StructureData.Insert("OrderWarehouseOfInventory", Not StructureData.Division.TransferSource.OrderWarehouse);
	
	Return StructureData;
	
EndFunction // GetDataStructuralUnitOnChange()

// Receives data set from the server for CellOnChange procedure.
//
&AtServerNoContext
Function GetDataCellOnChange(StructureData)
	
	If StructureData.StructuralUnit = StructureData.ProductsStructuralUnit Then
		
		If StructureData.StructuralUnit.TransferRecipient <> StructureData.ProductsStructuralUnit
			OR StructureData.StructuralUnit.TransferRecipientCell <> StructureData.ProductsCell Then
			
			StructureData.Insert("NewGoodsCell", StructureData.Cell);
			
		EndIf;
		
	EndIf;
	
	If StructureData.StructuralUnit = StructureData.InventoryStructuralUnit Then
		
		If StructureData.StructuralUnit.TransferSource <> StructureData.InventoryStructuralUnit
			OR StructureData.StructuralUnit.TransferSourceCell <> StructureData.CellInventory Then
			
			StructureData.Insert("NewCellInventory", StructureData.Cell);
			
		EndIf;
		
	EndIf;
	
	If StructureData.StructuralUnit = StructureData.DisposalsStructuralUnit Then
		
		If StructureData.StructuralUnit.RecipientOfWastes <> StructureData.DisposalsStructuralUnit
			OR StructureData.StructuralUnit.DisposalsRecipientCell <> StructureData.DisposalsCell Then
			
			StructureData.Insert("NewCellWastes", StructureData.Cell);
			
		EndIf;
		
	EndIf;
	
	Return StructureData;
	
EndFunction // GetDataCellOnChange()

// It receives data set from the server for the StructuralUnitOnChange procedure.
//
&AtServerNoContext
Function GetDataStructuralUnitProductsInventoryDisposalsOnChange(StructureData)
	
	StructureData.Insert("OrderWarehouse", Not StructureData.Warehouse.OrderWarehouse);
	
	Return StructureData;
	
EndFunction // GetDataStructuralUnitProductsInventoryDisposalsOnChange()

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(AttributeBasis = "BasisDocument")
	
	Document = FormAttributeToValue("Object");
	Document.Filling(Object[AttributeBasis], );
	ValueToFormAttribute(Document, "Object");
	
	SetVisibleAndEnabled();
	
EndProcedure // FillByDocument()

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
			TSRowsArray = Object.Inventory.FindRows(New Structure("ProductsAndServices,Characteristic,Batch,MeasurementUnit",BarcodeData.ProductsAndServices,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.ProductsAndServices = BarcodeData.ProductsAndServices;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.CostPercentage = 1;
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
		
		MessageString = NStr("en = 'Data by barcode is not found: %1%; quantity: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

// End Peripherals

// The procedure fills in column Reserve by reserves for the order.
//
&AtServer
Procedure FillColumnReserveByReservesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByReserves();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // FillColumnReserveByReservesAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetVisibleAndEnabled()
	
	If Object.OperationKind = Enums.OperationKindsInventoryAssembly.Disassembly Then
		
		// Reserve.
		Items.InventoryReserve.Visible = False;
		ReservationUsed = False;
		Items.InventoryChangeReserve.Visible = False;
		Items.ProductsReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		Items.InventoryCostPercentage.Visible = True;
		
		// Batch status.
		NewArray = New Array();
		NewArray.Add(Enums.BatchStatuses.OwnInventory);
		NewArray.Add(Enums.BatchStatuses.CommissionMaterials);
		ArrayInventoryWork = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.Status", ArrayInventoryWork);
		NewParameter2 = New ChoiceParameter("Additionally.StatusRestriction", ArrayInventoryWork);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewArray.Add(NewParameter2);
		NewParameters = New FixedArray(NewArray);
		Items.ProductsBatch.ChoiceParameters = NewParameters;
		
		Items.GroupWarehouseProductsAssembling.Visible = False;
		Items.GroupWarehouseProductsDisassembling.Visible = True;
		
		Items.GroupWarehouseInventoryAssembling.Visible = False;
		Items.GroupWarehouseInventoryDisassembling.Visible = True;
		
	Else
		
		// Reserve.
		Items.InventoryReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		ReservationUsed = ValueIsFilled(Object.CustomerOrder);
		Items.InventoryChangeReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		Items.ProductsReserve.Visible = False;
		Items.InventoryCostPercentage.Visible = False;
		
		// Batch status.
		NewParameter = New ChoiceParameter("Filter.Status", Enums.BatchStatuses.OwnInventory);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.ProductsBatch.ChoiceParameters = NewParameters;
		
		For Each StringProducts IN Object.Products Do
			
			If ValueIsFilled(StringProducts.Batch)
				AND StringProducts.Batch.Status = Enums.BatchStatuses.CommissionMaterials Then
				StringProducts.Batch = Undefined;
			EndIf;
			
		EndDo;
		
		Items.GroupWarehouseProductsAssembling.Visible = True;
		Items.GroupWarehouseProductsDisassembling.Visible = False;
		
		Items.GroupWarehouseInventoryAssembling.Visible = True;
		Items.GroupWarehouseInventoryDisassembling.Visible = False;
		
	EndIf;
	
EndProcedure // SetVisibleAndEnabled()

// Procedure sets selection mode and selection list for the form units.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetModeAndChoiceList()
	
	If Not ValueIsFilled(Object.StructuralUnit)
		OR Object.StructuralUnit.OrderWarehouse Then
		Items.Cell.Enabled = False;
	EndIf;
		
	If Not ValueIsFilled(Object.ProductsStructuralUnit)
		OR Object.ProductsStructuralUnit.OrderWarehouse Then
		Items.ProductsCellAssembling.Enabled = False;
		Items.CellInventoryDisassembling.Enabled = False;
	EndIf;
	
	If Not ValueIsFilled(Object.InventoryStructuralUnit)
		OR Object.InventoryStructuralUnit.OrderWarehouse Then
		Items.CellInventoryAssembling.Enabled = False;
		Items.ProductsCellDisassembling.Enabled = False;
	EndIf;
	
	If Not ValueIsFilled(Object.DisposalsStructuralUnit)
		OR Object.DisposalsStructuralUnit.OrderWarehouse Then
		Items.DisposalsCell.Enabled = False;
	EndIf;
	
	If Not Constants.FunctionalOptionAccountingByMultipleDivisions.Get()
		AND Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
		
		Items.StructuralUnit.ListChoiceMode = True;
		Items.StructuralUnit.ChoiceList.Add(Catalogs.StructuralUnits.MainDivision);
		Items.StructuralUnit.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
		
		Items.ProductsStructuralUnitAssembling.ListChoiceMode = True;
		Items.ProductsStructuralUnitAssembling.ChoiceList.Add(Catalogs.StructuralUnits.MainDivision);
		Items.ProductsStructuralUnitAssembling.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
		
		Items.ProductsStructuralUnitDisassembling.ListChoiceMode = True;
		Items.ProductsStructuralUnitDisassembling.ChoiceList.Add(Catalogs.StructuralUnits.MainDivision);
		Items.ProductsStructuralUnitDisassembling.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
		
		Items.InventoryStructuralUnitAssembling.ListChoiceMode = True;
		Items.InventoryStructuralUnitAssembling.ChoiceList.Add(Catalogs.StructuralUnits.MainDivision);
		Items.InventoryStructuralUnitAssembling.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
		
		Items.InventoryStructuralUnitDisassembling.ListChoiceMode = True;
		Items.InventoryStructuralUnitDisassembling.ChoiceList.Add(Catalogs.StructuralUnits.MainDivision);
		Items.InventoryStructuralUnitDisassembling.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
		
		Items.DisposalsStructuralUnit.ListChoiceMode = True;
		Items.DisposalsStructuralUnit.ChoiceList.Add(Catalogs.StructuralUnits.MainDivision);
		Items.DisposalsStructuralUnit.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
		
	EndIf;
	
EndProcedure // SetModeAndChoiceList()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR WORK WITH THE SELECTION

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName 	= "Inventory";
	SelectionMarker = "Inventory";
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 		Object.Date);
	SelectionParameters.Insert("Company", 	SubsidiaryCompany);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsInventoryAssembly.Assembly") Then
		SelectionParameters.Insert("StructuralUnit", Object.InventoryStructuralUnit);
	Else
		SelectionParameters.Insert("StructuralUnit", Object.ProductsStructuralUnit);
	EndIf;
	
	SelectionParameters.Insert("SpecificationsUsed", True);
	SelectionParameters.Insert("ReservationUsed", ReservationUsed);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsInventoryAssembly.Assembly") Then
		SelectionParameters.Insert("ThisIsReceiptDocument", False);
		SelectionParameters.Insert("AvailableStructuralUnitEdit", True);
	Else
		SelectionParameters.Insert("ThisIsReceiptDocument", True);
		SelectionParameters.Insert("AvailableStructuralUnitEdit", False);
	EndIf;
	
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
	
EndProcedure // Selection()

// Procedure - handler of the Action event of the Pick TS Products command.
//
&AtClient
Procedure ProductsPick(Command)
	
	TabularSectionName = "Products";
	SelectionMarker = "Products";
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 		Object.Date);
	SelectionParameters.Insert("Company",	SubsidiaryCompany);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsInventoryAssembly.Assembly") Then
		SelectionParameters.Insert("StructuralUnit", Object.ProductsStructuralUnit);
	Else
		SelectionParameters.Insert("StructuralUnit", Object.InventoryStructuralUnit);
	EndIf;
	
	SelectionParameters.Insert("SpecificationsUsed", True);
	SelectionParameters.Insert("ReservationUsed", ReservationUsed);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsInventoryAssembly.Assembly") Then
		SelectionParameters.Insert("ThisIsReceiptDocument", True);
		SelectionParameters.Insert("AvailableStructuralUnitEdit", False);
	Else
		SelectionParameters.Insert("ThisIsReceiptDocument", False);
		SelectionParameters.Insert("AvailableStructuralUnitEdit", True);
	EndIf;
	
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
	
EndProcedure // ProductsPick()

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure DisposalsPick(Command)
	
	TabularSectionName 	= "Disposals";
	SelectionMarker = "Disposals";
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 				Object.Date);
	SelectionParameters.Insert("Company", 			SubsidiaryCompany);
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

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
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
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
    
    CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
    
    
    If Not IsBlankString(CurBarcode) Then
        BarcodesReceived(New Structure("Barcode, Quantity, CostPercentage", CurBarcode, 1, 1));
    EndIf;

EndProcedure // SearchByBarcode()

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en='It is required to select a line to get weight for it.'"));
		
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
			MessageText = NStr("en = 'Electronic scales returned zero weight.'");
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
	
	SetVisibleAndEnabled();
	SetModeAndChoiceList();
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// Peripherals.
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

// Procedure - BeforeWrite event handler.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentInventoryAssemblyPosting");
	// StandardSubsystems.PerformanceEstimation
	
EndProcedure // BeforeWrite()

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	If ValueIsFilled(Object.BasisDocument) Then
		Notify("Record_InventoryAssembly", Object.Ref);
	EndIf;
	
EndProcedure // AfterWrite()

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
				Data.Add(New Structure("Barcode, Quantity, CostPercentage", Parameter[0], 1, 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity, CostPercentage", Parameter[1][1], 1, 1)); // Get a barcode from the additional data
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
		
		If SelectionMarker = "Products" Then
			
			TabularSectionName = "Products";
			
		ElsIf SelectionMarker = "Inventory" Then
			
			TabularSectionName = "Inventory";
			
		ElsIf SelectionMarker = "Disposals" Then
			
			TabularSectionName = "Disposals";
			
		EndIf;
		
		GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
		
	EndIf;
	
EndProcedure // NotificationProcessing()

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose()
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure // OnClose()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - handler of clicking the FillByBasis button.
//
&AtClient
Procedure FillByBasis(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en = 'Document will be completely refilled by ""Basis""! Continue?'"), QuestionDialogMode.YesNo, 0);

EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        
        FillByDocument();
        
        If Object.OperationKind = PredefinedValue("Enum.OperationKindsInventoryAssembly.Disassembly") Then
            
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
                ReservationUsed = False;
                
            Else
                
                If Items.Inventory.ChildItems.InventoryReserve.Visible = False Then
                    Items.Inventory.ChildItems.InventoryReserve.Visible = True;
                    Items.InventoryChangeReserve.Visible = True;
                    ReservationUsed = True;
                EndIf;
                
            EndIf;
            
        EndIf;
        
    EndIf;

EndProcedure  // FillByBasis()

// Procedure - handler of the  FillUsingCustomerOrder click button.
//
&AtClient
Procedure FillUsingCustomerOrder(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillByCustomerOrderEnd", ThisObject), NStr("en = 'The document will be completely refilled according to ""Customer order""! Continue?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByCustomerOrderEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocument("CustomerOrder");
    EndIf;

EndProcedure // FillByCustomerOrder()

// Procedure - command handler FillByReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeReserveFillByReserves(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Tabular section ""Inventory and services"" is not filled!'");
		Message.Message();
		Return;
	EndIf;
	
	FillColumnReserveByReservesAtServer();
	
EndProcedure // ChangeReserveFillByReserves()

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'Tabular section ""Inventory and services"" is not filled!'");
		Message.Message();
		Return;
	EndIf;
	
	For Each TabularSectionRow IN Object.Inventory Do
		TabularSectionRow.Reserve = 0;
	EndDo;
	
EndProcedure // ChangeReserveFillByBalances()

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
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsInventoryAssembly.Disassembly") Then
		
		Items.ProductsReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		
		For Each StringProducts IN Object.Products Do
			StringProducts.Reserve = 0;
		EndDo;
		
	Else
		
		Items.InventoryReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		Items.InventoryChangeReserve.Visible = ValueIsFilled(Object.CustomerOrder);
		
		For Each StringInventory IN Object.Inventory Do
			StringInventory.Reserve = 0;
		EndDo;
		
		ReservationUsed = ValueIsFilled(Object.CustomerOrder);
		
	EndIf;
	
EndProcedure // CustomerOrderOnChange()

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	SetVisibleAndEnabled();
	
EndProcedure // OperationKindOnChange()

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

////////////////////////////////////////////////////////////////////////////////
// Structural unit - MANUFACTURER

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	If ValueIsFilled(Object.StructuralUnit) Then
	
		StructureData = New Structure();
		StructureData.Insert("Division", Object.StructuralUnit);
		
		StructureData = GetDataStructuralUnitOnChange(StructureData);
		
		Items.Cell.Enabled = StructureData.OrderWarehouse;
		
		If ValueIsFilled(StructureData.ProductsStructuralUnit) Then
			Object.ProductsStructuralUnit = StructureData.ProductsStructuralUnit;
			Object.ProductsCell = StructureData.ProductsCell;
			Items.ProductsCellAssembling.Enabled = StructureData.OrderWarehouseOfProducts;
			Items.ProductsCellDisassembling.Enabled = StructureData.OrderWarehouseOfProducts;
			
		Else
			Object.ProductsStructuralUnit = Object.StructuralUnit;
			Object.ProductsCell = Object.Cell;
			Items.ProductsCellAssembling.Enabled = StructureData.OrderWarehouse;
			Items.ProductsCellDisassembling.Enabled = StructureData.OrderWarehouse;
			
		EndIf;
		
		If ValueIsFilled(StructureData.InventoryStructuralUnit) Then
			Object.InventoryStructuralUnit = StructureData.InventoryStructuralUnit;
			Object.CellInventory = StructureData.CellInventory;
			Items.CellInventoryAssembling.Enabled = StructureData.OrderWarehouseOfInventory;
			Items.CellInventoryDisassembling.Enabled = StructureData.OrderWarehouseOfInventory;
			
		Else
			Object.InventoryStructuralUnit = Object.StructuralUnit;
			Object.CellInventory = Object.Cell;
			Items.CellInventoryAssembling.Enabled = StructureData.OrderWarehouse;
			Items.CellInventoryDisassembling.Enabled = StructureData.OrderWarehouse;
			
		EndIf;
		
		If ValueIsFilled(StructureData.DisposalsStructuralUnit) Then
			Object.DisposalsStructuralUnit = StructureData.DisposalsStructuralUnit;
			Object.DisposalsCell = StructureData.DisposalsCell;
			Items.DisposalsCell.Enabled = StructureData.OrderWarehouseWaste;
			
		Else
			Object.DisposalsStructuralUnit = Object.StructuralUnit;
			Object.DisposalsCell = Object.Cell;
			Items.DisposalsCell.Enabled = StructureData.OrderWarehouse;
			
		EndIf;
		
	Else
		
		Items.Cell.Enabled = False;
		
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

// Procedure - OnChange event handler of the Cell input field.
//
&AtClient
Procedure CellOnChange(Item)
	
	StructureData = New Structure();
	StructureData.Insert("StructuralUnit", Object.StructuralUnit);
	StructureData.Insert("Cell", Object.Cell);
	StructureData.Insert("ProductsStructuralUnit", Object.ProductsStructuralUnit);
	StructureData.Insert("ProductsCell", Object.ProductsCell);
	StructureData.Insert("InventoryStructuralUnit", Object.InventoryStructuralUnit);
	StructureData.Insert("CellInventory", Object.CellInventory);
	StructureData.Insert("DisposalsStructuralUnit", Object.DisposalsStructuralUnit);
	StructureData.Insert("DisposalsCell", Object.DisposalsCell);
	
	StructureData = GetDataCellOnChange(StructureData);
	
	If StructureData.Property("NewGoodsCell") Then
		Object.ProductsCell = StructureData.NewGoodsCell;
	EndIf;
	
	If StructureData.Property("NewCellInventory") Then
		Object.CellInventory = StructureData.NewCellInventory;
	EndIf;
	
	If StructureData.Property("NewCellWastes") Then
		Object.DisposalsCell = StructureData.NewCellWastes;
	EndIf;
	
EndProcedure // CellOnChange()

////////////////////////////////////////////////////////////////////////////////
// Structural unit - PRODUCTION (RECIPIENT - ASSEMBLY)

// Procedure - OnChange event handler of the ProductsStructuralUnitAssembling input field.
//
&AtClient
Procedure ProductsStructuralUnitAssemblingOnChange(Item)
	
	If Not ValueIsFilled(Object.ProductsStructuralUnit) Then
		
		Items.ProductsCellAssembling.Enabled = False;
		
	Else
		
		StructureData = New Structure();
		StructureData.Insert("Warehouse", Object.ProductsStructuralUnit);
	
		StructureData = GetDataStructuralUnitProductsInventoryDisposalsOnChange(StructureData);
	
		Items.ProductsCellAssembling.Enabled = StructureData.OrderWarehouse;
	
	EndIf;
	
EndProcedure // ProductsStructuralUnitAssemblingOnChange()

// Procedure - Open event handler of ProductsStructuralUnitAssembling field.
//
&AtClient
Procedure StructuralUnitOfProductAssemblyOpening(Item, StandardProcessing)
	
	If Items.ProductsStructuralUnitAssembling.ListChoiceMode
		AND Not ValueIsFilled(Object.ProductsStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // StructuralUnitOfProductAssemblyOpening()

////////////////////////////////////////////////////////////////////////////////
// Structural unit - PRODUCTS (WRITE OFF FROM - DISASSEMBLY)

// Procedure - OnChange event handler of the ProductsStructuralUnitDisassembling input field.
//
&AtClient
Procedure ProductsStructuralUnitDisassemblingOnChange(Item)
	
	If Not ValueIsFilled(Object.InventoryStructuralUnit) Then
		
		Items.ProductsCellDisassembling.Enabled = False;
		
	Else
		
		StructureData = New Structure();
		StructureData.Insert("Warehouse", Object.InventoryStructuralUnit);
	
		StructureData = GetDataStructuralUnitProductsInventoryDisposalsOnChange(StructureData);
	
		Items.ProductsCellDisassembling.Enabled = StructureData.OrderWarehouse;
	
	EndIf;
	
EndProcedure // ProductsStructuralUnitDisassemblingOnChange()

// Procedure - Open event handler of ProductsStructuralUnitDisassembling field.
//
&AtClient
Procedure ProductsStructuralUnitDisassemblingOpen(Item, StandardProcessing)
	
	If Items.ProductsStructuralUnitDisassembling.ListChoiceMode
		AND Not ValueIsFilled(Object.InventoryStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // ProductsStructuralUnitDisassemblingOpen()

////////////////////////////////////////////////////////////////////////////////
// Structural unit - INVENTORY (WRITE OFF FROM - ASSEMBLY)

// Procedure - OnChange event handler of the InventoryStructuralUnitAssembling input field.
//
&AtClient
Procedure InventoryStructuralUnitAssemblingOnChange(Item)
	
	If Not ValueIsFilled(Object.InventoryStructuralUnit) Then
		
		Items.CellInventoryAssembling.Enabled = False;
		
	Else
		
		StructureData = New Structure();
		StructureData.Insert("Warehouse", Object.InventoryStructuralUnit);
	
		StructureData = GetDataStructuralUnitProductsInventoryDisposalsOnChange(StructureData);
	
		Items.CellInventoryAssembling.Enabled = StructureData.OrderWarehouse;
	
	EndIf;
	
EndProcedure // InventoryStructuralUnitAssemblingOnChange()

// Procedure - Open event handler of InventoryStructuralUnitAssembling field.
//
&AtClient
Procedure InventoryStructuralUnitInAssemblingOpen(Item, StandardProcessing)
	
	If Items.InventoryStructuralUnitAssembling.ListChoiceMode
		AND Not ValueIsFilled(Object.InventoryStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // InventoryStructuralUnitInAssemblingOpen()

////////////////////////////////////////////////////////////////////////////////
// Structural unit - INVENTORY (RECIPIENT - DISASSEMBLY)

// Procedure - OnChange event handler of the InventoryStructuralUnitDisassembling input field.
//
&AtClient
Procedure InventoryStructuralUnitDisassemblyOnChange(Item)
	
	If Not ValueIsFilled(Object.ProductsStructuralUnit) Then
		
		Items.CellInventoryDisassembling.Enabled = False;
		
	Else
		
		StructureData = New Structure();
		StructureData.Insert("Warehouse", Object.ProductsStructuralUnit);
	
		StructureData = GetDataStructuralUnitProductsInventoryDisposalsOnChange(StructureData);
	
		Items.CellInventoryDisassembling.Enabled = StructureData.OrderWarehouse;
	
	EndIf;
	
EndProcedure // InventoryStructuralUnitDisassemblyOnChange()

// Procedure - Handler of event Opening InventoryStructuralUnitDisassembling field.
//
&AtClient
Procedure InventoryStructuralUnitDisassemblyOpening(Item, StandardProcessing)
	
	If Items.InventoryStructuralUnitDisassembling.ListChoiceMode
		AND Not ValueIsFilled(Object.ProductsStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // InventoryStructuralUnitDisassemblyOpening()

////////////////////////////////////////////////////////////////////////////////
// Structural unit - Recipient

// Procedure - OnChange event handler of the DisposalsStructuralUnit input field.
//
&AtClient
Procedure DisposalsStructuralUnitOnChange(Item)
	
	If Not ValueIsFilled(Object.DisposalsStructuralUnit) Then
		
		Items.DisposalsCell.Enabled = False;
		
	Else
		
		StructureData = New Structure();
		StructureData.Insert("Warehouse", Object.DisposalsStructuralUnit);
	
		StructureData = GetDataStructuralUnitProductsInventoryDisposalsOnChange(StructureData);
	
		Items.DisposalsCell.Enabled = StructureData.OrderWarehouse;
	
	EndIf;
	
EndProcedure // DisposalsStructuralUnitOnChange()

// Procedure - Open event handler of DisposalsStructuralUnit field.
//
&AtClient
Procedure DisposalsStructuralUnitOpening(Item, StandardProcessing)
	
	If Items.DisposalsStructuralUnit.ListChoiceMode
		AND Not ValueIsFilled(Object.DisposalsStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // DisposalsStructuralUnitOpening()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM TABULAR SECTIONS COMMAND PANELS ACTIONS

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CommandFillBySpecification(Command)
	
	If Object.Inventory.Count() <> 0 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("CommandToFillBySpecificationEnd", ThisObject), NStr("en = 'Tabular section ""Materials"" will be refilled! Continue?'"), 
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
	
	StructureData = New Structure();
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Specification = StructureData.Specification;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.CostPercentage = 1;
	
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
// PROCEDURE - EVENT HANDLERS OF THE DISPOSALS TABULAR SECTION ATTRIBUTES

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure DisposalsProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Disposals.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
EndProcedure // DisposalsProductsAndServicesOnChange()

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
