Procedure AddSerialNumberToString(NewRow, SerialNumber, DocObject, FieldNameConnectionKey = "ConnectionKey") Export
	
	FilterSerialNumber = New Structure("SerialNumber", SerialNumber);
	If DocObject.SerialNumbers.FindRows(FilterSerialNumber).Count()>0 Then
		//Serial number already exists, skip it
		Return;
	EndIf;
	
	If NewRow[FieldNameConnectionKey]=0 Then
		FillConnectionKeysInTabularSectionProducts(DocObject, "Inventory", ,FieldNameConnectionKey);
	EndIf;
	
	StrSerialNumbers = DocObject.SerialNumbers.Add();
	StrSerialNumbers.SerialNumber = SerialNumber;
	StrSerialNumbers.ConnectionKey = NewRow[FieldNameConnectionKey];
	
	If DocObject.SerialNumbers.Count()>1 Then
		UpdateStringPresentationOfSerialNumbersOfLine(NewRow, DocObject, FieldNameConnectionKey);
	Else
		NewRow.SerialNumbers = String(SerialNumber);
	EndIf;
	
EndProcedure

Procedure UpdateStringPresentationOfSerialNumbersOfLine(StringInventory, DocObject, FieldNameConnectionKey, SerialNumbersTabularSectionName="SerialNumbers") Export
	
	FilterSerialNumbersOfCurrentString = New Structure("ConnectionKey", StringInventory[FieldNameConnectionKey]);
	StringPresentationOfSerialNumbers = "";
	
	For Each ImportRow In DocObject[SerialNumbersTabularSectionName].FindRows(FilterSerialNumbersOfCurrentString) Do
		StringPresentationOfSerialNumbers = StringPresentationOfSerialNumbers + ImportRow.SerialNumber+"; ";
	EndDo;
	
	StringPresentationOfSerialNumbers = Left(StringPresentationOfSerialNumbers, Min(StrLen(StringPresentationOfSerialNumbers)-2,150));
	If StrFind(SerialNumbersTabularSectionName, "Posting") = 0 Then
		StringInventory.SerialNumbers = StringPresentationOfSerialNumbers;
	Else
		StringInventory.SerialNumbersPosting = StringPresentationOfSerialNumbers;
	EndIf;
	
EndProcedure

Function StringPresentationOfSerialNumbersOfLine(SerialNumbers, ConnectionKey) Export
	
	FilterConnectionKey = New Structure("ConnectionKey", ConnectionKey);
	
	StringPresentationOfSerialNumbers = "";
	For Each Str In SerialNumbers.FindRows(FilterConnectionKey) Do
		StringPresentationOfSerialNumbers = StringPresentationOfSerialNumbers + Str.SerialNumber+"; ";
	EndDo;
	
	StringPresentationOfSerialNumbers = Left(StringPresentationOfSerialNumbers, Min(StrLen(StringPresentationOfSerialNumbers)-2,150));
	Return StringPresentationOfSerialNumbers;
	
EndFunction

// The function fills the connection keys in the "Products" table section of the document.
Procedure FillConnectionKeysInTabularSectionProducts(Object, TSName, TSName2 = Undefined, FieldNameConnectionKey = "ConnectionKey") Export
	
	For Each TSRow In Object[TSName] Do
		If Not ValueIsFilled(TSRow[FieldNameConnectionKey]) Then
			FillConnectionKey(Object[TSName], TSRow, FieldNameConnectionKey);
		EndIf;
	EndDo;
	
	Index = 0;
	If Not TSName2 = Undefined Then
		For Each TSRow In Object[TSName2] Do
			Index = Index + 1;
			TSRow.ConnectionKeyForMarkupAndDiscount = Index;
		EndDo;
	EndIf;
	
EndProcedure // FillConnectionKeysInTabularSectionProducts()

