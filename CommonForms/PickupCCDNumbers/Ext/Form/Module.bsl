
//CCD number is decrypted in the following way:
//item 1 - code of the customs authority that registered the DT [ CCD ].
//item 2 - registration date of CD [ CCD ] (day, month, two last digits of the year);
//item 3 - sequence number of CD [CCD], assigned according to the event log CD [CCD] by the customs authority, that registered the CD [CCD] (starts with one since each calendar year).
//All items are specified using the delimiter character "/", spaces between items are not allowed. 

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS OF THE DOCUMENT FORM

&AtServer
// Function puts the work results (the tabular section) in the storage
//
Function WritePickToStorage() 
		
	Return PutToTempStorage(
		Inventory.Unload(),
		?(OwnerFormUUID = New UUID("00000000-0000-0000-0000-000000000000"), Undefined, OwnerFormUUID)
										);
	
EndFunction

// Procedure sets the value in the marked rows of the tabular section
//
&AtServer
Procedure SetValuesInMarkedLinesOfTabularSection()
	
	For Each StringSupplies IN Inventory Do
		
		If Not StringSupplies.Mark Then
			
			Continue;
			
		EndIf;
		
		If Not StringSupplies.IsInventoryItem Then
			
			Continue;
			
		EndIf;
		
		StringSupplies.CountryOfOrigin = CountryOfOrigin;
		StringSupplies.CCDNo = CCDNo;
		
	EndDo;
	
EndProcedure //SetValuesInMarkedLinesOfTabularSection()

// Inverts the values of the Mark field in all rows of the Inventory tabular section
//
&AtServer
Procedure InvertMarksAtServer()
	
	For Each StringSupplies IN Inventory Do
		
		StringSupplies.Mark = Not StringSupplies.Mark;
		
	EndDo;
	
EndProcedure // InvertMarksAtServer()

// Procedure sets the passed value for the Mark field in the rows of the Inventory tabular section
//
// MarkValue (Boolean) - Value that will be set in
// the Mark field CountryOfOrigin (Catalog.WorldCountries) - Country of origin by which rows will be selected to set the mark.
// 		If it is not specified, the value will be set in all rows of the tabular section.
//
&AtServer
Procedure SetMarkInStrings(MarkValue, CountryOfOrigin = Undefined)
	
	For Each StringSupplies IN Inventory Do
		
		If CountryOfOrigin = Undefined
			Or StringSupplies.CountryOfOrigin = CountryOfOrigin Then
		
			StringSupplies.Mark = MarkValue;
			
		EndIf;
		
	EndDo;
	
EndProcedure // SetMarkInStrings()

// Receives the tabular section values of the Inventory document, for which the filling is executed
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage)
	
	Inventory.Load(GetFromTempStorage(InventoryAddressInStorage));
	
	For Each StringSupplies IN Inventory Do
		
		If ValueIsFilled(StringSupplies.ProductsAndServices) Then
			
			StringSupplies.IsInventoryItem = (StringSupplies.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem);
			
		Else
			
			StringSupplies.IsInventoryItem = False;
			
		EndIf;
		
		If Not ValueIsFilled(StringSupplies.CountryOfOrigin) Then
			
			Continue;
			
		EndIf;
		
		If Not ValueIsFilled(CountryOfOrigin) Then
			
			CountryOfOrigin = StringSupplies.CountryOfOrigin;
			
		EndIf;
		
		StringSupplies.Check = (CountryOfOrigin = StringSupplies.CountryOfOrigin);
		
	EndDo;
	
EndProcedure // GetInventoryFromStorage()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DocumentDate = Parameters.DocumentDate;
	
	GetInventoryFromStorage(Parameters.InventoryAddressInStorage);
	
	OwnerFormUUID = Parameters.OwnerFormUUID;
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - HANDLERS OF THE FORM ATTRIBUTES

