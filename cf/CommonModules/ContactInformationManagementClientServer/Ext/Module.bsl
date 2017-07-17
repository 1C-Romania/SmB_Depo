////////////////////////////////////////////////////////////////////////////////
// Contact information subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region SubsystemsLibrary 

#Region Interface

// This function generates presentation and kind for address input form.
//
// Parameters:
//    AddressStructure  - Structure - address structure.
//    Presentation      - String    - address presentation.
//    KindDescription   - String    - kind description.
//
// Returns:
//    String - address and kind presentation.
//
Function GenerateAddressPresentation(AddressStructure, Presentation, KindDescription = Undefined) Export 
	
	Presentation = "";
	
	Country = ValueByStructureKey("Country", AddressStructure);
	
	If Country <> Undefined Then
		SupplementAddressPresentation(TrimAll(ValueByStructureKey("CountryDescription", AddressStructure)), ", ", Presentation);
	EndIf;
	
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Index", AddressStructure)),			", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("State", AddressStructure)),			", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("County", AddressStructure)),			", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("City", AddressStructure)),			", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Settlement", AddressStructure)),	", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Street", AddressStructure)),			", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Building", AddressStructure)),				", " + ValueByStructureKey("BuildingType", AddressStructure) + " # ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Unit", AddressStructure)),			", " + ValueByStructureKey("UnitType", AddressStructure)+ " ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Apartment", AddressStructure)),			", " + ValueByStructureKey("ApartmentType", AddressStructure) + " ", Presentation);
	
	If StrLen(Presentation) > 2 Then
		Presentation = Mid(Presentation, 3);
	EndIf;
	
	KindDescription	= ValueByStructureKey("KindDescription", AddressStructure);
	PresentationWithKind = KindDescription + ": " + Presentation;
	
	Return PresentationWithKind;
	
EndFunction

// Generates a string presentation of a phone number.
//
// Parameters:
//    CountryCode  - String - country code.
//    AreaCode     - String - area code.
//    PhoneNumber  - String - phone number.
//    Extension    - String - extension.
//    Comment      - String - comment.
//
// Returns - String - phone number presentation.
//
Function GeneratePhonePresentation(CountryCode, AreaCode, PhoneNumber, Extension, Comment) Export
	
	Presentation = TrimAll(CountryCode);
	If Not IsBlankString(Presentation) And Left(Presentation,1) <> "+" Then
		Presentation = "+" + Presentation;
	EndIf;
	
	If Not IsBlankString(AreaCode) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", " ") + "(" + TrimAll(AreaCode) + ")";
	EndIf;
	
	If Not IsBlankString(PhoneNumber) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", " ") + TrimAll(PhoneNumber);
	EndIf;
	
	If Not IsBlankString(Extension) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", ", ") + "ext. " + TrimAll(Extension);
	EndIf;
	
	If Not IsBlankString(Comment) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", ", ") + TrimAll(Comment);
	EndIf;
	
	Return Presentation;
	
EndFunction

//Returns contact information structure by type
//
// Parameters:
//    CIType - EnumRef.ContactInformationTypes - contact information type
//
// Returns:
//    Structure - empty contact information structure, keys - field names, fields values
//
Function ContactInformationStructureByType(CIType) Export
	
	If CIType = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Return AddressFieldStructure();
	ElsIf CIType = PredefinedValue("Enum.ContactInformationTypes.Phone") Then
		Return PhoneFieldStructure();
	Else
		Return New Structure;
	EndIf;
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// Adds string to address presentation.
//
// Parameters:
//    Supplement          - String - string to be added to address.
//    ConcatenationString - String - concatenation string.
//    Presentation        - String - address presentation.
//
Procedure SupplementAddressPresentation(Supplement, ConcatenationString, Presentation)
	
	If Supplement <> "" Then
		Presentation = Presentation + ConcatenationString + Supplement;
	EndIf;
	
EndProcedure

// Returns value string by structure property.
// 
// Parameters:
//    Key       - String - structure key.
//    Structure - Structure - passed structure.
//
// Returns:
//    Arbitrary - value.
//    String    - empty string if no value
//
Function ValueByStructureKey(Key, Structure)
	
	Value = Undefined;
	
	If Structure.Property(Key, Value) Then 
		Return String(Value);
	EndIf;
	
	Return "";
	
EndFunction

