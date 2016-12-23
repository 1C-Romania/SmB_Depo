#Region ServiceProceduresAndFunctions

// Creates Barcode EAN13.
//
&AtServerNoContext
Function GenerateBarcodeEAN13()
	
	Return InformationRegisters.ProductsAndServicesBarcodes.GenerateBarcodeEAN13();
	
EndFunction // GenerateBarcodeEAN13()

&AtServerNoContext
Function GenerateBarcodeEAN13VehicleWeightGood(WeightProductPrefix = "1")
	
	Return InformationRegisters.ProductsAndServicesBarcodes.GenerateBarcodeVehicleWeightGoodsEAN13(WeightProductPrefix);
	
EndFunction

// Peripherals
&AtClient
Function BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	If BarcodesData.Count() > 0 Then
		Record.Barcode = BarcodesData[BarcodesData.Count() - 1].Barcode;
	EndIf;
	
	Return True;
	
EndFunction // BarcodesAreReceived()
// End Peripherals

// Procedure command handler  NewBarcode.
//
&AtClient
Procedure NewBarcode(Command)
	
	If UseExchangeWithPeripheralsOffline Then
		WeightProductPrefix = 1;
		ShowInputNumber(New NotifyDescription("NewBarcodeEnd", ThisObject, New Structure("WeightProductPrefix", WeightProductPrefix)), WeightProductPrefix, NStr("en='If it is a weight item then enter the prefix of the weight item and press the Cancell button';ru='Если товар весовой, то введите префикс весового товара или нажмите кнопку Отмена'"), 1, 0);
	Else
		Record.Barcode = GenerateBarcodeEAN13();
	EndIf;
	
EndProcedure

&AtClient
Procedure NewBarcodeEnd(Result1, AdditionalParameters) Export
    
    WeightProductPrefix = ?(Result1 = Undefined, AdditionalParameters.WeightProductPrefix, Result1);
    
    
    Result = (Result1 <> Undefined);
    If Result Then
        Record.Barcode = GenerateBarcodeEAN13VehicleWeightGood(WeightProductPrefix);
    Else
        Record.Barcode = GenerateBarcodeEAN13();
    EndIf;

EndProcedure // NewBarcode()

#EndRegion

#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Peripherals
	UsePeripherals = SmallBusinessReUse.UsePeripherals();
	UseExchangeWithPeripheralsOffline = GetFunctionalOption("UseExchangeWithPeripheralsOffline");
	// End Peripherals
	
EndProcedure // OnCreateAtServer()

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

// Procedure - event handler NotificationProcessing.
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
		ElsIf EventName = "DataCollectionTerminal" Then
			BarcodesReceived(Parameter);
		EndIf;
	EndIf;
	// End Peripherals
	
EndProcedure // NotificationProcessing()

// Procedure - event handler FillCheckProcessingAtServer.
//
&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	ProductsAndServicesBarcodes.Barcode,
	|	ProductsAndServicesBarcodes.ProductsAndServices,
	|	ProductsAndServicesBarcodes.Characteristic,
	|	ProductsAndServicesBarcodes.Batch,
	|	PRESENTATION(ProductsAndServicesBarcodes.ProductsAndServices) AS ProductsAndServicesPresentation,
	|	PRESENTATION(ProductsAndServicesBarcodes.Characteristic) AS CharacteristicPresentation,
	|	PRESENTATION(ProductsAndServicesBarcodes.Batch) AS BatchPresentation
	|FROM
	|	InformationRegister.ProductsAndServicesBarcodes AS ProductsAndServicesBarcodes
	|WHERE
	|	ProductsAndServicesBarcodes.Barcode = &Barcode";
	
	Query.SetParameter("Barcode", Record.Barcode);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() // Barcode is already written in the database
	   AND Record.SourceRecordKey.Barcode <> Record.Barcode Then
		
		ErrorDescription = NStr("en='Such barcode is already specified  for products and services %ProductsAndServices%';ru='Такой штрихкод уже назначен для номенклатуры %Номенклатура%'");
		ErrorDescription = StrReplace(ErrorDescription, "%ProductsAndServices%", """" + Selection.ProductsAndServicesPresentation + """"
		                + ?(ValueIsFilled(Selection.Characteristic), " " + NStr("en='with characteristic';ru='с характеристикой'") + " """ + Selection.CharacteristicPresentation + """", "")
		                + ?(ValueIsFilled(Selection.Batch), " """ + NStr("en='with the batch';ru='с партией'") + " " + Selection.BatchPresentation + """", ""));
		
		SmallBusinessServer.ShowMessageAboutError(ThisForm, ErrorDescription, , , "Record.Barcode", Cancel);
		
	EndIf;
	
EndProcedure // FillCheckProcessingAtServer()

#EndRegion














