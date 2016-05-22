#Region ServiceProceduresAndFunctions

// Method Ping (http://www.v8.1c.en/ssl/AddressSystem)
//
// Parameters:
//     Locale - String - code of the language in which the result and error messages are expected.
//
Function Ping(Locale, ConfigurationName)
	
	Data = New Structure("Data");
	AddressClassifierService.FillDataVendorVersionExt(Data);
	
	Return Data.Data;
EndFunction

// Method GetActualInfo (http://www.v8.1c.en/ssl/AddressSystem)
// 
// Parameters:
//     ID     - UUID (http://www.v8.1c.en/ssl/AddressSystem) - Identifier of the requested address object.
//     Locale - String - code of the language in which the result and error messages are expected.
// 
// Returns:
//     RFAddress (http://www.v8.1c.ru/ssl/contactinfo) - XML of RF address.
//
Function GetActualInfo(ID, Locale, ConfigurationName)
	
	DataProcessorStructure = New Structure("Data");
	AddressClassifierService.FillRelevantAddressInformationExt(DataProcessorStructure, ID);
	
	Return DataProcessorStructure.Data;
EndFunction

// Method GetExtraInfo (http://www.v8.1c.en/ssl/AddressSystem)
// 
// Parameters:
//     ID     - UUID (http://www.v8.1c.en/ssl/AddressSystem) - Identifier of the requested address object.
//     Locale - String - code of the language in which the result and error messages are expected.
// 
// Returns:
//     ExtraInfo (http://www.v8.1c.en/ssl/AddressSystem)
//
Function GetExtraInfo(ID, Locale, ConfigurationName)
	
	DataProcessorStructure = New Structure("Data", AddressClassifierService.AdditionalAddressInformationStructure() );
	AddressClassifierService.FillAdditionalAddressInformationExt(DataProcessorStructure, ID);
	
	Result = XDTOFactory.Create( AddressClassifierService.TargetNamespace(), "ExtraInfo");
	Data = DataProcessorStructure.Data;
	
	Result.OKATO      = Data.OKATO;
	Result.OKTMO      = Data.OKTMO;
	Result.IFTSFL     = Data.IFTSIndividualCode;
	Result.IFTSUL     = Data.IFTSLegalEntityCode;
	Result.TERRIFTSFL = Data.IFTSIndividualDepartmentCode;
	Result.TERRIFTSUL = Data.IFTSLegalEntityDepartmentCode;
	
	Return Result;
EndFunction

// Method Autocomplete (http://www.v8.1c.en/ssl/AddressSystem)
//
// You can search by full matches (including abbreviations) as well as partial matches.
//
// Parameters:
//     Parent - UUID (http://www.v8.1c.en/ssl/AddressSystem) - Identifier of parent object, can be empty.
//     Text   - String - Text typed by user.
//     Levels - Levels (http://www.v8.1c.en/ssl/AddressSystem) - List of used levels.
//     Limit  - Number  - Limitation of returned portion size.
//     Locale - String - code of the language in which the result and error messages are expected.
//
// Returns:
//     PresentationList (http://www.v8.1c.en/ssl/AddressSystem)  - list of options.
//
Function Autocomplete(Parent, Levels, Text, Limit, Locale, ConfigurationName)
	
	DataProcessorStructure = New Structure("Data", AddressClassifierService.AutoPickDataTable() );
	
	AdditionalParameters = New Structure;
	AddressClassifierService.FillAddressPartAutoPickListExt(DataProcessorStructure, Text, Parent, Levels, AdditionalParameters);

	Result = PresentationsList(DataProcessorStructure.Data, Undefined, Undefined, Undefined, Undefined);
	
	Return Result;
EndFunction

// Method Select (http://www.v8.1c.en/ssl/AddressSystem)
//
// Parameters:
//     Parent - UUID (http://www.v8.1c.en/ssl/AddressSystem) - Identifier of parent object, can be empty.
//     Level  - Number  - Required level of classifier.
//     Base   - UUID (http://www.v8.1c.en/ssl/AddressSystem) - Identifier of the object from
//              which data portion starts, the object itself should not be included into the selection.
//     Sort   - SortDirection (http://www.v8.1c.en/ssl/AddressSystem) 
//            - String - Mode. Defines sorting order by name.
//     Limit  - Number - Size of returned portions.
//     Locale - String - code of the language in which the result and error messages are expected.
//
// Returns:
//     PresentationList (http://www.v8.1c.en/ssl/AddressSystem) - list of options.
//
Function Select(Parent, Level, Base, Sort, Limit, Locale, ConfigurationName)
	
	DataProcessorStructure = New Structure("Data", AddressClassifierService.DataTableForInteractiveSelection() );
	
	AdditionalParameters = New Structure;
	Levels                  = AddressClassifierReUse.FIASClassifierLevels();
	
	AddressClassifierService.FillAddressesForInteractiveSelectionExt(DataProcessorStructure, Levels, Parent, Level, AdditionalParameters);	
	
	// Only the portion of right size.
	Result = PresentationsList(DataProcessorStructure.Data, Undefined, Base, Sort, Limit);
	
	Return Result;
EndFunction

