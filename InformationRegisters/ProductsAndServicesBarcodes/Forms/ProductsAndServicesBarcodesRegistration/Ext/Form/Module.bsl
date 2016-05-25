&AtClient
Var ClosingProcessing;

&AtServer
Var UnknownBarcodes;

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UsePeripherals = SmallBusinessReUse.UsePeripherals();
	
	For Each RowOfBarcode IN Parameters.UnknownBarcodes Do
		NewBarcode = ProductsAndServicesBarcodes.Add();
		NewBarcode.Barcode = RowOfBarcode.Barcode;
		NewBarcode.Quantity = RowOfBarcode.Quantity;
	EndDo;
	
	UnknownBarcodes = Parameters.UnknownBarcodes;
	
EndProcedure

&AtServer
Procedure RegisterBarcodesAtServer()
	
	For Each RowOfBarcode IN ProductsAndServicesBarcodes Do
		
		If RowOfBarcode.Registered OR Not ValueIsFilled(RowOfBarcode.ProductsAndServices) Then
			Continue;
		EndIf;
		
		Try
			
			RecordManager = InformationRegisters.ProductsAndServicesBarcodes.CreateRecordManager();
			RecordManager.ProductsAndServices = RowOfBarcode.ProductsAndServices;
			RecordManager.Characteristic = RowOfBarcode.Characteristic;
			RecordManager.Batch = RowOfBarcode.Batch;
			RecordManager.Barcode = RowOfBarcode.Barcode;
			RecordManager.Write();
			
			RowOfBarcode.RegisteredByProcessing = True;
			
		Except
		
		EndTry
		
	EndDo;
	
EndProcedure

&AtClient
Procedure MoveIntoDocument(Command)
	
	ClearMessages();
	
	If CheckFilling() Then
		
		RegisterBarcodesAtServer();
		
		FoundUnregisteredGoods = ProductsAndServicesBarcodes.FindRows(New Structure("Registered, RegisteredByProcessing", False, False));
		If FoundUnregisteredGoods.Count() > 0 Then
			
			QuestionText = NStr(
				"en='The corresponding products and services are specified not for all new barcodes.
				|These products will not be transferred in the document.
				|Put them aside as not scanned.'"
			);
			
			QuestionResult = Undefined;
			
			ShowQueryBox(New NotifyDescription("TransferToDocumentEnd", ThisObject), QuestionText, QuestionDialogMode.OKCancel);
			Return;
			
		EndIf;
		
		TransferToDocumentFragment();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TransferToDocumentEnd(Result, AdditionalParameters) Export
	
	QuestionResult = Result;
	If QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	
	TransferToDocumentFragment();
	
EndProcedure

&AtClient
Procedure TransferToDocumentFragment()
	
	Var RegisteredBarcodes, FoundsRegisteredBarcodes, FoundDeferredProducts, FoundsBarcodes, DeferredProducts, ClosingParameter, ReceivedNewBarcodes, RowOfBarcode;
	
	RegisteredBarcodes = New Array;
	FoundsRegisteredBarcodes = ProductsAndServicesBarcodes.FindRows(New Structure("RegisteredByProcessing", True));
	For Each RowOfBarcode IN FoundsRegisteredBarcodes Do
		RegisteredBarcodes.Add(New Structure("Barcode, Quantity", RowOfBarcode.Barcode, RowOfBarcode.Quantity));
	EndDo;
	
	DeferredProducts = New Array;
	FoundDeferredProducts = ProductsAndServicesBarcodes.FindRows(New Structure("Registered, RegisteredByProcessing", False, False));
	For Each RowOfBarcode IN FoundDeferredProducts Do
		DeferredProducts.Add(New Structure("Barcode, Quantity", RowOfBarcode.Barcode, RowOfBarcode.Quantity));
	EndDo;
	
	ReceivedNewBarcodes = New Array;
	FoundsBarcodes = ProductsAndServicesBarcodes.FindRows(New Structure("Registered", True));
	For Each RowOfBarcode IN FoundsBarcodes Do
		ReceivedNewBarcodes.Add(New Structure("Barcode, Quantity", RowOfBarcode.Barcode, RowOfBarcode.Quantity));
	EndDo;
	
	ClosingParameter = New Structure("DeferredProducts, RegisteredBarcodes, ReceivedNewBarcodes", DeferredProducts, RegisteredBarcodes, ReceivedNewBarcodes);
	ClosingProcessing = True;
	Close(ClosingParameter);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	#If Not WebClient Then
	Beep();
	#EndIf
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	ClosingProcessing = False;
	CurrentItem = Items.ProductsAndServices;
	
EndProcedure

&AtServerNoContext
Function GetBarcodeData(Barcode)

	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProductsAndServicesBarcodes.ProductsAndServices,
	|	ProductsAndServicesBarcodes.Characteristic,
	|	ProductsAndServicesBarcodes.Batch
	|FROM
	|	InformationRegister.ProductsAndServicesBarcodes AS ProductsAndServicesBarcodes
	|WHERE
	|	ProductsAndServicesBarcodes.Barcode = &Barcode";
	
	Query.SetParameter("Barcode", Barcode);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		BarcodeData = New Structure("ProductsAndServices, Characteristic, Batch");
		FillPropertyValues(BarcodeData, Selection);
		Return BarcodeData;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Peripherals