Procedure UpdateSerialNumbersQuantity(Object, TabularSectionRow, SerialNumbersTabularSectionName="SerialNumbers", FieldNameConnectionKey = "ConnectionKey") Export

	If NOT ValueIsFilled(TabularSectionRow[FieldNameConnectionKey]) Then
		Return;
	EndIf; 
	
	TheStructureOfTheSearch = New Structure("ConnectionKey", TabularSectionRow[FieldNameConnectionKey]);
	ArrayOfSNString = New FixedArray(Object[SerialNumbersTabularSectionName].FindRows(TheStructureOfTheSearch));
	
	If TypeOf(TabularSectionRow.MeasurementUnit)=Type("CatalogRef.UOM") Then
		Ratio = WorkWithSerialNumbers.UnitRatio(TabularSectionRow.MeasurementUnit);
	Else
		Ratio = 1;
	EndIf;
	
	RowInventoryQuantity = TabularSectionRow.Quantity * Ratio;

	If RowInventoryQuantity < ArrayOfSNString.Count() AND RowInventoryQuantity > 0 Then
		For n=RowInventoryQuantity To ArrayOfSNString.Count()-1 Do
			RowDelete = ArrayOfSNString[n];
			Object[SerialNumbersTabularSectionName].Delete(RowDelete);	
		EndDo;
	EndIf;

	UpdateStringPresentationOfSerialNumbersOfLine(TabularSectionRow, Object, FieldNameConnectionKey, SerialNumbersTabularSectionName);
	
EndProcedure

Function CharNumber() Export
	Return "#";
EndFunction

Function StringOfMaskByTemplate(TemplateSerialNumber) Export
	
	//Screening special characters
	SpecialCharacters = New Map;
	SpecialCharacters.Insert("9","\9");
	SpecialCharacters.Insert("N","\N");
	SpecialCharacters.Insert("U","\U");
	SpecialCharacters.Insert("X","\X");
	SpecialCharacters.Insert("h","\h");
	SpecialCharacters.Insert("@","\@");
	
	StringOfMask = "";
	For n=1 To StrLen(TemplateSerialNumber) Do
		Symb = Mid(TemplateSerialNumber, n, 1);
		
		If SpecialCharacters.Get(Symb)<>Undefined Then
			StringOfMask = StringOfMask + SpecialCharacters.Get(Symb);
		ElsIf Symb=CharNumber() Then
			StringOfMask = StringOfMask + "9";
		Else
			StringOfMask = StringOfMask + Symb;
		EndIf;
	EndDo;
	
	Return StringOfMask;
	
EndFunction

// Deletes the rows by the connection key in the SerialNumbers table section, clears the serial number representation line
Procedure DeleteSerialNumbersByConnectionKey(TabularSectionSN, TabularSectionRow, FieldNameConnectionKey = "ConnectionKey", UseSerialNumbersBalance,
	SerialNumbersTabularSectionName = "SerialNumbers") Export
	
	If UseSerialNumbersBalance=Undefined Then
		Return;
	EndIf;
	
	If NOT ValueIsFilled(TabularSectionRow[FieldNameConnectionKey]) Then
		Return;
	EndIf; 
	
	TheStructureOfTheSearch = New Structure("ConnectionKey", TabularSectionRow[FieldNameConnectionKey]);
	RowsToDelete = TabularSectionSN.FindRows(TheStructureOfTheSearch);
	For Each TableRow In RowsToDelete Do
		
		TabularSectionSN.Delete(TableRow);
		
	EndDo;
	
	If StrFind(SerialNumbersTabularSectionName, "Posting") = 0 Then
		TabularSectionRow.SerialNumbers = "";
	Else
		TabularSectionRow.SerialNumbersPosting = "";
	EndIf;
	
EndProcedure

// Fills the connection key of the
//document table or data processor
Procedure FillConnectionKey(TabularSection, TabularSectionRow, ConnectionAttributeName, TempConnectionKey = 0) Export
	
	If NOT ValueIsFilled(TabularSectionRow[ConnectionAttributeName]) Then
		If TempConnectionKey = 0 Then
			For Each TSRow In TabularSection Do
				If TempConnectionKey < TSRow[ConnectionAttributeName] Then
					TempConnectionKey = TSRow[ConnectionAttributeName];
				EndIf;
			EndDo;
		EndIf;
		TabularSectionRow[ConnectionAttributeName] = TempConnectionKey + 1;
	EndIf;
	
EndProcedure