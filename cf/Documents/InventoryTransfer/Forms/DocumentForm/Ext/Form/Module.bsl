
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Filling(BasisDocument,);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
EndProcedure // FillByDocument()

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
Function GetCompanyDataOnChange(Company, DocumentDate)
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", SmallBusinessServer.GetCompany(Company));
	
	ResponsiblePersons		= SmallBusinessServer.OrganizationalUnitsResponsiblePersons(Company, DocumentDate);
	
	StructureData.Insert("Head", ResponsiblePersons.Head);
	StructureData.Insert("HeadPosition",ResponsiblePersons.HeadPositionRefs);
	StructureData.Insert("ChiefAccountant", ResponsiblePersons.ChiefAccountant);
	StructureData.Insert("Released", ResponsiblePersons.WarehouseMan);
	StructureData.Insert("ReleasedPosition", ResponsiblePersons.WarehouseManPositionRef);
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()	

// Shows the flag showing the activity direction visible.
//
&AtServerNoContext
Function GetBusinessActivitiesVisible(GLExpenseAccount)
	
	Return GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()	

// It receives data set from the server for the StructuralUnitOnChange procedure.
//
&AtServer
Function GetDataStructuralUnitOnChange(StructureData)
	
	IsRetail = Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
			  OR Object.StructuralUnitPayee.StructuralUnitType = Enums.StructuralUnitsTypes.Retail;
	IsRetailAccrualAccounting = Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting
						  OR Object.StructuralUnitPayee.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting;
	
	If Not ValueIsFilled(StructureData.Source)
		OR StructureData.Source.OrderWarehouse 
		OR StructureData.Source.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
		OR StructureData.Source.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
		StructureData.Insert("OrderWarehouse", False);
	Else
		StructureData.Insert("OrderWarehouse", True);
	EndIf;
	
	If StructureData.OperationKind = Enums.OperationKindsInventoryTransfer.Move Then
		
		StructureData.Insert("StructuralUnitPayee", StructureData.Source.TransferRecipient);
		StructureData.Insert("CellPayee", StructureData.Source.TransferRecipientCell);
		StructureData.Insert("TypeOfStructuralUnitRetailAmmountAccounting", StructureData.Source.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting);
		
		If Not ValueIsFilled(StructureData.Source.TransferRecipient)
			OR StructureData.Source.TransferRecipient.OrderWarehouse 
			OR StructureData.Source.TransferRecipient.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
			OR StructureData.Source.TransferRecipient.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
			StructureData.Insert("OrderWarehouseRecipient", False);
		Else
			StructureData.Insert("OrderWarehouseRecipient", True);
		EndIf;
		
		FunctionalOptionOrderTransferInHeader = Object.CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader;
		
		If Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
		 OR Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
			Items.Inventory.ChildItems.InventoryReserve.Visible = False;
			Items.InventoryChangeReserve.Visible = False;
			ReservationUsed = False;
			
		Else
			Items.Inventory.ChildItems.InventoryReserve.Visible = True;
			Items.InventoryChangeReserve.Visible = True;
			ReservationUsed = True;
		EndIf;
		
		If (Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
			OR Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting)
			AND (Object.StructuralUnitPayee.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
		OR Object.StructuralUnitPayee.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting) Then
			Items.CustomerOrder.Visible = False;
			Items.Inventory.ChildItems.InventoryCustomerOrder.Visible = False;
		Else
			Items.CustomerOrder.Visible = FunctionalOptionOrderTransferInHeader;
			Items.Inventory.ChildItems.InventoryCustomerOrder.Visible = Not FunctionalOptionOrderTransferInHeader;
		EndIf;
		
	ElsIf StructureData.OperationKind = Enums.OperationKindsInventoryTransfer.WriteOffToExpenses Then	
		
		StructureData.Insert("StructuralUnitPayee", StructureData.Source.WriteOffToExpensesRecipient);
		StructureData.Insert("CellPayee", StructureData.Source.WriteOffToExpensesRecipientCell);
		StructureData.Insert("TypeOfStructuralUnitRetailAmmountAccounting", False);
		
		If Not ValueIsFilled(StructureData.Source.WriteOffToExpensesRecipient)
			OR StructureData.Source.WriteOffToExpensesRecipient.OrderWarehouse Then
			StructureData.Insert("OrderWarehouseRecipient", False);
		Else
			StructureData.Insert("OrderWarehouseRecipient", True);
		EndIf;
		
	ElsIf StructureData.OperationKind = Enums.OperationKindsInventoryTransfer.TransferToOperation Then		
		
		StructureData.Insert("StructuralUnitPayee", StructureData.Source.PassToOperationRecipient);
		StructureData.Insert("CellPayee", StructureData.Source.PassToOperationRecipientCell);
		StructureData.Insert("TypeOfStructuralUnitRetailAmmountAccounting", False);
		
		If Not ValueIsFilled(StructureData.Source.PassToOperationRecipient)
			OR StructureData.Source.PassToOperationRecipient.OrderWarehouse Then
			StructureData.Insert("OrderWarehouseRecipient", False);
		Else
			StructureData.Insert("OrderWarehouseRecipient", True);
		EndIf;
		
	ElsIf StructureData.OperationKind = Enums.OperationKindsInventoryTransfer.ReturnFromExploitation Then	
		
		StructureData.Insert("StructuralUnitPayee", StructureData.Source.ReturnFromOperationRecipient);
		StructureData.Insert("CellPayee", StructureData.Source.ReturnFromOperationRecipientCell);
		StructureData.Insert("TypeOfStructuralUnitRetailAmmountAccounting", False);
		
		If Not ValueIsFilled(StructureData.Source.ReturnFromOperationRecipient)
			OR StructureData.Source.ReturnFromOperationRecipient.OrderWarehouse Then
			StructureData.Insert("OrderWarehouseRecipient", False);
		Else
			StructureData.Insert("OrderWarehouseRecipient", True);
		EndIf;
		
	EndIf;
	
	Return StructureData;
	
