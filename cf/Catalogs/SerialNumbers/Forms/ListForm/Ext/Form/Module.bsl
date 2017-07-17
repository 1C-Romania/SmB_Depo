
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Owner") Then
		
		ProductsAndServicesOwner = Parameters.Filter.Owner;
		UseSerialNumbers = ProductsAndServicesOwner.UseSerialNumbers;
		
		If NOT ValueIsFilled(ProductsAndServicesOwner)
			OR NOT ProductsAndServicesOwner.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
			
			AutoTitle = False;
			Title = NStr("ru = 'Серийные номера хранятся только для запасов'; en = 'Serial numbers are stored only for inventories'");
			
			Items.List.ReadOnly = True;
		EndIf;
		
		If NOT ProductsAndServicesOwner.UseSerialNumbers Then
			Items.SearchByBarcodeForm.Enabled = False;
			Items.ShowSold.Enabled = False;
		EndIf;
		
	EndIf;
	
	If Parameters.Property("ShowSold") Then
	    ShowSold = Parameters.ShowSold;
	Else	
		ShowSold = False;
	EndIf;
	
	List.Parameters.SetParameterValue("ShowSold", ShowSold);
	Items.Sold.Visible = ShowSold;
	
	// Peripherals
	UsePeripherals = SmallBusinessReUse.UsePeripherals();
	// End Peripherals
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure

&AtClient
Procedure SoldOnChange(Item)
	
	Items.Sold.Visible = ShowSold;
	List.Parameters.SetParameterValue("ShowSold", ShowSold);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals" Then
		If EventName = "ScanData" Then
			//Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get barcode from the main data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get barcode from additional data
			EndIf;
			
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
EndProcedure

#Region Peripherals

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData) Export
	
	If NOT UseSerialNumbers Then
		Message = New UserMessage();
		Message.Text = NStr("ru = 'Для номенклатуры не ведется учет по серийным номерам!
							|Установите флаг ""Использовать серийные номера"" в карточке номенклатуры'; en = 'No account by serial numbers for this products!
							|Select the ""Use serial numbers"" check box in products and services card'");
		Message.Message();
		Return;
	EndIf;
	
	Barcode = BarcodesData[0].Barcode;
	
	For Each FilterItem In List.Filter.Items Do
		If FilterItem.LeftValue = New DataCompositionField("Owner") Then
			ProductsAndServicesOwner = FilterItem.RightValue;
			Break;
		EndIf;
	EndDo;
	If NOT ValueIsFilled(ProductsAndServicesOwner) AND Items.List.CurrentData<>Undefined Then
		ProductsAndServicesOwner = Items.List.CurrentData.Owner;
	EndIf;
	If NOT ValueIsFilled(ProductsAndServicesOwner) Then
		Return;
	EndIf;
	
	SerialNumber = GetSerialNumberByBarcode(BarcodesData, ProductsAndServicesOwner);
	If ValueIsFilled(SerialNumber) Then
		
		Items.List.CurrentRow = SerialNumber;
		OpenForm("Catalog.SerialNumbers.ObjectForm",New Structure("Key",SerialNumber),ThisObject);
	Else
		
		MissingBarcodes		= FillByBarcodesData(BarcodesData);
		UnknownBarcodes		= MissingBarcodes.UnknownBarcodes;
		IncorrectBarcodesType	= MissingBarcodes.IncorrectBarcodesType;
		
		ReceivedIncorrectBarcodesType(IncorrectBarcodesType);
		
		If UnknownBarcodes.Count() > 0 Then
			
			Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisObject, UnknownBarcodes);
			
			OpenForm(
				"InformationRegister.ProductsAndServicesBarcodes.Form.ProductsAndServicesBarcodesRegistration",
				New Structure("UnknownBarcodes", UnknownBarcodes), ThisObject,,,,Notification
			);
			
			Return;
			
		EndIf;
		
		BarcodesAreReceivedFragment(UnknownBarcodes);
	EndIf;
	
EndProcedure // BarcodesReceived()

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	IncorrectBarcodesType = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	StructureData.Insert("FilterProductsAndServicesType", PredefinedValue("Enum.ProductsAndServicesTypes.InventoryItem"));

	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
		   
		    CurBarcode.Insert("ProductsAndServices", ProductsAndServicesOwner);
			UnknownBarcodes.Add(CurBarcode);
			
		ElsIf StructureData.FilterProductsAndServicesType <> BarcodeData.ProductsAndServicesType Then
			IncorrectBarcodesType.Add(New Structure("Barcode,ProductsAndServices,ProductsAndServicesType", CurBarcode.Barcode, BarcodeData.ProductsAndServices, BarcodeData.ProductsAndServicesType));
		ElsIf BarcodeData.ProductsAndServices = ProductsAndServicesOwner Then
			
			If NOT ValueIsFilled(BarcodeData.SerialNumber) Then
				NewSerialNumber = CreateSerialNumber(CurBarcode.Barcode, ProductsAndServicesOwner);
				If ValueIsFilled(NewSerialNumber) Then
					NotifyChanged(NewSerialNumber);
				EndIf;
				
				Items.List.CurrentRow = NewSerialNumber;
			Else
				Items.List.CurrentRow = BarcodeData.SerialNumber;
			EndIf;
			
		EndIf;
	EndDo;
	
	Return New Structure("UnknownBarcodes, IncorrectBarcodesType",UnknownBarcodes, IncorrectBarcodesType);
	