// Returns a string of additional values by attribute name.
//
// Parameters:
//    Form          - ManagedForm - passed form.
//    AttributeName - String      - attribute name.
//
// Returns:
//    CollectionRow - collection string.
//    Undefined     - no data
//
Function GetAdditionalValueString(Form, AttributeName) Export
	
	Filter = New Structure("AttributeName", AttributeName);
	Rows = Form.ContactInformationAdditionalAttributeInfo.FindRows(Filter);
	
	Return ?(Rows.Count() = 0, Undefined, Rows[0]);
	
EndFunction

// Returns empty address structure
//
// Returns:
//    Structure - address, keys - field names, fields values
//
Function AddressFieldStructure() Export
	
	AddressStructure = New Structure;
	AddressStructure.Insert("Presentation", "");
	AddressStructure.Insert("Country", "");
	AddressStructure.Insert("CountryDescription", "");
	AddressStructure.Insert("CountryCode","");
	AddressStructure.Insert("Index","");
	AddressStructure.Insert("State","");
	AddressStructure.Insert("StateAbbr","");
	AddressStructure.Insert("County","");
	AddressStructure.Insert("CountyAbbr","");
	AddressStructure.Insert("City","");
	AddressStructure.Insert("CityAbbr","");
	AddressStructure.Insert("Settlement","");
	AddressStructure.Insert("SettlementAbbr","");
	AddressStructure.Insert("Street","");
	AddressStructure.Insert("StreetAbbr","");
	AddressStructure.Insert("Building","");
	AddressStructure.Insert("Unit","");
	AddressStructure.Insert("Apartment","");
	AddressStructure.Insert("BuildingType","");
	AddressStructure.Insert("UnitType","");
	AddressStructure.Insert("ApartmentType","");
	AddressStructure.Insert("KindDescription","");
	
	Return AddressStructure;
	
EndFunction

// Returns empty phone structure
//
// Returns:
//    Structure - keys - field names, field values
//
Function PhoneFieldStructure() Export
	
	PhoneStructure = New Structure;
	PhoneStructure.Insert("Presentation", "");
	PhoneStructure.Insert("CountryCode", "");
	PhoneStructure.Insert("AreaCode", "");
	PhoneStructure.Insert("PhoneNumber", "");
	PhoneStructure.Insert("Extension", "");
	PhoneStructure.Insert("Comment", "");
	
	Return PhoneStructure;
	
EndFunction

// Gets abbreviated geographical name of an object
//
// Parameters:
//    GeographicalName - String - geographical name of object
//
// Returns:
//     String - empty string, or last word of the geographical name
//
Function AddressAbbreviation(Val GeographicalName) Export
	
	Abbr = "";
	WordArray = StringFunctionsClientServer.SplitStringIntoWordArray(GeographicalName, " ");
	If WordArray.Count() > 1 Then
		Abbr = WordArray[WordArray.Count() - 1];
	EndIf;
	
	Return Abbr;
	
EndFunction

// Returns field list string.
//
// Parameters:
//    FieldMap       - ValueList - field mapping.
//    NoEmptyFields  - Boolean   - flag specifying that fields with empty values should be kept (optional)
//
//  Returns:
//     String - list transformation result
//
Function ConvertFieldListToString(FieldMap, NoEmptyFields = True) Export
	
	FieldValueStructure = New Structure;
	For Each Item In FieldMap Do
		FieldValueStructure.Insert(Item.Presentation, Item.Value);
	EndDo;
	
	Return FieldRow(FieldValueStructure, NoEmptyFields);
EndFunction

// Returns value list. Transforms field string to value list.
//
// Parameters:
//    FieldRow - String - field string.
//
// Returns:
//    ValueList - field value list.
//
Function ConvertStringToFieldList(FieldRow) Export
	
	// Transformation of XML serialization not necessary
	If ContactInformationClientServer.IsXMLContactInformation(FieldRow) Then
		Return FieldRow;
	EndIf;
	
	Result = New ValueList;
	
	FieldValueStructure = FieldValueStructure(FieldRow);
	For Each AttributeValue In FieldValueStructure Do
		Result.Add(AttributeValue.Value, AttributeValue.Key);
	EndDo;
	
	Return Result;
	
EndFunction