&AtClient
Function BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	For Each DataItem IN BarcodesData Do
		FoundStrings = ProductsAndServicesBarcodes.FindRows(New Structure("Barcode", DataItem.Barcode));
		If FoundStrings.Count() > 0 Then
			FoundStrings[0].Quantity = FoundStrings[0].Quantity + DataItem.Quantity;
		Else
			BarcodeData = GetBarcodeData(DataItem.Barcode);
			If BarcodeData = Undefined Then
				NewBarcode = ProductsAndServicesBarcodes.Add();
				NewBarcode.Barcode = DataItem.Barcode;
				NewBarcode.Quantity = DataItem.Quantity;
			Else
				NewBarcode = ProductsAndServicesBarcodes.Add();
				NewBarcode.Barcode   = DataItem.Barcode;
				NewBarcode.Quantity = DataItem.Quantity;
				FillPropertyValues(NewBarcode, BarcodeData);
				NewBarcode.Registered = True;
			EndIf;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction // BarcodesAreReceived()
// End Peripherals

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
		ElsIf EventName = "DataCollectionTerminal" Then
			BarcodesReceived(Parameter);
		EndIf;
	EndIf;
	// End Peripherals

EndProcedure

&AtClient
Procedure OnClose()
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	ProductsAndServicesBarcodes.Barcode AS Barcode,
	|	ProductsAndServicesBarcodes.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesBarcodes.Characteristic AS Characteristic,
	|	ProductsAndServicesBarcodes.Batch AS Batch,
	|	ProductsAndServicesBarcodes.ProductsAndServices.Description AS ProductsAndServicesPresentation,
	|	ProductsAndServicesBarcodes.Characteristic.Description AS CharacteristicPresentation,
	|	ProductsAndServicesBarcodes.Batch.Description AS BatchPresentation
	|FROM
	|	InformationRegister.ProductsAndServicesBarcodes AS ProductsAndServicesBarcodes
	|WHERE
	|	ProductsAndServicesBarcodes.Barcode IN(&Barcodes)";
	
	Query.SetParameter("Barcodes", ProductsAndServicesBarcodes.Unload(New Structure("Registered", False),"Barcode").UnloadColumn("Barcode"));
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then // Barcode is already written in the database
		
		TSRow = ProductsAndServicesBarcodes.FindRows(New Structure("Barcode", Selection.Barcode))[0];
		
		ErrorDescription = NStr("en='Such barcode is already specified  for products and services %ProductsAndServices%'");
		ErrorDescription = StrReplace(ErrorDescription, "%ProductsAndServices%", """" + Selection.ProductsAndServicesPresentation + """"
						+ ?(ValueIsFilled(Selection.Characteristic), " " + NStr("en='with characteristic'") + " """ + Selection.CharacteristicPresentation + """", "")
						+ ?(ValueIsFilled(Selection.Batch), " """ + NStr("en='in batch'") + " " + Selection.BatchPresentation + """", ""));
		
		CommonUseClientServer.MessageToUser(ErrorDescription,,"ProductsAndServicesBarcodes["+ProductsAndServicesBarcodes.IndexOf(TSRow)+"].Barcode",,Cancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Cancel(Command, Cancel = False)
	
	If Not ClosingProcessing Then
		
		NotifyDescription = New NotifyDescription("CancelEnd", ThisObject);
		
		QuestionText = NStr(
			"en='All products will not be transferred in the document.
			|Put them aside as not scanned.'"
		);
		
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.OKCancel);
		Return;
		
	EndIf;
	
	DeferredProducts = New Array;
	For Each RowOfBarcode IN ProductsAndServicesBarcodes Do
		DeferredProducts.Add(New Structure("Barcode, Quantity", RowOfBarcode.Barcode, RowOfBarcode.Quantity));
	EndDo;
	
	ClosingParameter = New Structure("DeferredProducts, RegisteredBarcodes, ReceivedNewBarcodes", DeferredProducts, New Array, New Array);
	ClosingProcessing = True;
	Close(ClosingParameter);
	
EndProcedure

&AtClient
Procedure CancelEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	DeferredProducts = New Array;
	For Each RowOfBarcode IN ProductsAndServicesBarcodes Do
		DeferredProducts.Add(New Structure("Barcode, Quantity", RowOfBarcode.Barcode, RowOfBarcode.Quantity));
	EndDo;
	
	ClosingParameter = New Structure("DeferredProducts, RegisteredBarcodes, ReceivedNewBarcodes", DeferredProducts, New Array, New Array);
	ClosingProcessing = True;
	Try
		Close(ClosingParameter);
	Except
	EndTry;
	
EndProcedure // DetermineNeedForDocumentFillByBasis()

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Not ClosingProcessing Then
		Cancel(Undefined, Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsAndServicesBarcodesBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure



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