EndFunction // GetDataStructuralUnitOnChange()	

// Receives the data set from server for the StructuralUnitReceiverOnChange procedure.
//
&AtServer
Function GetDataStructuralUnitPayeeOnChange(StructureData)

	IsRetail = Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
			  OR Object.StructuralUnitPayee.StructuralUnitType = Enums.StructuralUnitsTypes.Retail;
	IsRetailAccrualAccounting = Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting
						  OR Object.StructuralUnitPayee.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting;

	If Not ValueIsFilled(StructureData.Recipient)
		OR StructureData.Recipient.OrderWarehouse 
		OR StructureData.Recipient.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
		OR StructureData.Recipient.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
		StructureData.Insert("OrderWarehouse", False);
	Else
		StructureData.Insert("OrderWarehouse", True);
	EndIf;
	
	If StructureData.OperationKind = Enums.OperationKindsInventoryTransfer.Move Then
		
		StructureData.Insert("StructuralUnit", StructureData.Recipient.TransferSource);
		StructureData.Insert("Cell", StructureData.Recipient.TransferSourceCell);
				
		If Not ValueIsFilled(StructureData.Recipient.TransferSource)
			OR StructureData.Recipient.TransferSource.OrderWarehouse 
			OR StructureData.Recipient.TransferSource.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
			OR StructureData.Recipient.TransferSource.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
			StructureData.Insert("OrderWarehouseSource", False);
		Else
			StructureData.Insert("OrderWarehouseSource", True);
		EndIf;
		
		FunctionalOptionOrderTransferInHeader = Object.CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader;
		
		If Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
	 	 OR Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
			Items.Inventory.ChildItems.InventoryReserve.Visible = False;
			Items.InventoryChangeReserve.Visible = False;
			ReservationUsed = False;
			
		Else
			Items.Inventory.ChildItems.InventoryReserve.Visible = True;
			Items.InventoryChangeReserve.Visible = True;
			ReservationUsed = True;
			
		EndIf;
		
		If (Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
		 OR Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting)
		   AND (Object.StructuralUnitPayee.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
	 	OR Object.StructuralUnitPayee.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting) Then
		 	Items.CustomerOrder.Visible = False;
			Items.Inventory.ChildItems.InventoryCustomerOrder.Visible = False;
		Else
			Items.CustomerOrder.Visible = FunctionalOptionOrderTransferInHeader;
			Items.Inventory.ChildItems.InventoryCustomerOrder.Visible = Not FunctionalOptionOrderTransferInHeader;
		EndIf;
		
	ElsIf StructureData.OperationKind = Enums.OperationKindsInventoryTransfer.WriteOffToExpenses Then	
		
		StructureData.Insert("StructuralUnit", StructureData.Recipient.WriteOffToExpensesSource);
		StructureData.Insert("Cell", StructureData.Recipient.WriteOffToExpensesSourceCell);
		
		If Not ValueIsFilled(StructureData.Recipient.WriteOffToExpensesSource)
			OR StructureData.Recipient.WriteOffToExpensesSource.OrderWarehouse Then
			StructureData.Insert("OrderWarehouseSource", False);
		Else
			StructureData.Insert("OrderWarehouseSource", True);
		EndIf;
		
	ElsIf StructureData.OperationKind = Enums.OperationKindsInventoryTransfer.TransferToOperation Then		
		
		StructureData.Insert("StructuralUnit", StructureData.Recipient.PassToOperationSource);
		StructureData.Insert("Cell", StructureData.Recipient.PassToOperationSourceCell);
		
		If Not ValueIsFilled(StructureData.Recipient.PassToOperationSource)
			OR StructureData.Recipient.PassToOperationSource.OrderWarehouse Then
			StructureData.Insert("OrderWarehouseSource", False);
		Else
			StructureData.Insert("OrderWarehouseSource", True);
		EndIf;
							
	ElsIf StructureData.OperationKind = Enums.OperationKindsInventoryTransfer.ReturnFromExploitation Then	
		
		StructureData.Insert("StructuralUnit", StructureData.Recipient.ReturnFromOperationSource);
		StructureData.Insert("Cell", StructureData.Recipient.ReturnFromOperationSourceCell);
		
		If Not ValueIsFilled(StructureData.Recipient.ReturnFromOperationSource)
			OR StructureData.Recipient.ReturnFromOperationSource.OrderWarehouse Then
			StructureData.Insert("OrderWarehouseSource", False);
		Else
			StructureData.Insert("OrderWarehouseSource", True);
		EndIf;
						
	EndIf;
	
	ShippingAddress = "";
	ArrayOfOwners = New Array;
	ArrayOfOwners.Add(StructureData.Recipient);
	
	Addresses = ContactInformationManagement.ContactInformationOfObjects(ArrayOfOwners, , Catalogs.ContactInformationTypes.StructuralUnitsFactAddress);
	If Addresses.Count() > 0 Then
		
		ShippingAddress = Addresses[0].Presentation;
		
	EndIf;
	StructureData.Insert("ShippingAddress", ShippingAddress);
	
	Return StructureData;
	