//  Transforms string containing Key=Value pairs to structure
//
//  Parameters:
//      FieldRow               - String - string containing data fields in Key=Value format 
//      ContactInformationKind - CatalogRef.ContactInformationKinds - used to determine unfilled field content
//
//  Returns:
//      Structure - field values
//
Function FieldValueStructure(FieldRow, ContactInformationKind = Undefined) Export
	
	If ContactInformationKind = Undefined Then
		Result = New Structure;
	Else
		Result = ContactInformationStructureByType(ContactInformationKind.Type);
	EndIf;
	
	LastItem = Undefined;
	
	For Iteration = 1 To StrLineCount(FieldRow) Do
		ReceivedString = StrGetLine(FieldRow, Iteration);
		If Left(ReceivedString, 1) = Chars.Tab Then
			If Result.Count() > 0 Then
				Result.Insert(LastItem, Result[LastItem] + Chars.LF + Mid(ReceivedString, 2));
			EndIf;
		Else
			CharPosition = Find(ReceivedString, "=");
			If CharPosition <> 0 Then
				FieldValue = Left(ReceivedString, CharPosition - 1);
				AttributeValue = Mid(ReceivedString, CharPosition + 1);
				If FieldValue = "State" Or FieldValue = "County" Or FieldValue = "City" 
					Or FieldValue = "Settlement" Or FieldValue = "Street" Then
					If Find(FieldRow, FieldValue + "Abbr") = 0 Then
						Result.Insert(FieldValue + "Abbr", AddressAbbreviation(AttributeValue));
					EndIf;
				EndIf;
				Result.Insert(FieldValue, AttributeValue);
				LastItem = FieldValue;
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

//  Returns field list string.
//
//  Parameters:
//    FieldValueStructure - Structure - field value structure.
//    NoEmptyFields       - Boolean   - flag specifying if fields with empty values should be kept (optional)
//
//  Returns:
//      String - structure transformation result
//
Function FieldRow(FieldValueStructure, NoEmptyFields = True) Export
	
	Result = "";
	For Each AttributeValue In FieldValueStructure Do
		If NoEmptyFields And IsBlankString(AttributeValue.Value) Then
			Continue;
		EndIf;
		
		Result = Result + ?(Result = "", "", Chars.LF)
		            + AttributeValue.Key + "=" + StrReplace(AttributeValue.Value, Chars.LF, Chars.LF + Chars.Tab);
	EndDo;
	
	Return Result;
EndFunction

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

// The function generates a full name from the address array.
//
// Parameters:
//  Address - array - array containing address objects.
// Returns:
//  String - Full address name as a string.
Function GenerateFullDescr(Address) Export
	
	FullDescr = "";
	Delimiter = "";
	For Each Item In Address Do
		If ValueIsFilled(Item) Then 
			FullDescr = FullDescr + Delimiter + Item;
			Delimiter = ", ";
		EndIf;
	EndDo;
	
	Return FullDescr;
EndFunction


#Region ServiceProceduresAndFunctionsForWorkWithXMLAddresses


// Returns a structure with a name and a value abbreviation.
//
// Parameters:
//     Text - String - Full name.
//
// Returns:
//     Structure - data processor result.
//         * Description - String - text part.
//         * Abbreviation   - String - text part.
//
Function DescriptionAbbreviation(Val Text) Export
	Result = New Structure("Description, Abbr");
	
	Parts = NamesAndAbbreviationsSet(Text, True);
	If Parts.Count() > 0 Then
		FillPropertyValues(Result, Parts[0]);
	Else
		Result.Description = Text;
	EndIf;
	
	Return Result;
EndFunction

// Separately returns a value abbreviation.
//
// Parameters:
//     Text - String - Full name.
//
// Returns:
//     String - selected abbreviation.
//
Function Abbr(Val Text) Export
	
	Parts = DescriptionAbbreviation(Text);
	Return Parts.Abbr;
	
EndFunction

// Divides a text into words by specified separators. By default, separators - space characters.
//
// Parameters:
//     Text       - String - Separated string.
//     Separators - String - Optional string of separator characters.
//
// Returns:
//     Array - rows, words
//
Function WordsText(Val Text, Val Separators = Undefined) Export
	
	WordStart = 0;
	State   = 0;
	Result   = New Array;
	
	For Position = 1 To StrLen(Text) Do
		CurrentChar = Mid(Text, Position, 1);
		IsSplitter = ?(Separators = Undefined, IsBlankString(CurrentChar), Find(Separators, CurrentChar) > 0);
		
		If State = 0 AND (Not IsSplitter) Then
			WordStart = Position;
			State   = 1;
		ElsIf State = 1 AND IsSplitter Then
			Result.Add(Mid(Text, WordStart, Position-WordStart));
			State = 0;
		EndIf;
	EndDo;
	
	If State = 1 Then
		Result.Add(Mid(Text, WordStart, Position-WordStart));    
	EndIf;
	
	Return Result;
EndFunction