// Method SelectByPostalCode (http://www.v8.1c.en/ssl/AddressSystem)
//
// Parameters:
//     PostalCode - Number - Postal code.
//     Levels     - Levels (http://www.v8.1c.en/ssl/AddressSystem) - List of used levels.
//     Base       - UUID (http://www.v8.1c.en/ssl/AddressSystem) - Identifier of the object
//                  with which data portion begins.
//     Sort       - SortDirection (http://www.v8.1c.en/ssl/AddressSystem) 
//                - String - Mode. Defines sorting order by name, the object itself should not
//                be included into selection.
//     Limit      - Number - Size of returned portions.
//     Locale     - String - code of the language in which the result and error messages are expected.
//
// Returns:
//     PresentationList (http://www.v8.1c.en/ssl/AddressSystem) - list of options.
//
Function SelectByPostalCode(PostalCode, Levels, Base, Sort, Limit, Locale, ConfigurationName)
	
	DataProcessorStructure = New Structure("Data, PresentationCommonPart", AddressClassifierService.DataTableForSelectionByPostalCode() );
	
	AdditionalParameters = New Structure;
	
	AddressClassifierService.FillAddressesByClassifierPostalCodeExt(DataProcessorStructure, PostalCode, Levels, AdditionalParameters);
	
	// Only the portion of right size.
	Result = PresentationsList(DataProcessorStructure.Data, DataProcessorStructure.CommonPartPresentation, Base, Sort, Limit);
	
	Return Result;
EndFunction

// Method Analyze (http://www.v8.1c.en/ssl/AddressSystem)
//
// Parameters:
//     Values - AddressList (http://www.v8.1c.en/ssl/AddressSystem) - list of addresses and levels for check.
//     Locale - String - localization code for error messages.
//
// Returns:
//     AddressAnalysisResult (http://www.v8.1c.en/ssl/AddressSystem) - analysis result.
//
Function Analyze(Values, Locale, CheckAsKladr, ConfigurationName)
	
	DataProcessorStructure = New Structure("Data", New Array);
	
	AddressForChecking = New Array;
	For Each CheckAddress IN Values.GetList("Item") Do
		AddressForChecking.Add(New Structure("Address, Levels", CheckAddress.Address, CheckAddress.Levels));
	EndDo;
	
	AddressClassifierService.FillAddressCheckResultByClassifierInter(DataProcessorStructure, AddressForChecking);
	
	Result = XDTOFactory.Create( XDTOFactory.Type(AddressClassifierService.TargetNamespace(), "AddressAnalysisResult"));
	CheckPointType = Result.Properties().Get("Item").Type;
	TypeAddressError  = CheckPointType.Properties.Get("Error").Type;
	AddressTypeVariant = CheckPointType.Properties.Get("Variant").Type;
	
	For Each CheckResult IN DataProcessorStructure.Data Do
		CheckingItem =  Result.Item.Add( XDTOFactory.Create(CheckPointType));
	
		For Each Error IN CheckResult.Errors Do
			AddressError = CheckingItem.Error.Add(XDTOFactory.Create(TypeAddressError));
			AddressError.Key        = Error.Key;
			AddressError.Text       = Error.Text;
			AddressError.Suggestion = Error.ToolTip;
		EndDo;
		
		For Each Variant IN CheckResult.Variants Do
			AddressError = CheckingItem.Variant.Add(XDTOFactory.Create(AddressTypeVariant));
			AddressError.ID         = Error.ID;
			AddressError.PostalCode = Error.IndexOf;
			AddressError.KLADRCode  = Error.ARCACode;
		EndDo;
	EndDo;
	
	Return Result;
EndFunction

// Generates Presentation List by tabular section.
//
Function PresentationsList(Table, Title, MainItem, Direction, PortionSize)
	
	TypeList   = XDTOFactory.Type( AddressClassifierService.TargetNamespace(), "PresentationList");
	Result   = XDTOFactory.Create(TypeList);
	List      = Result.GetList("Item");
	PointType = List.OwningProperty.Type;
	
	StringsTotalNumber = Table.Count();
	
	If Direction = "DESC" Then
		Step    = -1;
		Limit = -1;
	Else
		Step    = 1;
		Limit = StringsTotalNumber;
	EndIf;
	
	IndexOf = 0;
	If ValueIsFilled(MainItem) Then
		StringMain = Table.Find(New UUID(MainItem), "ID");
		If StringMain <> Undefined Then
			IndexOf = Table.IndexOf(StringMain) + Step;
		EndIf;
	EndIf;
	
	Portion = ?(ValueIsFilled(PortionSize), PortionSize, StringsTotalNumber);
	
	While IndexOf <> Limit Do
		TableRow = Table[IndexOf];
		
		Item = XDTOFactory.Create(PointType);
		Item.ID           = TableRow.ID;
		Item.Presentation = TableRow.Presentation;
		List.Add(Item);
		
		IndexOf = IndexOf + Step;
		
		Portion = Portion - 1;
		If Portion = 0 Then
			Break;
		EndIf;
		
	EndDo;
	
	If Title <> Undefined Then
		Result.Title = Title;
	EndIf;
	
	Return Result;
EndFunction

#EndRegion
