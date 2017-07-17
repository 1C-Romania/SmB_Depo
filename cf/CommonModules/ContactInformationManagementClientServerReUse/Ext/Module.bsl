////////////////////////////////////////////////////////////////////////////////////////////////////
// The Contact information subsystem.
// 
////////////////////////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

//  Returns the code of an additional address part for serialization.
//
//  Parameters:
//      RowOfValue - String - value for search, for example, "House", "Block", "Letter".
//
// Returns:
//      Number - code
// 
Function AddressingObjectSerializationCode(RowOfValue) Export
	
	VarKey = Upper(TrimAll(RowOfValue));
	For Each Item In TypesOfAddressingAddressesRF() Do
		If Item.Key = VarKey Then
			Return Item.Code;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

//  Returns the code of an additional address part for the postal code.
//
// Returns:
//      String - code
//
Function SerializationCodePostalIndex() Export
	
	Return AddressingObjectSerializationCode(NStr("en='Zip code';ru='Почтовый индекс'"));
	
EndFunction

//  Returns Xpath for the postal code.
//
// Returns:
//      String - XPath
//
Function XMailPathIndex() Export
	
	Return "AddEMailAddress[TypeAdrEl='" + SerializationCodePostalIndex() + "']";
	
EndFunction

//  Returns XPath for the region.
//
// Returns:
//      String - XPath
//
Function RegionXPath() Export
	
	Return "PrRayMO/Region";
	
EndFunction

Function AdditionalAddressingObjectSerializationCode(Level, AddressPointType = "") Export
	
	If Level = 90 Then
		If Upper(AddressPointType) = "GSK" Then
			Return "10600000";
		ElsIf Upper(AddressPointType) = "SNT" Then
			Return "10300000";
		ElsIf Upper(AddressPointType) = "TER" Then
			Return "10700000";
		Else
			Return "10200000";
		EndIf;
	ElsIf Level = 91 Then
		Return "10400000";
	EndIf;
	
	// The rest - consider it a landmark.
	Return "Location";
EndFunction

// Returns Xpath for an additional object of the default addressing.
//
//  Parameters;
//      Level - Number - object level. 90  - additional (Variants: GSK, SNT, TER), 91 - subordinate, -1 -
//                        Landmark.
//
// Returns:
//      String - XPath
//
Function AddressingAdditionalObjectXPath(Level, AddressPointType = "") Export
	SerializationCode = AdditionalAddressingObjectSerializationCode(Level, AddressPointType);
	Return "AddEMailAddress[TypeAdrEl='" + SerializationCode + "']";
EndFunction


//  Returns Xpath for the number of the addressing additional object.
//
//  Parameters;
//      RowOfValue - String - search type, for example, "House", "Block".
//
// Returns:
//      String - XPath
//
Function XNumberOfAdditionalObjectPathAddressing(RowOfValue) Export
	
	Code = AddressingObjectSerializationCode(RowOfValue);
	If Code = Undefined Then
		Code = StrReplace(RowOfValue, "'", "");
	EndIf;
	
	Return "AddEMailAddress/Number[Type='" + Code + "']";
EndFunction

//  Returns the row with description of type according to the code of address part.
//  Opposite of the AddressingObjectSerializationCode function.
//
// Parameters:
//      Code - String - code
//
// Returns:
//      Number - Type
//
Function ObjectTypeSerializationCode(Code) Export
	For Each Item In TypesOfAddressingAddressesRF() Do
		If Item.Code = Code Then
			Return Item;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

// Returns the names space for operating with XDTO contact information.
//
// Returns:
//      String - namespaces.
//
Function TargetNamespace() Export
	Return "http://www.v8.1c.ru/ssl/contactinfo";
EndFunction

// Returns the form name for editing the type of contact information.
//
// Parameters:
//      InformationKind - EnumRef.ContactInformationTypes, CatalogRef.ContactInformationTypes -
//                      requested type.
//
// Returns:
//      String - full name of the form.
//
Function FormInputNameContactInformation(Val InformationKind) Export
	InformationType = ContactInformationManagementServiceServerCall.TypeKindContactInformation(InformationKind);
	
	AllTypes = "Enum.ContactInformationTypes.";
	If InformationType = PredefinedValue(AllTypes + "Address") Then
		Return "DataProcessor.ContactInformationInput.Form.AddressInput";
		
	ElsIf InformationType = PredefinedValue(AllTypes + "Phone") Then
		Return "DataProcessor.ContactInformationInput.Form.PhoneInput";
		
	ElsIf InformationType = PredefinedValue(AllTypes + "Fax") Then
		Return "DataProcessor.ContactInformationInput.Form.PhoneInput";
		
	EndIf;
	
	Return Undefined;