EndFunction // GetDataStructuralUnitPayeeOnChange()

// The procedure of processing the document operation kind change.
//
&AtServer
Procedure ProcessOperationKindChange()
	
	If ValueIsFilled(Object.OperationKind)
		AND Not Object.OperationKind = Enums.OperationKindsInventoryTransfer.Move Then
		
		User = Users.CurrentUser();
		
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainWarehouse");
		MainWarehouse = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainWarehouse);
		
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainDivision");
		MainDivision = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainDivision);
		
		If Object.OperationKind = Enums.OperationKindsInventoryTransfer.WriteOffToExpenses 
			OR Object.OperationKind = Enums.OperationKindsInventoryTransfer.TransferToOperation Then
			
			If Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
				
				Object.StructuralUnit = MainWarehouse;
				
			EndIf;
			
			If Not Constants.FunctionalOptionAccountingByMultipleDivisions.Get() Then
				
				Object.StructuralUnitPayee = MainDivision;
				
			EndIf;
			
		ElsIf Object.OperationKind = Enums.OperationKindsInventoryTransfer.ReturnFromExploitation Then
			
			If Not Constants.FunctionalOptionAccountingByMultipleDivisions.Get() Then
				
				Object.StructuralUnit = MainDivision;
				
			EndIf;
			
			If Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
				
				Object.StructuralUnitPayee = MainWarehouse;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	SetVisibleAndEnabled();
	
EndProcedure // ProcessOperationKindChange()

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
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsAndServicesData.MeasurementUnit);
				NewRow.Amount = NewRow.Quantity * NewRow.Cost;
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				FoundString.Amount = FoundString.Quantity * FoundString.Cost;
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

