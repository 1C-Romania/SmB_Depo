////////////////////////////////////////////////////////////////////////////////
// The Contact information subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// The function generates a presentation with a kind for the address input form.
//
// Parameters:
//    StructureOfAddress  - Structure - address structure.
//    Presentation    - String - address presentation.
//    KindDescription - String - kind name.
//
// Returns:
//    String - address presentation with a kind.
//
Function GenerateAddressPresentation(StructureOfAddress, Presentation, KindDescription = Undefined) Export 
	
	Presentation = "";
	
	Country = ValueByStructureKey("Country", StructureOfAddress);
	
	If Country <> Undefined Then
		SupplementAddressPresentation(TrimAll(ValueByStructureKey("CountryDescription", StructureOfAddress)), ", ", Presentation);
	EndIf;
	
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("IndexOf", StructureOfAddress)),			", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("State", StructureOfAddress)),			", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Region", StructureOfAddress)),			", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("City", StructureOfAddress)),			", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Settlement", StructureOfAddress)),	", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Street", StructureOfAddress)),			", ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("House", StructureOfAddress)),				", " + ValueByStructureKey("HouseType", StructureOfAddress) + " No. ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Block", StructureOfAddress)),			", " + ValueByStructureKey("BlockType", StructureOfAddress)+ " ", Presentation);
	SupplementAddressPresentation(TrimAll(ValueByStructureKey("Apartment", StructureOfAddress)),			", " + ValueByStructureKey("ApartmentType", StructureOfAddress) + " ", Presentation);
	
	If StrLen(Presentation) > 2 Then
		Presentation = Mid(Presentation, 3);
	EndIf;
	
	KindDescription = ValueByStructureKey("KindDescription", StructureOfAddress);
	PresentationWithKind = KindDescription + ": " + Presentation;
	
	Return PresentationWithKind;
	
EndFunction

// Creates a string presentation of the phone number.
//
// Parameters:
//    CountryCode     - String - country code.
//    CityCode     - String - city code.
//    PhoneNumber - String - phone number.
//    Supplementary    - String - extension.
//    Comment   - String - comment.
//
// Returns - String - phone presentation.
//
Function GeneratePhonePresentation(CountryCode, CityCode, PhoneNumber, Supplementary, Comment) Export
	
	Presentation = TrimAll(CountryCode);
	If Not IsBlankString(Presentation) AND Left(Presentation,1) <> "+" Then
		Presentation = "+" + Presentation;
	EndIf;
	
	If Not IsBlankString(CityCode) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", " ") + "(" + TrimAll(CityCode) + ")";
	EndIf;
	
	If Not IsBlankString(PhoneNumber) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", " ") + TrimAll(PhoneNumber);
	EndIf;
	
	If Not IsBlankString(Supplementary) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", ", ") + "ext. " + TrimAll(Supplementary);
	EndIf;
	
	If Not IsBlankString(Comment) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", ", ") + TrimAll(Comment);
	EndIf;
	
	Return Presentation;
	
EndFunction

// Returns a contact information structure by type.
//
// Parameters:
//    CIType - EnumRef.ContactInformationTypes - contact information type.
//
// Returns:
//    Structure - empty structure of contact information, keys - fields names, field values.
//
Function StructureContactInformationByType(CIType) Export
	
	If CIType = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Return AddressFieldsStructure();
	ElsIf CIType = PredefinedValue("Enum.ContactInformationTypes.Phone") Then
		Return PhoneFieldsStructure();
	Else
		Return New Structure;
	EndIf;
	
EndFunction

// Returns a flag showing whether a contact information data string is XML data.
//
// Parameters:
//     Text - String - Checking string.
//
// Returns:
//     Boolean - checking result.
//
Function IsContactInformationInXML(Val Text) Export
	
	Return TypeOf(Text) = Type("String") AND Left(TrimL(Text),1) = "<";
	