&AtClient
Procedure InventoryTableCCDNumberStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not Items.InventoryTable.CurrentData.IsInventoryItem Then
		
		StandardProcessing = False;
		
		MessageText = NStr("en = 'Specify the CCD number is possible only for the products and services with the <Inventory> type.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryTableNumberCCDOnChange(Item)
	
	RowData = Items.InventoryTable.CurrentData;
	If Not RowData.IsInventoryItem Then
		
		StandardProcessing = False;
		
		MessageText = NStr("en = 'Specify the CCD number is possible only for the products and services with the <Inventory> type.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
		RowData.CCDNo = Undefined;
		
	EndIf;
	
	CCDRegistrationDate = Date(0001,01,01);
	SmallBusinessServer.FillDateByCCDNumber(RowData.CCDNo, CCDRegistrationDate);
	
	If CCDRegistrationDate > DocumentDate Then
		
		QuestionText = NStr("en = 'You selected the CCD which registration date is older than the date of the document. 
			|Continue?'");
		
		Notification = New NotifyDescription("NoCCDWhenCheckDateEnd", ThisObject, "RowData.CCDNo");
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryTableCountryOfOriginStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not Items.InventoryTable.CurrentData.IsInventoryItem Then
		
		StandardProcessing = False;
		
		MessageText = NStr("en = 'You can specify the country of origin only for the products and services with the <Inventory> type.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryTableCountryOfOriginOnChange(Item)
	
	RowData = Items.InventoryTable.CurrentData;
	If Not RowData.IsInventoryItem Then
		
		StandardProcessing = False;
		
		MessageText = NStr("en = 'You can specify the country of origin only for the products and services with the <Inventory> type.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
		RowData.CountryOfOrigin = Undefined;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NumberCCDOnChange(Item)
	
	If IsBlankString(CCDNo) Then
		
		Return;
		
	EndIf;
	
	CCDRegistrationDate = Date(0001,01,01);
	SmallBusinessServer.FillDateByCCDNumber(CCDNo, CCDRegistrationDate);
	
	If CCDRegistrationDate > DocumentDate Then
		
		QuestionText = NStr("en = 'You selected the CCD which registration date is older than the date of the document. 
			|Continue?'");
		
		Notification = New NotifyDescription("NoCCDWhenCheckDateEnd", ThisObject, "CCDNo");
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NoCCDWhenCheckDateEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		
		If AdditionalParameters = "CCDNo" Then
			
			CCDNo = Undefined;
			
		ElsIf AdditionalParameters = "RowData.CCDNo" Then
			
			RowData = Items.InventoryTable.CurrentData;
			RowData.CCDNo = Undefined;
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

// Procedures of managing setting/clearing mark in the rows

// Procedure - command handler SetMarkInAllRows
//
&AtClient
Procedure SetMarkInAllRows(Command)
	
	SetMarkInStrings(True, );
	
EndProcedure //SetMarkInAllRows()

// Procedure - command handler UnmarkAllLines
//
&AtClient
Procedure UnmarkAllLines(Command)
	
	SetMarkInStrings(False, );
	
EndProcedure //UnmarkAllLines()

// Procedure - command handler InvertMark (changes the value on the opposite)
//
&AtClient
Procedure InvertMark(Command)
	
	InvertMarksAtServer();
	
EndProcedure //InvertMark()

// Procedure - command handler SetMarkForRowsWithSameCountry
//
&AtClient
Procedure SetMarkForRowsWithSameCountry(Command)
	
	CurrentStringData = Items.InventoryTable.CurrentData;
	
	If CurrentStringData = Undefined Then
		
		MessageText = NStr("en = 'Highlight a row of the tabular section and repeat click...'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	CountryOfOrigin = CurrentStringData.CountryOfOrigin;
	
	SetMarkInStrings(True, CurrentStringData.CountryOfOrigin);
	
EndProcedure // SetMarkForRowsWithSameCountry()

// Procedure - command handler ClearMarkForRowsWithSameCountry
//
&AtClient
Procedure ClearMarkForRowsWithSameCountry(Command)
	
	CurrentStringData = Items.InventoryTable.CurrentData;
	
	If CurrentStringData = Undefined Then
		
		MessageText = NStr("en = 'Highlight a row of the tabular section and repeat click...'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	SetMarkInStrings(False, CurrentStringData.CountryOfOrigin);
	
EndProcedure // ClearMarkForRowsWithSameCountry()

// End. Procedures of managing setting/clearing mark in the rows

// Procedure - command handler SetCCDNumber
//
&AtClient
Procedure SetValues(Command)
	
	SetValuesInMarkedLinesOfTabularSection();
	
EndProcedure //SetCCDNumber()

// Procedure - command handler ClearCountryOfOrigin
//
&AtClient
Procedure TransferDataInDocument(Command)
	
	Notify("FillingNumbersOfCFD", WritePickToStorage(), OwnerFormUUID);
	
	Close();
	
EndProcedure // TransferDataInDocument()

// Procedure call handler of the tooltip on filling the CCD ticket
//
&AtClient
Procedure DecorationHelpClick(Item)
	
	ParametersToolTipManager = New Structure("Title, ToolTipKey", "How to clear CCD number?", "SupplierInvoiceNote_FillingNumbersOfCFD");
	
	OpenForm("DataProcessor.ToolTipManager.Form.Form", ParametersToolTipManager);
	
EndProcedure // DecorationHelpClick()