// The procedure fills in column Reserve by reserves for the order.
//
&AtServer
Procedure FillInventoryByWarehouseBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillInventoryByInventoryBalances();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // FillInventoryByWarehouseBalancesAtServer()

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
	
	FunctionalOptionOrderTransferInHeader = Object.CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader;
	
	NewArray = New Array();
	NewArray.Add(Enums.StructuralUnitsTypes.Warehouse);
	NewArray.Add(Enums.StructuralUnitsTypes.Retail);
	NewArray.Add(Enums.StructuralUnitsTypes.RetailAccrualAccounting);
	If Constants.FunctionalOptionUseSubsystemProduction.Get() Then
		NewArray.Add(Enums.StructuralUnitsTypes.Division);
	EndIf;
	ArrayWarehouseSubdivisionRetail = New FixedArray(NewArray);
	
	NewArray = New Array();
	NewArray.Add(Enums.StructuralUnitsTypes.Division);
	ArrayUnit = New FixedArray(NewArray);
	
	NewArray = New Array();
	NewArray.Add(Enums.StructuralUnitsTypes.Warehouse);
	ArrayWarehouse = New FixedArray(NewArray);
	
	If Object.OperationKind = Enums.OperationKindsInventoryTransfer.Move Then
		
		ThisForm.Items.GLExpenseAccount.Visible = False;
		ThisForm.Items.BusinessActivity.Visible = False;
		ThisForm.Items.CustomerOrder.Visible = FunctionalOptionOrderTransferInHeader;
		ThisForm.Items.Inventory.ChildItems.InventoryCustomerOrder.Visible = Not FunctionalOptionOrderTransferInHeader;
		Items.InventoryPick.Visible = True;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouseSubdivisionRetail);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		ThisForm.Items.StructuralUnit.ChoiceParameters = NewParameters;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouseSubdivisionRetail);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		ThisForm.Items.StructuralUnitPayee.ChoiceParameters = NewParameters;
		
		If Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
			OR Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
			Items.Inventory.ChildItems.InventoryReserve.Visible = False;
			Items.InventoryChangeReserve.Visible = False;
			ReservationUsed = False;
		Else
			Items.Inventory.ChildItems.InventoryReserve.Visible = True;
			Items.InventoryChangeReserve.Visible = True;
			ReservationUsed = True;
		EndIf;
		
		If (Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
			OR Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting)
			AND (Object.StructuralUnitPayee.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
	 	OR Object.StructuralUnitPayee.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting) Then
			Items.CustomerOrder.Visible = False;
			Items.Inventory.ChildItems.InventoryCustomerOrder.Visible = False;
		Else
			Items.CustomerOrder.Visible = FunctionalOptionOrderTransferInHeader;
			Items.Inventory.ChildItems.InventoryCustomerOrder.Visible = Not FunctionalOptionOrderTransferInHeader;
		EndIf;
		
		Items.StructuralUnit.Visible = True;
		Items.StructuralUnitPayee.Visible = True;
		
	ElsIf Object.OperationKind = Enums.OperationKindsInventoryTransfer.WriteOffToExpenses Then
		
		ThisForm.Items.GLExpenseAccount.Visible = True;
		ThisForm.Items.BusinessActivity.Visible = GetBusinessActivitiesVisible(Object.GLExpenseAccount);
		ThisForm.Items.CustomerOrder.Visible = FunctionalOptionOrderTransferInHeader;
		ThisForm.Items.Inventory.ChildItems.InventoryCustomerOrder.Visible = Not FunctionalOptionOrderTransferInHeader;
		Items.Inventory.ChildItems.InventoryReserve.Visible = True;
		Items.InventoryChangeReserve.Visible = True;
		Items.InventoryPick.Visible = True;
		ReservationUsed = True;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouse);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		ThisForm.Items.StructuralUnit.ChoiceParameters = NewParameters;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayUnit);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		ThisForm.Items.StructuralUnitPayee.ChoiceParameters = NewParameters;
		
		If Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
			
			Items.StructuralUnit.Visible = False;
			
		Else	
			
			Items.StructuralUnit.Visible = True;
			
		EndIf;
		
		If Not Constants.FunctionalOptionAccountingByMultipleDivisions.Get() Then
			
			Items.StructuralUnitPayee.Visible = False;
			
		Else
			
			Items.StructuralUnitPayee.Visible = True;
			
		EndIf;
		
	ElsIf Object.OperationKind = Enums.OperationKindsInventoryTransfer.TransferToOperation Then
		
		Items.GLExpenseAccount.Visible = True;
		Items.BusinessActivity.Visible = GetBusinessActivitiesVisible(Object.GLExpenseAccount);
		Items.CustomerOrder.Visible = False;
		Items.Inventory.ChildItems.InventoryCustomerOrder.Visible = False;
		Items.Inventory.ChildItems.InventoryReserve.Visible = False;
		Items.InventoryChangeReserve.Visible = False;
		Items.InventoryPick.Visible = True;
		ReservationUsed = False;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouse);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		ThisForm.Items.StructuralUnit.ChoiceParameters = NewParameters;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayUnit);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		ThisForm.Items.StructuralUnitPayee.ChoiceParameters = NewParameters;
		
		For Each StringInventory IN Object.Inventory Do
			StringInventory.Reserve = 0;
		EndDo;
		
		If Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
			
			Items.StructuralUnit.Visible = False;
			
		Else
			
			Items.StructuralUnit.Visible = True;
			
		EndIf;
		
		If Not Constants.FunctionalOptionAccountingByMultipleDivisions.Get() Then
			
			Items.StructuralUnitPayee.Visible = False;
			
		Else
			
			Items.StructuralUnitPayee.Visible = True;
			
		EndIf;
		
	ElsIf Object.OperationKind = Enums.OperationKindsInventoryTransfer.ReturnFromExploitation Then
		
		Items.GLExpenseAccount.Visible = False;
		Items.BusinessActivity.Visible = False;
		Items.CustomerOrder.Visible = False;
		Items.Inventory.ChildItems.InventoryCustomerOrder.Visible = False;
		Items.Inventory.ChildItems.InventoryReserve.Visible = False;
		Items.InventoryChangeReserve.Visible = False;
		Items.InventoryPick.Visible = False;
		ReservationUsed = False;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayUnit);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		ThisForm.Items.StructuralUnit.ChoiceParameters = NewParameters;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouse);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		ThisForm.Items.StructuralUnitPayee.ChoiceParameters = NewParameters;
		
		For Each StringInventory IN Object.Inventory Do
			StringInventory.Reserve = 0;
		EndDo;
		
		If Not Constants.FunctionalOptionAccountingByMultipleDivisions.Get() Then
			
			Items.StructuralUnit.Visible = False;
			
		Else
			
			Items.StructuralUnit.Visible = True;
			
		EndIf;
		
		If Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
			
			Items.StructuralUnitPayee.Visible = False;
			
		Else
			
			Items.StructuralUnitPayee.Visible = True;
			
		EndIf;
		
	Else
		
		Items.StructuralUnit.Visible = True;
		Items.StructuralUnitPayee.Visible = True;
		
	EndIf;
	
	Items.Inventory.ChildItems.InventoryCostPrice.Visible = Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting;
	Items.Inventory.ChildItems.InventoryAmount.Visible = Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting;
	
	Items.BusinessActivity.Visible = Object.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses;
	
	SetCellVisible("Cell", Object.StructuralUnit);
	SetCellVisible("CellPayee", Object.StructuralUnitPayee);
	