EndFunction

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
Function LocalityAddressPartsStructure(ClassifierVariant = "FIAS") Export
	
	Result = New Structure;
	
	Result.Insert("State",           ItemAddressStructure(NStr("en='State';ru='Состояние'"),      NStr("en='Addresses state';ru='Регион адреса'"),           "RFTerritorialEntity",     1));
	If ClassifierVariant = "FIAS" Then
		Result.Insert("District",        ItemAddressStructure(NStr("en='District';ru='Район'"),       NStr("en='Address region';ru='Округ адреса'"),            "District",         2));
	EndIf;
	Result.Insert("Region",            ItemAddressStructure(NStr("en='Region';ru='Регион'"),       NStr("en='Address region';ru='Округ адреса'"),            "PrRayMO/Region", 3));
	Result.Insert("City",            ItemAddressStructure(NStr("en='City';ru='Город'"),       NStr("en='Address city';ru='Город адреса'"),            "City",         4));
	If ClassifierVariant = "FIAS" Then
		Result.Insert("UrbDistrict", ItemAddressStructure(NStr("en='Ext. dis.';ru='Внутр. р-н.'"), NStr("en='Urban district';ru='Внутригородской район'"),   "UrbDistrict",  5));
	EndIf;
	Result.Insert("Settlement", ItemAddressStructure(NStr("en='Us.Item';ru='Us.Item'"),
		NStr("en='Addresses of settlement';ru='Населенный пункт адреса'"), "Settlement",  6, True));
	Result.Insert("Street", ItemAddressStructure(NStr("en='Street';ru='Улица'"),
		NStr("en='Address street';ru='Улица адреса'"), "Street", 7));
	Result.Insert("AdditionalItem", ItemAddressStructure(NStr("en='AdditionalItem';ru='AdditionalItem'"),
		NStr("en='Additional address item';ru='Дополнительный элемент адреса'"), "AddEMailAddress[TypeAdrEl='10200000']", 90));
	Result.Insert("SubordinateItem", ItemAddressStructure(NStr("en='Subordinate item';ru='Подчиненный элемент'"),
		NStr("en='Subordinate address item';ru='Подчиненный элемент адреса'"), "AddEMailAddress[TypeAdrEl='10400000']", 91));
		
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
Function SettlementPresentationByAddressParts(PartsAddresses, ClassifierVariant = "FIAS") Export
	
	Levels = New Array;
	Levels.Add(1);
	Levels.Add(3);
	Levels.Add(4);
	Levels.Add(6);
	If ClassifierVariant = "FIAS" Then
		Levels.Add(2);
		Levels.Add(5);
	EndIf;
	Return PresentationByAddressParts(PartsAddresses,Levels);
	
EndFunction

//  Returns a full street name. Street is a synthetic field that includes everything that is less than or equals to a street.
//
//  Parameters:
//      PartsAddresses           - Structure - Description of the current address state.
//      ClassifierVariant - String    - Classifier option.
//
Function StreetPresentationByAddressParts(PartsAddresses, ClassifierVariant = "FIAS") Export
	
	Levels = New Array;
	Levels.Add(7);
	If ClassifierVariant = "FIAS" Then
		Levels.Add(90);
		Levels.Add(91);
	EndIf;
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

#Region OtherServiceProceduresAndFunctions

// Supplements an address presentation with a string.
//
// Parameters:
//    Supplement         - String - address addition.
//    ConcatenationString - String - concatenation string.
//    Presentation      - String - address presentation.
//
Procedure SupplementAddressPresentation(Supplement, ConcatenationString, Presentation)
	
	If Supplement <> "" Then
		Presentation = Presentation + ConcatenationString + Supplement;
	EndIf;
	
EndProcedure

// Returns a value string by the structure property.
// 
// Parameters:
//    Key - String - structure key.
//    Structure - Structure - passed structure.
//
// Returns:
//    Arbitrary - value.
//    String       - empty string if there is no value.
//
Function ValueByStructureKey(Key, Structure)
	
	Value = Undefined;
	
	If Structure.Property(Key, Value) Then 
		Return String(Value);
	EndIf;
	
	Return "";
	
EndFunction

// Returns a string of additional values by an attribute name.
//
// Parameters:
//    Form - ManagedForm - passed form.
//    AttributeName - String - attribute name.
//
// Returns:
//    CollectionRow - string of collection.
//    Undefined - no data.
//
Function GetAdditionalValuesString(Form, AttributeName) Export
	
	Filter = New Structure("AttributeName", AttributeName);
	Rows = Form.ContactInformationAdditionalAttributeInfo.FindRows(Filter);
	
	Return ?(Rows.Count() = 0, Undefined, Rows[0]);
	
EndFunction

// Returns en empty address structure.
//
// Returns:
//    Structure - address, keys - fields names, field values.
//
Function AddressFieldsStructure() Export
	
	StructureOfAddress = New Structure;
	StructureOfAddress.Insert("Presentation", "");
	StructureOfAddress.Insert("Country", "");
	StructureOfAddress.Insert("CountryDescription", "");
	StructureOfAddress.Insert("CountryCode","");
	StructureOfAddress.Insert("IndexOf","");
	StructureOfAddress.Insert("State","");
	StructureOfAddress.Insert("StateAbbr","");
	StructureOfAddress.Insert("Region","");
	StructureOfAddress.Insert("RegionAbbr","");
	StructureOfAddress.Insert("City","");
	StructureOfAddress.Insert("CityAbbr","");
	StructureOfAddress.Insert("Settlement","");
	StructureOfAddress.Insert("SettlementAbbr","");
	StructureOfAddress.Insert("Street","");
	StructureOfAddress.Insert("StreetAbbr","");
	StructureOfAddress.Insert("House","");
	StructureOfAddress.Insert("Block","");
	StructureOfAddress.Insert("Apartment","");
	StructureOfAddress.Insert("HouseType","");
	StructureOfAddress.Insert("BlockType","");
	StructureOfAddress.Insert("ApartmentType","");
	StructureOfAddress.Insert("KindDescription","");
	
	Return StructureOfAddress;
	