EndFunction

// Returns the array of names options by type (according to ownership, construction etc).
//
// Parameters:
//      Type                  - Number  - requested type.
//      AllowReplaysCode - Boolean - True - all variants with repetitions will be returned ("apartment" - ap.etc).
//
// Returns:
//      Array - contains structures - description.
//
Function NamesOfObjectsByTypeAddressing(Type, AllowReplaysCode = True) Export
	Result = New Array;
	Replays   = New Map;
	
	For Each Item In TypesOfAddressingAddressesRF() Do
		If Item.Type = Type Then
			If AllowReplaysCode Then
				Result.Add(Item.Description);
			Else
				If Replays.Get(Item.Code) = Undefined Then
					Result.Add(Item.Description);
				EndIf;
				Replays.Insert(Item.Code, True);
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction    

//  Returns the array of structures with information about the parts of address according to the order of FTS IIM-7-1/525 dated 31.08.2011.
//
// Returns:
//      Array - contains structures - description.
//
Function TypesOfAddressingAddressesRF() Export
	
	Result = New Array;
	
	// Code, Name, Type, Order,
	// FIASCode Type: 1 - ownership, 2 - building, 3 - units.
	
	Result.Add(ObjectStringAddress("1010", NStr("en='House';ru='дом'"),          1, 1, 2));
	Result.Add(ObjectStringAddress("1020", NStr("en='Ownership';ru='Владение'"),     1, 2, 1));
	Result.Add(ObjectStringAddress("1030", NStr("en='Home-ownership';ru='Домовладение'"), 1, 3, 3));
	
	Result.Add(ObjectStringAddress("1050", NStr("en='Block';ru='блок'"),     2, 1));
	Result.Add(ObjectStringAddress("1060", NStr("en='Construction';ru='строительство'"),   2, 2, 1));
	Result.Add(ObjectStringAddress("1080", NStr("en='Email';ru='Письмо'"),     2, 3, 3));
	Result.Add(ObjectStringAddress("1070", NStr("en='Construction';ru='Сооружение'"), 2, 4, 2));
	Result.Add(ObjectStringAddress("1040", NStr("en='Land lot';ru='Участок'"),    2, 5));
	
	Result.Add(ObjectStringAddress("2010", NStr("en='Apartment';ru='Квартира'"),  3, 1));
	Result.Add(ObjectStringAddress("2030", NStr("en='Office';ru='офис'"),      3, 2));
	Result.Add(ObjectStringAddress("2040", NStr("en='Box';ru='коробка'"),      3, 3));
	Result.Add(ObjectStringAddress("2020", NStr("en='Unit';ru='Единица
		|измерения'"), 3, 4));
	Result.Add(ObjectStringAddress("2050", NStr("en='Room';ru='Комната'"),   3, 5));
	//  Our abbreviations for supporting the backward match during parsing.
	Result.Add(ObjectStringAddress("2010", NStr("en='application.';ru='приложение.'"),       3, 6));
	Result.Add(ObjectStringAddress("2030", NStr("en='f';ru='ж'"),       3, 7));
	
	// Adjusting objects
	Result.Add(ObjectStringAddress("10100000", NStr("en='Zip code';ru='Почтовый индекс'")));
	Result.Add(ObjectStringAddress("10200000", NStr("en='Address point';ru='Адресная точка'")));
	Result.Add(ObjectStringAddress("10300000", NStr("en=""Gardeners' partnership"";ru='Садовое товарищество'")));
	Result.Add(ObjectStringAddress("10400000", NStr("en='Item of street-road network, planning structure of additional address element';ru='Элемент улично-дорожной сети, планировочной структуры дополнительного адресного элемента'")));
	Result.Add(ObjectStringAddress("10500000", NStr("en='Industrial area';ru='Промышленная зона'")));
	Result.Add(ObjectStringAddress("10600000", NStr("en='Garage construction co-operative';ru='Гаражно-строительный кооператив'")));
	Result.Add(ObjectStringAddress("10700000", NStr("en='TERRITORY';ru='ТЕРРИТОРИЯ'")));
	
	Return Result;
EndFunction

Function ObjectStringAddress(Code, Description, Type = 0, Order = 0, CodeOfFIAS = 0)
	Return New Structure("Code, Description, Type, Order, FIASCode, Abbreviation, Key",
		Code, Description, Type, Order, CodeOfFIAS, Lower(Description), Upper(Description));
EndFunction

#EndRegion