EndProcedure // SetVisibleAndEnabled()

// Receives the flag of Order warehouse.
//
&AtServer
Procedure SetCellVisible(CellName, Warehouse)
	
	If Not ValueIsFilled(Warehouse) 
		OR Warehouse.OrderWarehouse
		OR Warehouse.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
		OR Warehouse.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting Then
		Items[CellName].Enabled = False;
	Else
		Items[CellName].Enabled = True;
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
		If Not Constants.FunctionalOptionAccountingByMultipleDivisions.Get()
			AND Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
			
			Items.StructuralUnit.ListChoiceMode = True;
			Items.StructuralUnit.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
			Items.StructuralUnit.ChoiceList.Add(Catalogs.StructuralUnits.MainDivision);
			
			Items.StructuralUnitPayee.ListChoiceMode = True;
			Items.StructuralUnitPayee.ChoiceList.Add(Catalogs.StructuralUnits.MainDivision);
			Items.StructuralUnitPayee.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
			
		EndIf;
		
	EndIf;
	
	If Constants.FunctionalOptionUseSubsystemProduction.Get()
		OR Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
		
		Items.OperationKind.ChoiceList.Add(Enums.OperationKindsInventoryTransfer.Move, "Move");
		
	ElsIf Not ValueIsFilled(Object.Ref) Then
		
		Object.OperationKind = Enums.OperationKindsInventoryTransfer.WriteOffToExpenses;
		
	EndIf;
	
	Items.OperationKind.ChoiceList.Add(Enums.OperationKindsInventoryTransfer.WriteOffToExpenses, "Deduction of expenses");
	Items.OperationKind.ChoiceList.Add(Enums.OperationKindsInventoryTransfer.TransferToOperation, "Transfer to operation");
	Items.OperationKind.ChoiceList.Add(Enums.OperationKindsInventoryTransfer.ReturnFromExploitation, "Return from operation");
	