EndFunction // FillByBarcodesData()

&AtServer
Function CreateSerialNumber(SerialNumberString, ProductsAndServicesOwner)

	Ob = Catalogs.SerialNumbers.CreateItem();
	Ob.Owner = ProductsAndServicesOwner;
	Ob.Description = SerialNumberString;
	
	Try
		Ob.Write();
		
		MessageString = NStr("ru = 'Создан серийный номер: %1%'; en = 'Created serial number: %1%'");
		MessageString = StrReplace(MessageString, "%1%", SerialNumberString);
		CommonUseClientServer.MessageToUser(MessageString);
	Except
		CommonUseClientServer.MessageToUser(ErrorDescription());
	EndTry;
	
	Return Ob.Ref;
	
EndFunction

&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	DataByBarCodes = InformationRegisters.ProductsAndServicesBarcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() <> 0 Then
			
			If NOT ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.ProductsAndServices.MeasurementUnit;
			EndIf;
			BarcodeData.Insert("ProductsAndServicesType", BarcodeData.ProductsAndServices.ProductsAndServicesType);
			If ValueIsFilled(BarcodeData.MeasurementUnit)
				AND TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
				BarcodeData.Insert("Ratio", BarcodeData.MeasurementUnit.Ratio);
			Else
				BarcodeData.Insert("Ratio", 1);
			EndIf;
		EndIf;
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure // GetDataByBarCodes()

Function GetSerialNumberByBarcode(BarcodeData, ProductsAndServicesOwner)

	BarcodeString = BarcodeData[0].Barcode;
	SNData = InformationRegisters.ProductsAndServicesBarcodes.GetDataByBarCodes(BarcodeData);
	
	WrittenBarcodeData = SNData[BarcodeString];
	If WrittenBarcodeData.Count() = 0 Then
		
		Return Undefined;
	ElsIf WrittenBarcodeData.ProductsAndServices = ProductsAndServicesOwner Then
		
		Return WrittenBarcodeData.SerialNumber;
	Else	
		MessageString = NStr("ru = 'Введенный штрихкод %1% привязан к другой номенклатуре (серийному номеру): %2%'; en = 'Entered barcode %1% is bound to other product (serial number): %2%'");
		MessageString = StrReplace(MessageString, "%1%", BarcodeString);
		MessageString = StrReplace(MessageString, "%2%", WrittenBarcodeData.ProductsAndServices);
		CommonUseClientServer.MessageToUser(MessageString);
		
		Return Undefined;
	EndIf;
	
EndFunction

// Procedure - command handler of the tabular section command panel.
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("ru = 'Введите штрихкод'; en = 'Enter barcode'"));
	Modified = False;
	
EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, ExtendedParameters) Export
    
    CurBarcode = ?(Result = Undefined, ExtendedParameters.CurBarcode, Result);
    
    If NOT IsBlankString(CurBarcode) Then
		BarcodesArray = New Array;
		BarcodesArray.Add(New Structure("Barcode, Quantity", CurBarcode, 1));
		BarcodesReceived(BarcodesArray);
    EndIf;

EndProcedure // SearchByBarcode()

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement In ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement In ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		MissingBarcodes		= FillByBarcodesData(BarcodesArray);
		UnknownBarcodes		= MissingBarcodes.UnknownBarcodes;
		IncorrectBarcodesType	= MissingBarcodes.IncorrectBarcodesType;
		ReceivedIncorrectBarcodesType(IncorrectBarcodesType);
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageString = NStr("en='Barcode data is not found: %1%; quantity: %2%';ru='Данные по штрихкоду не найдены: %1%; количество: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Count);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ReceivedIncorrectBarcodesType(IncorrectBarcodesType) Export
	
	For Each CurhInvalidBarcode In IncorrectBarcodesType Do
		
		MessageString = NStr("ru = 'Найденная по штрихкоду %1% номенклатура -%2%- имеет тип %3%, который не подходит для этой табличной части'; en = 'Product %2% founded by barcode %1% have type %3% which is not suitable for this table section'");
		MessageString = StrReplace(MessageString, "%1%", CurhInvalidBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurhInvalidBarcode.ProductsAndServices);
		MessageString = StrReplace(MessageString, "%3%", CurhInvalidBarcode.ProductsAndServicesType);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

#EndRegion //Peripherals