// Divides a comma-separated text.
//
// Parameters:
//     Text              - Of deadline  - Shared text.
//     AllocateReductions - Boolean - Optional parameter of the working schedule.
//
// Returns:
//     Array - contains structures "Description, Abbr".
//
Function NamesAndAbbreviationsSet(Val Text, Val AllocateReductions = True) Export
	
	Result = New Array;
	For Each part In WordsText(Text, ",") Do
		StringParts = TrimAll(part);
		If IsBlankString(StringParts) Then
			Continue;
		EndIf;
		
		Position = ?(AllocateReductions, StrLen(StringParts), 0);
		While Position > 0 Do
			If Mid(StringParts, Position, 1) = " " Then
				Result.Add(New Structure("Description, Abbr",
					TrimAll(Left(StringParts, Position-1)), TrimAll(Mid(StringParts, Position))));
				Position = -1;
				Break;
			EndIf;
			Position = Position - 1;
		EndDo;
		If Position = 0 Then
			Result.Add(New Structure("Description, Abbr", StringParts));
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction    

// Returns the first item from the list.
//
// Parameters:
//     DataList - ValueList, Array, FormField
//
// Returns:
//     Arbitrary - first item.
//     Undefined - no first item.
// 
Function FirstOrEmpty(Val DataList) Export
	
	TypeList = TypeOf(DataList);
	If TypeList = Type("ValueList") AND DataList.Count() > 0 Then
		Return DataList[0].Value;
	ElsIf TypeList = Type("Array") AND DataList.Count() > 0 Then
		Return DataList[0];
	ElsIf TypeList = Type("FormField") Then
		Return FirstOrEmpty(DataList.ChoiceList);
	EndIf;
	
	Return Undefined;
EndFunction

//  Returns a structure that describes a locality with hierarchy junior-senior.
// 
//  Parameters:
//      ClassifierVariant  String - Required classifier kind. 
// 
// Returns:
//      Structure - description of a locality.
//
Function LocalityAddressPartsStructure() Export
	
	Result = New Structure;
	
	Result.Insert("State",	ItemAddressStructure(NStr("en='Region';ru='Регион'"),	NStr("en='Address region';ru='Регион адреса'"),	"RFTerritorialEntity",	1));
	Result.Insert("Region",	ItemAddressStructure(NStr("en='District';ru='Район'"),	NStr("ru = 'Район адреса'; en = 'Address county'"),		"PrRayMO/Region",		3));
	Result.Insert("City",	ItemAddressStructure(NStr("ru = 'Город'; en = 'City'"),		NStr("ru = 'Город адреса'; en = 'Address city'"),		"City",					4));
	Result.Insert("Settlement", ItemAddressStructure(NStr("ru = 'Населенный пункт'; en = 'Settlement'"),
		NStr("en='Settlement addresses';ru='Населенный пункт адреса'"), "Settlement",  6, True));
	Result.Insert("Street", ItemAddressStructure(NStr("ru = 'Улица'; en = 'Street'"),
		NStr("ru = 'Улица адреса'; en = 'Address street'"), "Street", 7));
	Result.Insert("AdditionalItem", ItemAddressStructure(NStr("ru = 'Дополнительный элемент'; en = 'Additional item'"),
		NStr("ru = 'Дополнительный элемент адреса'; en = 'Additional address item'"), "AddEMailAddress[TypeAdrEl='10200000']", 90));
	Result.Insert("SubordinateItem", ItemAddressStructure(NStr("ru = 'Подчиненный элемент'; en = 'Subordinate item'"),
		NStr("ru = 'Подчиненный элемент адреса'; en = 'Subordinate address item'"), "AddEMailAddress[TypeAdrEl='10400000']", 91));
		
	Return Result;
	
EndFunction

// Processes a structure of the address parts and returns an identifier of the nearest particular parent.
//
// Parameters:
//     PartAddresses - String, Structure - Part identifier or the part itself.
//     PartsAddresses - Structure - Description of the current address state.
//
// Returns:
//     UUID - identifier of the parent.
//
Function ItemAddressPartParentIdentifier(PartAddresses, PartsAddresses) Export
	
	PathXPath = PartAddresses.PathXPath;
	Item   = Undefined;
	
	Order = New ValueList;
	For Each KeyValue In PartsAddresses Do
		part = KeyValue.Value;
		NewItem = Order.Add(part.Level, KeyValue.Key);
		If part.PathXPath = PathXPath Then
			Item = NewItem;
		EndIf;
	EndDo;
	Order.SortByValue(SortDirection.Desc);
	
	If Item <> Undefined Then
		For Position = Order.IndexOf(Item) + 1 To Order.Count() - 1 Do
			part = PartsAddresses[ Order[Position].Presentation ];
			If ValueIsFilled(part.Presentation) Then
				Return part.Identifier;
			EndIf;
		EndDo;
	EndIf;
	
	Return Undefined;