EndProcedure // SetVisibleByFDUseProductionSubsystem()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR WORK WITH THE SELECTION

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName 	= "Inventory";
	
	If Not IsBlankString(SelectionOpenParameters[TabularSectionName]) Then
		
		PickProductsAndServicesInDocumentsClient.OpenPick(ThisForm, TabularSectionName, SelectionOpenParameters[TabularSectionName]);
		Return;
		
	EndIf;
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period", 				Object.Date);
	SelectionParameters.Insert("Company", 			SubsidiaryCompany);
	
	SelectionParameters.Insert("StructuralUnit", 	Object.StructuralUnit);
	SelectionParameters.Insert("ReservationUsed", ReservationUsed);
	
	SelectionParameters.Insert("ShowPriceColumn", 	False);
	
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
			TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Cost;
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
	
	// Filling in responsible persons for new documents
	If Not ValueIsFilled(Object.Ref) Then
		
		ResponsiblePersons		= SmallBusinessServer.OrganizationalUnitsResponsiblePersons(Object.Company, Object.Date);
		
		Object.Head		= ResponsiblePersons.Head;
		Object.HeadPosition = ResponsiblePersons.HeadPositionRefs;
		Object.ChiefAccountant = ResponsiblePersons.ChiefAccountant;
		Object.Released			= ResponsiblePersons.WarehouseMan;
		Object.ReleasedPosition= ResponsiblePersons.WarehouseManPositionRef;
		
	EndIf;
	
	IsRetail = Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Retail
				OR Object.StructuralUnitPayee.StructuralUnitType = Enums.StructuralUnitsTypes.Retail;
	IsRetailAccrualAccounting = Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting
				OR Object.StructuralUnitPayee.StructuralUnitType = Enums.StructuralUnitsTypes.RetailAccrualAccounting;
	
	// FO Use Production subsystem.
	SetVisibleByFOUseProductionSubsystem();
	
	SetVisibleAndEnabled();
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// PickProductsAndServicesInDocuments
	PickProductsAndServicesInDocuments.AssignPickForm(SelectionOpenParameters, Object.Ref.Metadata().Name, "Inventory");
	// End PickProductsAndServicesInDocuments
	
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
	
	SetChoiceParameters();
	
EndProcedure // OnOpen()

// Procedure - event handler ChoiceProcessing.
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "DataProcessor.PrintBOL.Form.PrintInfo" Then
		
		For Each AttributeValues IN ValueSelected Do
			
			If AttributeValues.Key = "BankAccountOfTheCompany" Then
				
				Object.BankAccount = AttributeValues.Value;
				
			Else
				
				Object[AttributeValues.Key] = AttributeValues.Value;
				
			EndIf;
			
			Modified = True;
			
		EndDo;
		
	EndIf;
	
EndProcedure // ChoiceProcessing()

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

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose()
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure // OnClose()