EndFunction

// Returns an empty phone structure.
//
// Returns:
//    Structure - keys - fields names, field values.
//
Function PhoneFieldsStructure() Export
	
	PhoneStructure = New Structure;
	PhoneStructure.Insert("Presentation", "");
	PhoneStructure.Insert("CountryCode", "");
	PhoneStructure.Insert("CityCode", "");
	PhoneStructure.Insert("PhoneNumber", "");
	PhoneStructure.Insert("Supplementary", "");
	PhoneStructure.Insert("Comment", "");
	
	Return PhoneStructure;
	
EndFunction

// Gets an abbreviation of the geographical object name.
//
// Parameters:
//    GeographicalName - String - geographical object name.
//
// Returns:
//     String - empty string or the last word in the geographical name.
//
Function AddressAbbreviation(Val GeographicalName) Export
	
	Abbr = "";
	ArrayOfWords = StringFunctionsClientServer.SplitStringIntoWordArray(GeographicalName, " ");
	If ArrayOfWords.Count() > 1 Then
		Abbr = ArrayOfWords[ArrayOfWords.Count() - 1];
	EndIf;
	
	Return Abbr;
	
EndFunction

// Returns a string of field list.
//
// Parameters:
//    FieldMap - ValueList - field matches.
//    WithoutEmptyFields    - Boolean - optional check box for saving fields with empty values.
//
//  Returns:
//     String - result converted from the list.
//
Function ConvertFieldListToString(FieldMap, WithoutEmptyFields = True) Export
	
	FieldValuesStructure = New Structure;
	For Each Item In FieldMap Do
		FieldValuesStructure.Insert(Item.Presentation, Item.Value);
	EndDo;
	
	Return FieldsRow(FieldValuesStructure, WithoutEmptyFields);
EndFunction

// Returns a list of values. Converts the field string to the value list.
//
// Parameters:
//    FieldsRow - String - fields string.
//
// Returns:
//    ValueList - list of field values.
//
Function ConvertStringToFieldList(FieldsRow) Export
	
	// It is not required to convert XML serialization.
	If IsContactInformationInXML(FieldsRow) Then
		Return FieldsRow;
	EndIf;
	
	Result = New ValueList;
	
	FieldValuesStructure = FieldValuesStructure(FieldsRow);
	For Each FieldValue In FieldValuesStructure Do
		Result.Add(FieldValue.Value, FieldValue.Key);
	EndDo;
	
	Return Result;
	
EndFunction

//  Converts a field string of kind key = value into a structure.
//
//  Parameters:
//      FieldsRow             - String - field value with data of kind key = value.
//      ContactInformationKind - CatalogRef.ContactInformationTypes - to define content
//                                                                            of unfilled fields.
//
//  Returns:
//      Structure - fields value.
//
Function FieldValuesStructure(FieldsRow, ContactInformationKind = Undefined) Export
	
	If ContactInformationKind = Undefined Then
		Result = New Structure;
	Else
		Result = StructureContactInformationByType(ContactInformationKind.Type);
	EndIf;
	
	LastItem = Undefined;
	
	For Iteration = 1 To StrLineCount(FieldsRow) Do
		ReceivedString = StrGetLine(FieldsRow, Iteration);
		If Left(ReceivedString, 1) = Chars.Tab Then
			If Result.Count() > 0 Then
				Result.Insert(LastItem, Result[LastItem] + Chars.LF + Mid(ReceivedString, 2));
			EndIf;
		Else
			CharPosition = Find(ReceivedString, "=");
			If CharPosition <> 0 Then
				FieldsName = Left(ReceivedString, CharPosition - 1);
				FieldValue = Mid(ReceivedString, CharPosition + 1);
				If FieldsName = "State" Or FieldsName = "Region" Or FieldsName = "City" 
					Or FieldsName = "Settlement" Or FieldsName = "Street" Then
					If Find(FieldsRow, FieldsName + "Abbr") = 0 Then
						Result.Insert(FieldsName + "Abbr", AddressAbbreviation(FieldValue));
					EndIf;
				EndIf;
				Result.Insert(FieldsName, FieldValue);
				LastItem = FieldsName;
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

//  Returns a string of field list.
//
//  Parameters:
//    FieldValuesStructure - Structure - structure of field values.
//    WithoutEmptyFields         - Boolean - optional check box for saving fields with empty values.
//
//  Returns:
//      String - conversion result from a structure.
//
Function FieldsRow(FieldValuesStructure, WithoutEmptyFields = True) Export
	
	Result = "";
	For Each FieldValue In FieldValuesStructure Do
		If WithoutEmptyFields AND IsBlankString(FieldValue.Value) Then
			Continue;
		EndIf;
		
		Result = Result + ?(Result = "", "", Chars.LF)
		            + FieldValue.Key + "=" + StrReplace(FieldValue.Value, Chars.LF, Chars.LF + Chars.Tab);
	EndDo;
	
	Return Result;
EndFunction

#EndRegion

#EndRegion