EndFunction

// Processes a structure of the address parts and returns an identifier of the last populated item.
//
// Parameters:
//     PartsAddresses - Structure - Description of the current address state.
//
// Returns:
//     UUID - identifier.
//
Function ItemIdentifierByAddressParts(PartsAddresses) Export
	
	Order = New ValueList;
	For Each KeyValue In PartsAddresses Do
		Order.Add(KeyValue.Value.Level, KeyValue.Key);
	EndDo;
	Order.SortByValue(SortDirection.Desc);
	
	For Each ItemOfList In Order Do
		AttributeName = ItemOfList.Presentation;
		If PartsAddresses.Property(AttributeName) Then
			PartAddresses = PartsAddresses[AttributeName];
			If ValueIsFilled(PartAddresses.Presentation) Then
				Return PartAddresses.Identifier;
			EndIf;
		EndIf
	EndDo;
	
	Return Undefined;
EndFunction

// Processes a structure of the address parts.
//
// Parameters:
//     AddressesPartName    - String    - Part identifier.
//     PartsAddresses       - Structure - Description of the current address state.
//     ValueSelected - String, Structure - new value.
//
// Returns:
//     String - New presentation of the address part.
//
Function SetPartsAddressesValue(AddressesPartName, PartsAddresses, ValueSelected) Export
	
	PartAddresses = PartsAddresses[AddressesPartName];
	
	If TypeOf(ValueSelected) = Type("Structure") Then
		PartAddresses.Identifier = ValueSelected.Identifier;
		PartAddresses.Presentation = ValueSelected.Presentation;
	Else
		PartAddresses.Identifier = Undefined;
		PartAddresses.Presentation = TrimAll(ValueSelected);
	EndIf;
	
	Presentation = PartAddresses.Presentation;
	
	Parts = DescriptionAbbreviation(Presentation);
	PartAddresses.Description = Parts.Description;
	PartAddresses.Abbr   = Parts.Abbr;
	
	Return Presentation;
EndFunction

//  Returns a full locality name. Locality is a synthetic field that includes everything larger than a street.
//
//  Parameters:
//      PartsAddresses           - Structure - Description of the current address state.
//      ClassifierVariant - String    - Classifier option.
//
Function SettlementPresentationByAddressParts(PartsAddresses) Export
	
	Levels = New Array;
	Levels.Add(1);
	Levels.Add(3);
	Levels.Add(4);
	Levels.Add(6);
	Return PresentationByAddressParts(PartsAddresses,Levels);
	
EndFunction

//  Returns a full street name. Street is a synthetic field that includes everything that is less than or equals to a street.
//
//  Parameters:
//      PartsAddresses           - Structure - Description of the current address state.
//      ClassifierVariant - String    - Classifier option.
//
Function StreetPresentationByAddressParts(PartsAddresses) Export
	
	Levels = New Array;
	Levels.Add(7);
	Return PresentationByAddressParts(PartsAddresses, Levels);
	
EndFunction

// Constructor of the internal address item structure.
//
Function ItemAddressStructure(Title, ToolTip, PathXPath, Level, Predefined = False)
	
	Result = New Structure("Description, Abbr, Identifier, Presentation");
	Result.Insert("Title",        Title);
	Result.Insert("ToolTip",        ToolTip);
	Result.Insert("PathXPath",        PathXPath);
	Result.Insert("Predefined", Predefined);
	Result.Insert("Level",          Level);
	
	Return Result;
EndFunction

// Presentation string by the address parts in the required sequence.
//
Function PresentationByAddressParts(PartsAddresses, Levels)
	
	Prototype = LocalityAddressPartsStructure();
	
	Order = New ValueList;
	For Each KeyValue In Prototype Do
		If Levels.Find(KeyValue.Value.Level) <> Undefined Then
			Order.Add(KeyValue.Value.Level, KeyValue.Key);
		EndIf;
	EndDo;
	Order.SortByValue(SortDirection.Desc);
	
	Result = "";
	For Each ItemOfList In Order Do
		AttributeName = ItemOfList.Presentation;
		If PartsAddresses.Property(AttributeName) Then
			PresentationPart = PartsAddresses[AttributeName].Presentation;
			If Not IsBlankString(PresentationPart) Then
				Result = Result + ", " + PresentationPart;
			EndIf;
		EndIf
	EndDo;
	
	Return TrimAll(Mid(Result, 2));
EndFunction

#EndRegion

#EndRegion