// Procedure - command handler DocumentSetting.
//
&AtClient
Procedure DocumentSetting(Command)
	
	// 1. Form parameter structure to fill "Document setting" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("CustomerOrderPositionInInventoryTransfer", 	Object.CustomerOrderPosition);
	ParametersStructure.Insert("WereMadeChanges", 							False);
	
	StructureDocumentSetting = Undefined;

	
	OpenForm("CommonForm.DocumentSetting", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
    
    // 2. Open the form "Prices and Currency".
    StructureDocumentSetting = Result;
    
    // 3. Apply changes made in "Document setting" form.
    If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
        
        Object.CustomerOrderPosition = StructureDocumentSetting.CustomerOrderPositionInInventoryTransfer;
        SetVisibleAndEnabled();
        
    EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// You can call the procedure by clicking
// the button "FillByBasis" of the tabular field command panel.
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
        FillByDocument(Object.BasisDocument);
    EndIf;

EndProcedure // FillByBasis()

// FillInByBalance command event handler procedure
//
&AtClient
Procedure FillByBalanceAtWarehouse(Command)
	
	If Object.Inventory.Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillByBalanceOnWarehouseEnd", ThisObject), NStr("en='Tabular section will be cleared. Continue?';ru='Табличная часть будет очищена! Продолжить выполнение операции?'"), QuestionDialogMode.YesNo, 0);
        Return; 
	EndIf;
	
	FillByBalanceOnWarehouseEndFragment();
EndProcedure

&AtClient
Procedure FillByBalanceOnWarehouseEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf; 
    
    FillByBalanceOnWarehouseEndFragment();

EndProcedure

&AtClient
Procedure FillByBalanceOnWarehouseEndFragment()
    
    FillInventoryByWarehouseBalancesAtServer();

EndProcedure //FillByBalanceAtWarehouse()

// Procedure - command handler FillByReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeReserveFillByReserves(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='Tabular section ""Inventory"" is not filled!';ru='Табличная часть ""Запасы"" не заполнена!'");
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
		Message.Text = NStr("en='Tabular section ""Inventory"" is not filled!';ru='Табличная часть ""Запасы"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	For Each TabularSectionRow IN Object.Inventory Do
		TabularSectionRow.Reserve = 0;
	EndDo;
	
EndProcedure // ChangeReserveFillByBalances()

&AtClient
// Procedure - PrintInfo command handler
//
// To improve the usability of printing function and increase the speed of form opening, move secondary attributes to a separate form
//
Procedure StampAttributes(Command)
	
	ParametersStructure = New Structure();
	
	// Information about the current document
	ParametersStructure.Insert("Date",						Object.Date);
	ParametersStructure.Insert("Company",					Object.Company);
	ParametersStructure.Insert("StructuralUnitSender",Object.StructuralUnit);
	ParametersStructure.Insert("StructuralUnitPayee",Object.StructuralUnitPayee);
	ParametersStructure.Insert("StampBase",				Object.StampBase);
	//ParametersStructure.Insert("CounterpartyContract",		Undefined);
	ParametersStructure.Insert("BasisDocument",			Object.BasisDocument);
	ParametersStructure.Insert("Source",					"InventoryTransfer");
	
	OrdersArray = New Array;
	For Each TabularSectionRow IN Object.Inventory Do
		
		OrderInRow = Undefined;
		If TabularSectionRow.Property("CustomerOrder", OrderInRow)
			AND ValueIsFilled(OrderInRow)
			AND OrdersArray.Find(OrderInRow) = Undefined Then
			
			OrdersArray.Add(OrderInRow);
			
		EndIf;
		
	EndDo;
	ParametersStructure.Insert("OrdersArray",				OrdersArray);
	
	// Bank
	//accounts	ParametersStructure.Insert ("CompanyBankAcc", Undefined);
	//ParametersStructure.Insert("CounterpartyBankAcc",	Undefined);
	
	// Logistics
	ParametersStructure.Insert("Consignor",			Object.Company);
	ParametersStructure.Insert("Consignee",				Object.Company);
	ParametersStructure.Insert("ShippingAddress",				Object.ShippingAddress);
	
	// Carrier
	ParametersStructure.Insert("Carrier",					Object.Carrier);
	ParametersStructure.Insert("CarrierBankAccount",	Object.CarrierBankAccount);
	ParametersStructure.Insert("DeliveryTerm",				Object.DeliveryTerm);
	ParametersStructure.Insert("Driver",					Object.Driver);
	ParametersStructure.Insert("Vehicle",					Object.Vehicle);
	ParametersStructure.Insert("trailer",						Object.trailer);
	
	// Responsible individuals
	ParametersStructure.Insert("Head",				Object.Head);
	ParametersStructure.Insert("HeadPosition",		Object.HeadPosition);
	ParametersStructure.Insert("ChiefAccountant",			Object.ChiefAccountant);
	ParametersStructure.Insert("Released",					Object.Released);
	ParametersStructure.Insert("ReleasedPosition",			Object.ReleasedPosition);
	
	// PowerOfAttorney
	ParametersStructure.Insert("PowerOfAttorneyNumber",			Object.PowerOfAttorneyNumber);
	ParametersStructure.Insert("PowerOfAttorneyDate",			Object.PowerOfAttorneyDate);
	ParametersStructure.Insert("PowerOfAttorneyIssued",			Object.PowerOfAttorneyIssued);
	ParametersStructure.Insert("PowerAttorneyPerson",			Object.PowerAttorneyPerson);
	
	OpenForm("DataProcessor.PrintBOL.Form", ParametersStructure, ThisForm);
	
EndProcedure // PrintInfo()

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
	StructureData = GetCompanyDataOnChange(Object.Company, Object.Date);
	Counterparty = StructureData.Counterparty;
	
	Object.Head		= StructureData.Head;
	Object.HeadPosition = StructureData.HeadPosition;
	Object.ChiefAccountant = StructureData.ChiefAccountant;
	Object.Released			= StructureData.Released;
	Object.ReleasedPosition= StructureData.ReleasedPosition;
	
EndProcedure // CompanyOnChange()

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	ProcessOperationKindChange();
	
EndProcedure // OperationKindOnChange()

// Procedure - OnChange event handler of the CostsCounter input field.
//
&AtClient
Procedure GLExpenseAccountOnChange(Item)
	
	Items.BusinessActivity.Visible = GetBusinessActivitiesVisible(Object.GLExpenseAccount);
	
EndProcedure // GLExpenseAccountOnChange()

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	StructureData = New Structure();
	StructureData.Insert("OperationKind", Object.OperationKind);
	StructureData.Insert("Source", Object.StructuralUnit);
	
	StructureData = GetDataStructuralUnitOnChange(StructureData);
	
	Items.Cell.Enabled = StructureData.OrderWarehouse;
	
	If Not ValueIsFilled(Object.StructuralUnitPayee) Then
		Object.StructuralUnitPayee = StructureData.StructuralUnitPayee;
		Object.CellPayee = StructureData.CellPayee;
		Items.CellPayee.Enabled = StructureData.OrderWarehouseRecipient;
	EndIf;
	
	If StructureData.TypeOfStructuralUnitRetailAmmountAccounting Then
		Items.Inventory.ChildItems.InventoryCostPrice.Visible = True;
		Items.Inventory.ChildItems.InventoryAmount.Visible = True;
	ElsIf Not StructureData.TypeOfStructuralUnitRetailAmmountAccounting Then
		For Each StringInventory IN Object.Inventory Do
			StringInventory.Cost = 0;
			StringInventory.Amount = 0;
		EndDo;
		Items.Inventory.ChildItems.InventoryCostPrice.Visible = False;
		Items.Inventory.ChildItems.InventoryAmount.Visible = False;
	EndIf;
	
	SetChoiceParameters();
	
EndProcedure // StructuralUnitOnChange()

// Procedure - OnChange event handler of the StructuralUnitRecipient input field.
//
&AtClient
Procedure StructuralUnitPayeeOnChange(Item)
	
	StructureData = New Structure();
	StructureData.Insert("OperationKind", Object.OperationKind);
	StructureData.Insert("Recipient", Object.StructuralUnitPayee);
	
	StructureData = GetDataStructuralUnitPayeeOnChange(StructureData);
	
	Items.CellPayee.Enabled = StructureData.OrderWarehouse;
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		Object.StructuralUnit = StructureData.StructuralUnit;
		Object.Cell = StructureData.Cell;
		Items.Cell.Enabled = StructureData.OrderWarehouseSource;
	EndIf;
	
	StructureData.Property("ShippingAddress", Object.ShippingAddress);
	
	SetChoiceParameters();
	
EndProcedure // StructuralUnitPayeeOnChange()

// Procedure - Opening event handler of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOpening(Item, StandardProcessing)
	
	If Items.StructuralUnit.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // StructuralUnitOpening()

// Procedure - Opening event handler of the StructuralUnitRecipient input field.
//
&AtClient
Procedure StructuralUnitPayeeOpening(Item, StandardProcessing)
	
	If Items.StructuralUnitPayee.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnitPayee) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure // StructuralUnitPayeeOpening()

// Procedure sets choice parameter links.
//
&AtClient
Procedure SetChoiceParameters()
	
	If IsRetailAccrualAccounting Then
		NewArray = New Array();
		NewArray.Add(PredefinedValue("Enum.BatchStatuses.OwnInventory"));
		NewParameter = New ChoiceParameter("Filter.Status", New FixedArray(NewArray));
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.Inventory.ChildItems.InventoryBatch.ChoiceParameters = NewParameters;
	ElsIf IsRetail Then
		NewArray = New Array();
		NewArray.Add(PredefinedValue("Enum.BatchStatuses.OwnInventory"));
		NewArray.Add(PredefinedValue("Enum.BatchStatuses.ProductsOnCommission"));
		NewParameter = New ChoiceParameter("Filter.Status", New FixedArray(NewArray));
		NewParameter2 = New ChoiceParameter("Additionally.StatusRestriction", New FixedArray(NewArray));
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewArray.Add(NewParameter2);
		NewParameters = New FixedArray(NewArray);
		Items.Inventory.ChildItems.InventoryBatch.ChoiceParameters = NewParameters;
	Else
		NewArray = New Array();
		NewArray.Add(PredefinedValue("Enum.BatchStatuses.OwnInventory"));
		NewArray.Add(PredefinedValue("Enum.BatchStatuses.SafeCustody"));
		NewArray.Add(PredefinedValue("Enum.BatchStatuses.CommissionMaterials"));
		NewArray.Add(PredefinedValue("Enum.BatchStatuses.ProductsOnCommission"));
		NewParameter = New ChoiceParameter("Filter.Status", New FixedArray(NewArray));
		NewParameter2 = New ChoiceParameter("Additionally.StatusRestriction", New FixedArray(NewArray));
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewArray.Add(NewParameter2);
		NewParameters = New FixedArray(NewArray);
		Items.Inventory.ChildItems.InventoryBatch.ChoiceParameters = NewParameters;
	EndIf;
	
EndProcedure // SetChoiceParameters()

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
// PROCEDURE - TABULAR SECTION ATTRIBUTE EVENT HANDLERS

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure InventoryProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
EndProcedure // InventoryProductsAndServicesOnChange()

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Cost;
	
EndProcedure // InventoryQuantityOnChange()

// Procedure - OnChange event handler of the Primecost input field.
//
&AtClient
Procedure InventoryCostPriceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Cost;

EndProcedure // InventoryCostPriceOnChange()

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Cost = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
EndProcedure // InventoryAmountOnChange()

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
