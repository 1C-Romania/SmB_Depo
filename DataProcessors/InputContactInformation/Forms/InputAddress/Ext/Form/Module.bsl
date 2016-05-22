// Form is parameterized:
//
//      Title     - String  - form title.
//      FieldsValues - String  - serialized value of the contact details or
//  empty string to enter a new one.
//      Presentation - String  - address presentation (used only when working with old data).
//      ContactInformationKind - CatalogRef.ContactInformationTypes, Structure - description
//                                of what we are editing.
//      Comment  - String   - optional comment for substitution in the "Comment" field.
//
//      ReturnValueList - Boolean - optional flag showing that the return value of a field.
//                                 ContactInformation will have ValueList type (compatibility).
//
//  Selection result:
//      Structure - fields:
//          * ContactInformation   - String - Contact information XML.
//          * Presentation          - String - Presentation.
//          * Comment            - String - Comment.
//          * EnteredInFreeForm - Boolean - input flag.
//

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("OpenByScenario") Then
		Raise NStr("en = 'Data processor is not aimed for being used directly'");
	EndIf;
	
	// Form settings
	NewAddress = ?(ValueIsFilled(Parameters.FieldsValues), False, True);
	ThisWebService = ContactInformationManagementService.ClassifierAvailableThroughWebService();
	CanImportClassifier = ContactInformationManagementService.IsAbilityToChangesOfAddressClassifier() AND Not ThisWebService;
	ThereIsClassifier = ContactInformationManagementServiceReUse.AddressClassifierAvailable();
	
	SetPossibilityToSelectByCode(ThisWebService);
	
	Parameters.Property("ReturnValueList", ReturnValueList);
	// Internal initializing
	BackgroundColorFieldsManager = StyleColors.ManagingFieldBackgroundColor;
	FormBackColor            = StyleColors.FormBackColor;
	AutoColor                 = New Color;
	
	RussiaCountry = Catalogs.WorldCountries.Russia;
	
	ContactInformationKind = ContactInformationManagementService.StructureTypeContactInformation(Parameters.ContactInformationKind);
	If ContactInformationKind.CheckByFIAS Then
		Commands.CheckAddressFilling.ToolTip = NStr("en = 'Check the address filling in FIAS format'");
	Else
		Commands.CheckAddressFilling.ToolTip  = NStr("en = 'Check the address filling in CLADR format'");
	EndIf;
	ContactInformationKind.Insert("Ref", Parameters.ContactInformationKind);
	
	// We always use FIAS sections.
	ContactInformationKind.Insert("AddressFormat", "FIAS");
	
	// Title
	If IsBlankString(Parameters.Title) Then
		If TypeOf(ContactInformationKind) = Type("CatalogRef.ContactInformationTypes") Then
			Title = String(ContactInformationKind);
			// Otherwise the header specified in the form is left.
		EndIf;
	Else
		Title = Parameters.Title;
	EndIf;
	
	HideObsoleteAddresses  = ContactInformationKind.HideObsoleteAddresses;
	
	AddressRussianOnly       = ContactInformationKind.AddressRussianOnly;
	ContactInformationType     = ContactInformationKind.Type;
	
	// Possible variants of the house, building, apartment.
	SetItemsChoiceList(Items.HouseType,      Items.House,       ContactInformationManagementService.VariantsDataHouse());
	SetItemsChoiceList(Items.ConstructionType,  Items.Construction,  ContactInformationManagementService.VariantsDataConstruction());
	SetItemsChoiceList(Items.UnitType, Items.Unit, ContactInformationManagementService.VariantsOfDataPlace());
	
	// Try to fill from parameters.
	If ContactInformationManagementClientServer.IsContactInformationInXML(Parameters.FieldsValues) 
		AND ContactInformationType = Enums.ContactInformationTypes.Address
	Then
		ReadingResults = New Structure;
		XDTOContact = ContactInformationManagementService.ContactInformationFromXML(Parameters.FieldsValues, ContactInformationType, ReadingResults);
		If ReadingResults.Property("ErrorText") Then
			// Recognized with errors, will notify on opening.
			WarningTextOnOpen = ReadingResults.ErrorText;
			XDTOContact.Presentation = Parameters.Presentation;
			XDTOContact.Content.Country = String(RussiaCountry);
		EndIf;
	Else
		XDTOContact = ContactInformationManagementService.XMLBXDTOAddress(Parameters.FieldsValues, Parameters.Presentation, );
	EndIf;
	
	If Parameters.Comment <> Undefined Then
		// Leave a new comment otherwise we take it from the information.
		XDTOContact.Comment = Parameters.Comment;
	EndIf;
	
	If Not NewAddress Then 
		ValueofAttributesByContactInformation(ThisObject, XDTOContact);
	Else
		SettlementInDetail = ContactInformationManagementClientServer.LocalityAddressPartsStructure(ContactInformationKind.AddressFormat);
	EndIf;
	
	If ValueIsFilled(Country) Then
		// Find in the catalog of countries
		OriginalCountryPresentation = "";
	ElsIf IsBlankString(CountryCode) Then
		// We find it in the classifier but did not find in the catalog. It is necessary to add?
		OriginalCountryPresentation = TrimAll(XDTOContact.Content.Country);
	Else
		// We did not find it neither in the classifier nor in the catalog.
		OriginalCountryPresentation = TrimAll(XDTOContact.Content.Country);
	EndIf;
		
	DrawAdditionalBuildingsAndFacilities();
	
	// Empty values are possible in order not to confuse.
	If IsBlankString(House) AND IsBlankString(HouseType) Then
		HouseType = ContactInformationManagementClientServer.FirstOrEmpty(Items.HouseType);
	EndIf;
	If IsBlankString(Construction) AND IsBlankString(ConstructionType) Then
		ConstructionType = ContactInformationManagementClientServer.FirstOrEmpty(Items.ConstructionType);
	EndIf;
	If IsBlankString(Unit) AND IsBlankString(UnitType) Then
		UnitType = ContactInformationManagementClientServer.FirstOrEmpty(Items.UnitType);
	EndIf;
	
	// Check the correctness
	If AddressRussianOnly  Then
		Items.Country.Enabled = False;
		Items.Country.BackColor = AutoColor;
		If Country <> RussiaCountry AND Not NewAddress Then
			// We consider the address is Russian
			AddressPresentationTest = TrimAll(TrimAll(Country) + " " + TrimAll(ForeignAddressPresentation));
			If Not IsBlankString(AddressPresentationTest) Then
				AddressPresentation = AddressPresentationTest;
				AllowInputAddressInFreeForm = True;
				AddressPresentationChanged = True;
			EndIf;
			WarningTextOnOpen = NStr("en = 'Address is entered incorrectly: you can enter only Russian addresses. Country field value was changed to Russia, it is necessary to check other fields.'"); 
			Country = RussiaCountry;
			Modified = True;
		EndIf;
	EndIf;
	
	If ValueIsFilled(Country) Then
		CountryCode = Country.Code;
	ElsIf IsBlankString(OriginalCountryPresentation) Then
		Country    = RussiaCountry;
		CountryCode = RussiaCountry.Code;
	Else 
		// The country is not specified but it is not Russia exactly.
		If IsBlankString(WarningTextOnOpen) Then
			FieldWarningsOnOpen = "Country";
		EndIf;
		WarningTextOnOpen = WarningTextOnOpen
			+ StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='%1 country is not in the catalog of the world countries.'"), OriginalCountryPresentation);
	EndIf;
			
	// Initialize all items
	If Country = RussiaCountry Then
		Items.AddressType.CurrentPage = Items.RussianAddress;
		CurrentItem = Items.Settlement;
	Else
		Items.AddressType.CurrentPage = Items.ForeignAddress;
		CurrentItem = Items.ForeignAddressPresentation;
		CanImportClassifier = False;
	EndIf;
	
	Items.ImportClassifier.Visible            = CanImportClassifier;
	Items.ImportClassifierAllActions.Visible = CanImportClassifier;
	
	If Not ThereIsClassifier Then
		Items.FillByZipCode.Visible            = False;
		Items.FillByZipCodeAllActions.Visible = False;
	EndIf;
	
	// We display the presentation by default.
	Items.AddressPresentationComment.CurrentPage = Items.AddressPagePresentation;
	
	// Command group "all activity" depends on the interface.
	ThisTaxi = ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Taxi;
	If ThisTaxi Then
		Items.FormAllActions.Visible = False;
	Else
		Items.EnterAddressInFreeForm.Visible  = False;
		Items.FillByZipCode.Visible = False;
		Items.FormClearAddress.Visible          = False;
		Items.ImportClassifier.Visible      = False;
		Items.ChangeForm.Visible               = False;
	EndIf;
	
	ClassifierAvailability = Undefined;
	
	If Not ThisWebService Then
		// Russian address
		If XDTOContact.Content.Content <> Undefined AND TypeOf(XDTOContact.Content.Content) <> Type("String") Then
			If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
				ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
				InformationAboutState = ModuleAddressClassifierService.InformationAboutState(XDTOContact.Content.Content.RFTerritorialEntity);
				If InformationAboutState.Imported = False Then
					ClassifierAvailability = New Structure("Cancel, BriefErrorDescription");
					ClassifierAvailability.Cancel = True;
					ClassifierAvailability.BriefErrorDescription = StringFunctionsClientServer.PlaceParametersIntoString(
						NStr("en = 'You should export the address information for the %1 state (in the %2 menu).'"), 
						XDTOContact.Content.Content.RFTerritorialEntity,
						?(ThisTaxi, NStr("en = 'More'"), NStr("en = 'All actions'")));
					Items.AuthorizationOnUsersSupportSite.Visible = False;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	CheckClassifierAvailability(ClassifierAvailability);
	SetKeyUseForms();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetCommentIcon();
	Items.AddObject.Enabled = CanAddAdditionalObjects();
	
	DataProcessorCountriesChangesClient();
	StateInputPresentationAddresses(AllowInputAddressInFreeForm, False);
	
	If Not IsBlankString(AddressClassifierEnabled) Or Not IsBlankString(WarningTextOnOpen) Then
		AttachIdleHandler("Attachable_CheckJobExecution", 0.5, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	Notification = New NotifyDescription("ConfirmAndClose", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "AddressClassifierIsUpdated" OR EventName = "AddressClassifierIsImported" Then
		If ThereIsClassifier AND InformationAboutState(SettlementInDetail.State.Presentation).Imported = True Then
			Items.GroupServerIsUnavailableDetails.CurrentPage = Items.ServiceAvailable;
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure CountryOnChange(Item)
	DataProcessorCountriesChangesClient();
	
	Context = ContextFormClient();
	FillAddressPresentation(Context);
	ContextFormClient(Context);
	
#If WebClient Then
	// Crawl the platform feature.
	Item.UpdateEditText();
#EndIf

	// Always display presentation.
	Items.AddressPresentationComment.CurrentPage = Items.AddressPagePresentation;
EndProcedure

&AtClient
Procedure CountryClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure CountryAutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	If Wait = 0 Then
		// Creation of the shortcut selection list.
		If IsBlankString(Text) Then
			ChoiceData = New ValueList;
		EndIf;
		Return;
	EndIf;

EndProcedure

&AtClient
Procedure CountryTextInputEnd(Item, Text, ChoiceData, StandardProcessing)
	
	If IsBlankString(Text) Then
		StandardProcessing = False;
	EndIf;
	
#If WebClient Then
	// Crawl the platform feature.
	StandardProcessing = False;
	ChoiceData         = New ValueList;
	ChoiceData.Add(Country);
#EndIf

EndProcedure

&AtClient
Procedure CountryChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	ContactInformationManagementClient.WorldCountryChoiceProcessing(Item, ValueSelected, StandardProcessing);
	
EndProcedure

&AtClient
Procedure EditTextchangingIndex(Item, Text, StandardProcessing)
	
	StandardProcessing = False;
	CurrentIndex = Format(Text, "ND=6; NGS=' '; NZ=; NG=0");
	If StrLen(TrimAll(CurrentIndex)) = 6 AND IndexOf <> Text Then
		Context = ContextFormClient();
		IndexOf = CurrentIndex;
		If ThereIsClassifier Then
			FormParameters = New Structure;
			FormParameters.Insert("IndexOf", CurrentIndex);
			FormParameters.Insert("HideObsoleteAddresses", HideObsoleteAddresses);
			FormParameters.Insert("AddressFormat", ContactInformationKind.AddressFormat);
			
			OpenForm("DataProcessor.InputContactInformation.Form.SelectionAddressesByPostcode", FormParameters, Items.IndexOf);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure IndexChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	If ValueSelected = Undefined Then 
		Return;
	ElsIf ValueSelected.Cancel Then
		If ValueSelected.Property("IndexOf") AND Not IsBlankString(ValueSelected.IndexOf) 
				AND PickByIndexAvailable Then
			Notification = New NotifyDescription("AfterQueryClassifierUpdate", ThisObject);
			QuestionText = NStr("en = 'The %1 code is not found in the address classifier. Possible errors:'") + Chars.LF;
			QuestionText = QuestionText + NStr("en = '  - the code is applied to the state where the address information is absent in the application;'") + Chars.LF;
			QuestionText = QuestionText + NStr("en = '  - address information loaded into the application are obsolete;'") + Chars.LF;
			QuestionText = QuestionText + NStr("en = '  - the code is entered incorrectly.'");
			QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(QuestionText, Format(ValueSelected.IndexOf, "NGS=' '; NG=0"));
			Buttons = New ValueList;
			Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Update the classifier'"));
			Buttons.Add(DialogReturnCode.Cancel, NStr("en = 'Cancel'"));
			ShowQueryBox(Notification, QuestionText, Buttons);
		Else
			If Not PickByIndexAvailable Then
				MessageText = NStr("en = 'The code %1 is not found in the address classifier'");
				MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, Format(ValueSelected.IndexOf, "NGS=' '; NG=0"));
				CommonUseClientServer.MessageToUser(MessageText,,, "Object.IndexOf");
			Else
				CheckClassifierAvailability(ValueSelected);
			EndIf;
		EndIf;
		Return;
	EndIf;
	
	Context = ContextFormClient();
	FillAddressByCodeData(Context, ValueSelected);
	ContextFormClient(Context);
	Modified = True;
	CurrentItem = Items.House;
	
EndProcedure

&AtClient
Procedure AfterQueryClassifierUpdate(Result, Parameter) Export
	If Result = DialogReturnCode.Yes Then
		If CommonUseClient.SubsystemExists("StandardSubsystems.AddressClassifier") Then
			ModuleAddressClassifierClient = CommonUseClient.CommonModule("AddressClassifierClient");
			ModuleAddressClassifierClient.ImportAddressClassifier();
		EndIf;
	EndIf;
EndProcedure

&AtServer
Procedure FillAddressByCodeData(Context, Val IndexData)
	
	ClearAddressServer(Context);
	
	XDTOContactInfo = ContactInformationForAttributesValue(Context);
	
	// We assume the address is still not Russian.
	XDTOAddress = XDTOContactInfo.Content.Content;
	
	ContactInformationManagementService.PostalIndexOfAddresses(XDTOAddress, IndexData.IndexOf);
	ContactInformationManagementService.SetAddressLocalityOnIdidentifier(XDTOAddress, IndexData.Identifier);
	ContactInformationManagementService.SetAddressStreetByIdentifier(XDTOAddress, IndexData.Identifier);
	
	ValueofAttributesByContactInformation(Context, XDTOContactInfo);
	FillAddressPresentation(Context);
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	SetCommentIcon();
	
EndProcedure

&AtClient
Procedure HouseTypeOnChange(Item)
	
	Context = ContextFormClient();
	FillAddressPresentation(Context);
	ContextFormClient(Context);
	
EndProcedure

&AtClient
Procedure HouseOnChange(Item)
	
	Context = ContextFormClient();
	UpdateIndexAndPresentation(Context);
	ContextFormClient(Context);

EndProcedure

&AtClient
Procedure StructureTypeOnChange(Item)
	
	Context = ContextFormClient();
	FillAddressPresentation(Context);
	ContextFormClient(Context);
	
EndProcedure

&AtClient
Procedure ConstructionOnChange(Item)
	Context = ContextFormClient();
	UpdateIndexAndPresentation(Context);
	ContextFormClient(Context);
EndProcedure

&AtClient
Procedure UnitTypeOnChange(Item)
	
	Context = ContextFormClient();
	FillAddressPresentation(Context);
	ContextFormClient(Context);
	
EndProcedure

&AtClient
Procedure UnitOnChange(Item)
	
	Context = ContextFormClient();
	FillAddressPresentation(Context);
	ContextFormClient(Context);
	
EndProcedure

&AtClient
Procedure SettlementOnChange(Item)
	
	Context = ContextFormClient();
	DataProcessorChangesLocationServer(Context);
	ContextFormClient(Context);
	
EndProcedure

&AtClient
Procedure SettlementStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	// If it comes directly after editing, we reset the address.
	If Item.EditText <> Settlement Then
		Modified = True;
		Settlement    = Item.EditText;
		
		SettlementIdentifier = Undefined;
		
		Context = ContextFormClient();
		DataProcessorChangesLocationServer(Context, True);
		ContextFormClient(Context);
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("SettlementInDetail", SettlementInDetail);
	FormParameters.Insert("SettlementIdentifier", SettlementIdentifier);
	FormParameters.Insert("HideObsoleteAddresses", HideObsoleteAddresses);
	FormParameters.Insert("AddressFormat", ContactInformationKind.AddressFormat);
	OpenForm("DataProcessor.InputContactInformation.Form.SettlementAddress", FormParameters, Item, , , , , FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure SettlementChoiceProcessing(Item, ValueSelected, StandardProcessing)
	Var CanImportState;
	
	StandardProcessing = False;
	If ValueSelected=Undefined Then
		Return;
	EndIf;
	Modified = True;
	ValueType = TypeOf(ValueSelected);
	FormInDetail = True;
	
	If ValueType = Type("Structure") Then
		
		If ValueSelected.Presentation <> Settlement Then
			StreetIdentifier = Undefined;
		EndIf;
		
		// Autofit result or button selection result, we take all from there.
		SettlementIdentifier = ValueSelected.ID;
		Settlement                = ValueSelected.Presentation;
		
		If ValueSelected.Property("SettlementInDetail") Then
			// Selection from the detailed entry form.
			SettlementInDetail = ValueSelected.SettlementInDetail;
			FormInDetail = False;
		Else 
			If SettlementInDetail <> Undefined Then
				NewSettlementDataDetails = SettlementInDetailByIdentifier(SettlementIdentifier, ContactInformationKind.AddressFormat);
				For Each PartAddresses In NewSettlementDataDetails Do
					If PartAddresses.Value.Level < 7 Then
						SettlementInDetail[PartAddresses.Key] = PartAddresses.Value;
					EndIf;
				EndDo;
			Else
				SettlementInDetail = SettlementInDetailByIdentifier(SettlementIdentifier, ContactInformationKind.AddressFormat);
			EndIf;
		EndIf;
		
		StateNotImported = ValueSelected.Property("StateImported") AND (Not ValueSelected.StateImported);
		If CanImportClassifier AND StateNotImported Then
			// Offer to import a classifier.
			ContactInformationManagementClient.OfferExportClassifier(
				StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='Data for ""%1"" is not imported.'"), ValueSelected.Presentation), 
				ValueSelected.Presentation);
		EndIf;
		
	Else
		// Other source, an attempt to parse will be provided.
		SettlementIdentifier = Undefined;
	 	Settlement = String(ValueSelected);
	EndIf;
	
	Context = ContextFormClient();
	// Since the settlement is changed, recheck the street, the code and the presentation are updated there.
	DataProcessorChangesStreetsServer(Context);
	ContextFormClient(Context);
	
EndProcedure

&AtClient
Procedure SettlementAutoSelection(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	ChoiceData = New ValueList;
	If Wait = 0 Then
		// Creation of list for fast selection, standard processing is not used.
		Return;
	ElsIf ServiceUnavailability() Then
		Return;
	EndIf;
	
	TextForAutoSelection = TrimAll(Text);
	Items.Settlement.BackColor = AutoColor;
	If StrLen(TextForAutoSelection) < 3 Then
		// No options, the list is empty, standard processing must not be used.
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("AddressFormat", ContactInformationKind.AddressFormat);
	AdditionalParameters.Insert("HideObsolete",              HideObsoleteAddresses);
	
	ClassifierData = LocalityAutofitList(TextForAutoSelection, AdditionalParameters);
	CheckClassifierAvailability(ClassifierData);
	If ClassifierData.Cancel Then
		Return;
	EndIf;
	
	ChoiceData = ClassifierData.Data;
	// Standard processing is off, only if there are own options.
	If ChoiceData.Count() > 0 Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettlementTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	// Exit from the field with the text changed manually.
	
	Modified = True;

	ChoiceData = New ValueList;
	ChoiceData.Add(Text);
	
	// The settlement becomes inadequate.
	SettlementIdentifier = Undefined;
	Settlement                = Text;
	
	// The street becomes inadequate.
	StreetIdentifier = Undefined;
	
	#If WebClient Then
		// Crawl the platform feature.
		Context = ContextFormClient();
		DataProcessorChangesLocationServer(Context);
		ContextFormClient(Context);
	#EndIf
	
EndProcedure

&AtClient
Procedure StreetStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	// If it comes directly after editing, then reset.
	If Item.EditText <> Street Then
		Street = Item.EditText;
	EndIf;
	
	If ValueIsFilled(SettlementIdentifier) Then
		FormParameters = New Structure("HideObsoleteAddresses, SettlementIdentifier, Street", 
			HideObsoleteAddresses, SettlementIdentifier, Street);
	Else
		// Street parent is not defined, open the form that is empty.
		FormParameters = New Structure("HideObsoleteAddresses, SettlementIdentifier, Street, Title", 
			HideObsoleteAddresses, -1, Street, Settlement + " " + NStr("en = '(not found)'"));
	EndIf;
	
	FormParameters.Insert("AddressFormat", ContactInformationKind.AddressFormat);
	
	ContactInformationManagementClient.StartChoiceStreet(Item, SettlementIdentifier, Street, FormParameters);
EndProcedure

&AtClient
Procedure StreetChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If ValueSelected = Undefined Then
		Return;
	EndIf;
	
	If ValueSelected.Property("Cancel") AND ValueSelected.Cancel = True Then
		If Not IsBlankString(ValueSelected.BriefErrorDescription) Then
			ShowMessageBox(, ValueSelected.BriefErrorDescription);
		EndIf;
		Return;
	EndIf;
	
	Modified = True;
	ChoiceType = TypeOf(ValueSelected);
	If ChoiceType = Type("Structure") Then
			// Autofit result or button selection result, we take all from there.
			If ValueIsFilled(ValueSelected.Street) Then 
				SettlementInDetail.Street.Presentation = ValueSelected.Street;
				DescriptionAbbreviation= ContactInformationManagementClientServer.DescriptionAbbreviation(ValueSelected.Street);
				SettlementInDetail.Street.Description = DescriptionAbbreviation.Description;
				SettlementInDetail.Street.Abbr = DescriptionAbbreviation.Abbr;
			EndIf;
			If ValueIsFilled(ValueSelected.AdditionalItem) Then
				SettlementInDetail.AdditionalItem.Presentation = ValueSelected.AdditionalItem;
				DescriptionAbbreviation= ContactInformationManagementClientServer.DescriptionAbbreviation(ValueSelected.AdditionalItem);
				SettlementInDetail.AdditionalItem.Description = DescriptionAbbreviation.Description;
				SettlementInDetail.AdditionalItem.Abbr = DescriptionAbbreviation.Abbr;
			EndIf;
			If ValueIsFilled(ValueSelected.SubordinateItem) Then
				SettlementInDetail.SubordinateItem.Presentation = ValueSelected.SubordinateItem;
				DescriptionAbbreviation= ContactInformationManagementClientServer.DescriptionAbbreviation(ValueSelected.SubordinateItem);
				SettlementInDetail.SubordinateItem.Description = DescriptionAbbreviation.Description;
				SettlementInDetail.SubordinateItem.Abbr = DescriptionAbbreviation.Abbr;
			EndIf;
		Street = ValueSelected.Presentation;
		StreetIdentifier = ValueSelected.Identifier;
	Else
		// Other source, an attempt to parse will be provided.
		StreetIdentifier = Undefined;
	 	Street = String(ValueSelected);
	EndIf;
	
	Context = ContextFormClient();
	DataProcessorChangesStreetsServer(Context);
	ContextFormClient(Context);
	
EndProcedure

&AtClient
Procedure StreetAutoPickup(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	ChoiceData = New ValueList;
	If Wait = 0 Then
		// Creation of list for fast selection, standard processing is not used.
		Return;
	ElsIf ServiceUnavailability() Then
		Return;
	EndIf;
	
	Items.Street.BackColor = AutoColor;
	If StrLen(Text) < 3 Or Not ValueIsFilled(SettlementIdentifier)Then 
		// No options, the list is empty, standard processing must not be used.
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("AddressFormat", ContactInformationKind.AddressFormat);
	AdditionalParameters.Insert("HideObsolete",              HideObsoleteAddresses);
	
	ClassifierData = StreetAutoselectionList(SettlementIdentifier, Text, AdditionalParameters);
	CheckClassifierAvailability(ClassifierData);
	If ClassifierData.Cancel Then
		Return;
	EndIf;
	
	ChoiceData = ClassifierData.Data;
	
	// Standard processing is off, only if there are own options.
	If ChoiceData.Count() > 0 Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure StreetTextInputEnd(Item, Text, ChoiceData, StandardProcessing)
	// Exit from the field with the text changed manually.
	Modified = True;
	
	ChoiceData = New ValueList;
	ChoiceData.Add(Text);
	Street = Text;
	
	// The street becomes unverified.
	StreetIdentifier = Undefined;
	
	Context = ContextFormClient();
	DataProcessorChangesStreetsServer(Context);
	ContextFormClient(Context);

EndProcedure

&AtClient
Procedure AddressPresentationOnChange(Item)
	AddressPresentationChanged = True;
	AddressPresentationOnChangeServer();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandOK(Command)
	
	ConfirmAndClose();
	
EndProcedure

&AtClient
Procedure CommandCancel(Command)
	Modified = False;
	Close();
EndProcedure

&AtClient
Procedure CheckAddressFilling(Command)
	
	If AllowInputAddressInFreeForm Then
		ShowMessageBox(, NStr("en='Address can not be verified because it is entered in the free form.'"));
		Return;
	EndIf;

	WarnAboutMissingErrors = True;
	
	Context = ContextFormClient();
	ErrorList = ErrorListFill(Context, WarnAboutMissingErrors);
	FillErrorMessage(ErrorList, WarnAboutMissingErrors);
	
EndProcedure

&AtClient
Procedure ClearAddress(Command)
	
	ClearAddressClient();
	
EndProcedure

&AtClient
Procedure FillByZipCode(Command)
	
	If ThereIsClassifier AND Not IsBlankString(IndexOf) Then
		FormParameters = New Structure("IndexOf, HideObsoleteAddresses", TrimAll(IndexOf), HideObsoleteAddresses);
		OpenForm("DataProcessor.InputContactInformation.Form.SelectionAddressesByPostcode", FormParameters, Items.IndexOf);
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportClassifier(Command)
	
	InformationAboutState = InformationAboutState(SettlementInDetail.State.Presentation);
	AdditionalParameters = New Structure("StateCodeForImport", InformationAboutState.RFTerritorialEntityCode);
	
	ContactInformationManagementClient.ImportAddressClassifier(AdditionalParameters);
EndProcedure

&AtClient
Procedure AddObject(Command)
	Variants = UnusedItemsAdditionalTables(AdditionalBuildings, Items.ConstructionType, 1);
	For Each ItemObject In UnusedItemsAdditionalTables(AdditionalUnits, Items.UnitType, 2) Do
		FillPropertyValues(Variants.Add(), ItemObject);
	EndDo;
	
	VariantCount = Variants.Count();
	If VariantCount>0 Then
		AdditionalParameters = New Structure("VariantCount", VariantCount);
		Notification = New NotifyDescription("AddObjectEnd", ThisObject, AdditionalParameters);
		ShowChooseFromMenu(Notification, Variants, Items.AddObject);
	EndIf;
EndProcedure

&AtClient
Procedure EnterAddressInFreeForm(Command)
	
	If AllowInputAddressInFreeForm Then
		QuestionText = NStr("en='Changes entered manually will be lost.
		                        |Continue?'");
	Else
		QuestionText = NStr("en='Enter the address in
		                        |a free form? Addresses entered in the free form may fail to pass the verification according to the address classifier.'");
	EndIf;
	
	Notification = New NotifyDescription("EnterAddressInFreeFormEnd", ThisObject);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , , NStr("en='Confirmation'"));
EndProcedure

&AtClient
Procedure AuthorizationOnUsersSupportSite(Command)
	
	ClosingAlert = New NotifyDescription("AuthorizationOnUserSupportSiteEnd", ThisObject);
	StandardSubsystemsClient.AuthorizeOnUserSupportSite(ThisObject, ClosingAlert);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetCommentIcon()
	
	If IsBlankString(Comment) Then
		Items.AddressPageComment.Picture = New Picture;
	Else
		Items.AddressPageComment.Picture = PictureLib.Comment;
	EndIf;
		
EndProcedure

&AtClient
Procedure ConfirmAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	// If unmodified, it works as Cancel.
	
	If Modified Then
		// Address value is changed 
		
		Context = ContextFormClient();
		Result = SelectionResultOfCheckBoxUpdating(Context, ReturnValueList);
		
		// Type flags were read again.
		ContactInformationKind = Context.ContactInformationKind;
		
		If ContactInformationKind.CheckCorrectness AND (Not AllowInputAddressInFreeForm) AND Result.FillingErrors.Count() > 0 Then
			FillErrorMessage(Result.FillingErrors, False);
			If ContactInformationKind.ProhibitEntryOfIncorrect Then
				Return;
			EndIf;
		EndIf;
		
		Result = Result.SelectionData;
		
		DropModifiedOnChoice();
#If WebClient Then
		ClosingFlag = CloseOnChoice;
		CloseOnChoice = False;
		NotifyChoice(Result);
		CloseOnChoice = ClosingFlag;
#Else
		NotifyChoice(Result);
#EndIf
		SaveFormState();
		
	ElsIf Comment <> CopyComment Then
		// Only comment is changed, try to return the updated.
		Result = ChoiceResultOnlyComment(Parameters.FieldsValues, Parameters.Presentation, Comment);
		Result = Result.SelectionData;
		
		DropModifiedOnChoice();
#If WebClient Then
		ClosingFlag = CloseOnChoice;
		CloseOnChoice = False;
		NotifyChoice(Result);
		CloseOnChoice = ClosingFlag;
#Else
		NotifyChoice(Result);
#EndIf
		SaveFormState();
		
	Else
		Result = Undefined;
	EndIf;
	
	If (ModalMode Or CloseOnChoice) AND IsOpen() Then
		DropModifiedOnChoice();
		SaveFormState();
		Close(Result);
	EndIf;

EndProcedure

&AtClient
Procedure SaveFormState()
	SetKeyUseForms();
	SavedInSettingsDataModified = True;
EndProcedure

&AtClient
Procedure AddObjectEnd(Val SelectedItem, Val AdditionalParameters) Export
	If SelectedItem=Undefined Then
		// Refusal to select
		Return;
	EndIf;
	
	If SelectedItem.Value=1 Then
		String = AdditionalBuildings.Add();
		
		String.Type = SelectedItem.Presentation;
		String.PathXPath = ContactInformationManagementClientServerReUse.XNumberOfAdditionalObjectPathAddressing(String.Type);
		NameCurrent = DrawAdditionalBuildings();
	Else
		String = AdditionalUnits.Add();
		
		String.Type = SelectedItem.Presentation;
		String.PathXPath = ContactInformationManagementClientServerReUse.XNumberOfAdditionalObjectPathAddressing(String.Type);
		NameCurrent = DrawAdditionalUnits();
	EndIf;
	
	// Prohibit to add more than existing variants.
	Items.AddObject.Enabled = AdditionalParameters.VariantCount>1;
	
	If NameCurrent<>Undefined Then
		CurrentItem = Items[NameCurrent];
	EndIf;
	
	Modified = True;
EndProcedure

&AtClient
Procedure EnterAddressInFreeFormEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult<>DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	AllowInputAddressInFreeForm = Not AllowInputAddressInFreeForm;
	StateInputPresentationAddresses(AllowInputAddressInFreeForm);
	
	Modified = True;
EndProcedure

&AtClient
Procedure DropModifiedOnChoice()
	Modified = False;
	CopyComment   = Comment;
EndProcedure

&AtClient
Procedure Attachable_CheckJobExecution()
	
	If Not IsBlankString(WarningTextOnOpen) Then
		CommonUseClientServer.MessageToUser(WarningTextOnOpen, , FieldWarningsOnOpen);
		WarningTextOnOpen = "";
	EndIf;
	
	If Not IsBlankString(AddressClassifierEnabled) Then
		If JobCompleted(JobID) Then
			UpdateClassifierAvailability(ThisObject);
		Else	
			AttachIdleHandler("Attachable_CheckJobExecution", 0.5, True);
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	
	If CommonUseClientServer.DebugMode() Then
		JobCompleteSuccessfully = True;
	Else
		JobCompleteSuccessfully = LongActions.JobCompleted(JobID);
	EndIf;
	
	Return JobCompleteSuccessfully;
	
EndFunction

&AtServerNoContext
Function SelectionResultOfCheckBoxUpdating(Context, ReturnValueList = False)
	// Update some flags
	FlagsValue = ContactInformationManagementService.StructureTypeContactInformation(Context.ContactInformationKind.Ref);
	
	Context.ContactInformationKind.AddressRussianOnly      = FlagsValue.AddressRussianOnly;
	Context.ContactInformationKind.ProhibitEntryOfIncorrect = FlagsValue.ProhibitEntryOfIncorrect;
	Context.ContactInformationKind.CheckCorrectness      = FlagsValue.CheckCorrectness;

	Return ChoiceResult(Context, ReturnValueList);
EndFunction

&AtServerNoContext
Function ChoiceResult(Context, ReturnValueList = False)
	XDTOInformation = ContactInformationForAttributesValue(Context);
	Result      = New Structure("SelectionData, FillingErrors");
	
	If ReturnValueList Then
		ChoiceData = ContactInformationManagementService.ContactInformationInOldStructure(XDTOInformation);
		ChoiceData = ChoiceData.FieldsValues;
		
	ElsIf Context.Country = Context.RussiaCountry AND IsBlankString(XDTOInformation.Presentation) Then
		ChoiceData = "";
		
	Else
		ChoiceData = ContactInformationManagementService.ContactInformationXDTOVXML(XDTOInformation);
		
	EndIf;
	
	Result.SelectionData = New Structure("ContactInformation, Presentation, Comment, EnteredInFreeForm",
		ChoiceData,
		XDTOInformation.Presentation,
		XDTOInformation.Comment,
		ContactInformationManagementService.AddressEnteredInFreeForm(XDTOInformation));
	
	Result.FillingErrors = ContactInformationManagementService.AddressFillingErrorsXDTO(
		XDTOInformation.Content,
		Context.ContactInformationKind);
	
	// Suppress the string wrapping in the separately returned presentation.
	Result.SelectionData.Presentation = TrimAll(StrReplace(Result.SelectionData.Presentation, Chars.LF, " "));
	
	Return Result;
EndFunction

&AtServerNoContext
Function ErrorListFill(Context, WarnAboutMissing)
	XDTOInformation = ContactInformationForAttributesValue(Context);
	
	// We receive the value list: XPath - error text.
	Result = ContactInformationManagementService.AddressFillingErrorsXDTO(
		XDTOInformation.Content, Context.ContactInformationKind);
	
	If Result.Count() = 0 // No errors
		AND WarnAboutMissing // But it is necessary to inform of their absence.
		// We additionally check the blank.
		AND (Not ContactInformationManagementService.XDTOContactInformationFilled(XDTOInformation))
	Then
		Result.Add("/", NStr("en = 'Address is empty.'"));
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function ChoiceResultOnlyComment(ContactInfo, Presentation, Comment)
	
	If IsBlankString(ContactInfo) Then
		NewContact = ContactInformationManagementService.XMLBXDTOAddress("");
		NewContact.Comment = Comment;
		NewContact = ContactInformationManagement.XMLContactInformation(NewContact);
		AddressEnteredInFreeForm = False;
		
	ElsIf ContactInformationManagementClientServer.IsContactInformationInXML(ContactInfo) Then
		// copy
		NewContact = ContactInfo;
		// Modify the NewContact value.
		ContactInformationManagement.SetContactInformationComment(NewContact, Comment);
		AddressEnteredInFreeForm = ContactInformationManagementService.AddressEnteredInFreeForm(ContactInfo);
		
	Else
		NewContact = ContactInfo;
		AddressEnteredInFreeForm = False;
	EndIf;
	
	Result = New Structure("SelectionData, FillingErrors", New Structure, New ValueList);
	Result.ChoiceData.Insert("ContactInformation", NewContact);
	Result.ChoiceData.Insert("Presentation", Presentation);
	Result.ChoiceData.Insert("Comment", Comment);
	Result.ChoiceData.Insert("EnteredInFreeForm", AddressEnteredInFreeForm);
	Return Result;
EndFunction

&AtServerNoContext
Procedure DataProcessorChangesLocationServer(Context, ReformationInDetail = True)
	
	If Not ValueIsFilled(Context.SettlementIdentifier) Then
		// Data is entered manually, try to parse the entered string.
		Address = SettlementsOnPresentation(Context.Settlement, Context.HideObsoleteAddresses);
		GenerateDetailedSettlement(Context, Address);
		ReformationInDetail = False;
		ContactInformationManagementService.FillSettlementIdentifiers(Context.SettlementInDetail, Context.SettlementIdentifier);
	EndIf;
	
	// Settlement divided by parts.
	If ReformationInDetail Then
		GenerateDetailedSettlement(Context);
	EndIf;
	
	// Recheck the street, the code and presentation are updated there.
	DataProcessorChangesStreetsServer(Context);

EndProcedure

&AtServerNoContext
Procedure DataProcessorChangesStreetsServer(Context)
	
	// Clear street records
	Context.SettlementInDetail.Street.Presentation = Undefined;
	Context.SettlementInDetail.Street.Identifier = Undefined;
	Context.SettlementInDetail.AdditionalItem.Presentation = Undefined;
	Context.SettlementInDetail.AdditionalItem.Identifier = Undefined;
	Context.SettlementInDetail.SubordinateItem.Presentation = Undefined;
	Context.SettlementInDetail.SubordinateItem.Identifier = Undefined;
	
	// Data is entered manually, try to parse the entered string.
	AnalysisClassifier = StreetsReporting(Context.SettlementIdentifier, Context.Street, Context.HideObsoleteAddresses);
	If AnalysisClassifier <> Undefined Then 
		For Each PartAddresses In AnalysisClassifier Do
			If PartAddresses.Level = 7 Then
				Context.SettlementInDetail.Street.Presentation = PartAddresses.Value;
				Context.SettlementInDetail.Street.Identifier = PartAddresses.Identifier;
			ElsIf PartAddresses.Level = 90 Then
				Context.SettlementInDetail.AdditionalItem.Presentation = PartAddresses.Value;
				Context.SettlementInDetail.AdditionalItem.Identifier = PartAddresses.Identifier;
				PathXPath = ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(90, Context.SettlementInDetail.AdditionalItem.Abbr);
				Context.SettlementInDetail.AdditionalItem.PathXPath = PathXPath;
			ElsIf PartAddresses.Level = 91 Then
				Context.SettlementInDetail.SubordinateItem.Presentation = PartAddresses.Value;
				Context.SettlementInDetail.SubordinateItem.Identifier = PartAddresses.Identifier;
				PathXPath = ContactInformationManagementClientServerReUse.AddressingAdditionalObjectXPath(91, Context.SettlementInDetail.AdditionalItem.Abbr);
				Context.SettlementInDetail.SubordinateItem.PathXPath = PathXPath;
			Else
				Context.SettlementInDetail.Street.Presentation = PartAddresses.Value;
			EndIf;
		EndDo;
		
	Else
		Context.SettlementInDetail.Street.Presentation = Context.Street;
	EndIf;
	
	// Recheck the building, the code and presentation are updated there.
	ProcessorChangesHomeServer(Context);
EndProcedure

&AtServerNoContext
Procedure ProcessorChangesHomeServer(Context)
	
	UpdateIndexAndPresentation(Context);
	
EndProcedure

&AtClient
Procedure DataProcessorCountriesChangesClient()
	ItsRussianAddress = Country = RussiaCountry;
	
	Items.IndexOf.Visible = ItsRussianAddress;
	Items.AddressType.CurrentPage = ?(ItsRussianAddress, Items.RussianAddress, Items.ForeignAddress);
	
	// You can check, enter in free form and search by the code only Russian addresses.
	Items.CheckAddressFilling.Enabled   = ItsRussianAddress;
	
	Items.EnterAddressInFreeForm.Enabled             = ItsRussianAddress;
	Items.InputAddressInFreeFormatAllActions.Enabled  = ItsRussianAddress;
	
	Items.FillByZipCode.Enabled            = ItsRussianAddress;
	Items.FillByZipCodeAllActions.Enabled = ItsRussianAddress;
	
	// You can import only Russian Addresses.
	If CanImportClassifier Then
		ButtonPanel = Items.Find("FormImportClassifier");
		If ButtonPanel <> Undefined Then
			Items.FormImportClassifier.Enabled = ItsRussianAddress;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetItemsChoiceList(ItemKind, ItemValue, Data)
	ItemValue.DropListButton = Data.CanSelectValues;
	
	TypeList = Data.TypeOptions;
	ItemKind.DropListButton = TypeList.Count() > 0;
	If ItemKind.DropListButton Then
		ItemKind.ChoiceList.LoadValues(TypeList);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure UpdateIndexAndPresentation(Context, XDTOContact = Undefined)
	
	Info = ?(XDTOContact = Undefined, ContactInformationForAttributesValue(Context), XDTOContact);
	
	SetValueIndex(Context, Info);
	FillAddressPresentation(Context, Info);
	
EndProcedure

&AtServerNoContext
Procedure SetValueIndex(Context, XDTOContact = Undefined)
	Info = ?(XDTOContact = Undefined, ContactInformationForAttributesValue(Context), XDTOContact);
	
	Address = Info.Content;
	
	ID = FindAddressIdentifierByHierarchy(Context.SettlementInDetail);
	IndexOfClassifier = Format(ContactInformationManagementService.DefineIndexOfAddresses(Address, ID), "ND=6; NGS=' '; NZ=; NG=0");
	
	Context.IndexOf = IndexOfClassifier;
	ContactInformationManagementService.PostalIndexOfAddresses(Address, IndexOfClassifier);
	XDTOContact.Presentation = ContactInformationManagementService.AddressPresentation(Address, Context.ContactInformationKind);
EndProcedure

&AtServerNoContext
Function FindAddressIdentifierByHierarchy(SettlementInDetail)
	
	ID = Undefined;
	IdLevel = 0;
	For Each AddressLevel In SettlementInDetail Do
		If ValueIsFilled(AddressLevel.Value.Identifier) AND IdLevel < AddressLevel.Value.Level Then
			ID = AddressLevel.Value.Identifier;
			IdLevel = AddressLevel.Value.Level;
		EndIf;
	EndDo;
	
	Return ?(ValueIsFilled(ID), New UUID(ID), Undefined);
EndFunction

&AtServerNoContext
Procedure FillAddressPresentation(Context, XDTOContact = Undefined)
	
	// Always enter the country code
	If TypeOf(Context.Country)=Type("CatalogRef.WorldCountries") Then
		Context.CountryCode = Context.Country.Code
	Else
		Context.CountryCode = "";
	EndIf;
	
	If Context.AllowInputAddressInFreeForm AND Context.AddressPresentationChanged Then
		Return;
	EndIf;
		
	Info = ?(XDTOContact = Undefined, ContactInformationForAttributesValue(Context), XDTOContact);
	Context.AddressPresentation = Info.Presentation;
EndProcedure

&AtServerNoContext
Procedure ValueofAttributesByContactInformation(Context, EditableInformation)
	
	DataAddresses = EditableInformation.Content;
	
	// Common attributes
	Context.AddressPresentation = EditableInformation.Presentation;
	Context.Comment         = EditableInformation.Comment;
	
	// Copy of the comment for the changes analysis.
	Context.CopyComment = Context.Comment;
	
	// Country by name
	CountryDescription = TrimAll(DataAddresses.Country);
	If IsBlankString(CountryDescription) Then
		Context.Country = Catalogs.WorldCountries.EmptyRef();
	Else
		RefToRussia = Catalogs.WorldCountries.Russia;
		If UPPER(CountryDescription) = UPPER(TrimAll(RefToRussia.Description)) Then
			Context.Country    = RefToRussia;
			Context.CountryCode = RefToRussia.Code;
		Else
			CountryInformation = Catalogs.WorldCountries.WorldCountriesData(, CountryDescription);
			If CountryInformation = Undefined Then
				// We did not find it neither in the catalog nor in the classifier.
				Context.Country    = Undefined;
				Context.CountryCode = Undefined;
			Else
				Context.Country    = CountryInformation.Ref;
				Context.CountryCode = CountryInformation.Code;
			EndIf;
		EndIf;
	EndIf;
	
	CalculatedPresentation = ContactInformationManagementService.GeneratePresentationContactInformation(
		EditableInformation, Context.ContactInformationKind);
		
	If ContactInformationManagementService.ItsRussianAddress(DataAddresses) Then
		Context.AllowInputAddressInFreeForm = Not IsBlankString(DataAddresses.Content.Address_to_document);
		
		// We additionally check the case when the document presentation equals the calculated one.
		If Context.AllowInputAddressInFreeForm Then
			If PresentationAddressesAreSame(CalculatedPresentation, DataAddresses.Content.Address_to_document, True) 
				AND PresentationAddressesAreSame(EditableInformation.Presentation, DataAddresses.Content.Address_to_document, True) 
			Then
				Context.AllowInputAddressInFreeForm = False;
				DataAddresses.Content.Address_to_document      = "";
			EndIf;
		EndIf;
		
		If Context.AllowInputAddressInFreeForm Then
			Context.AddressPresentation = DataAddresses.Content.Address_to_document;
		EndIf;
		
		If Context.ThereIsClassifier Then
			ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
			Context.SettlementIdentifier = ModuleAddressClassifierService.AddressObjectIdentifierByAddressParts(DataAddresses.Content);
		EndIf;
		
	Else
		Context.ForeignAddressPresentation = String(DataAddresses.Content);
	EndIf;
	
	// We just enter the code
	Context.IndexOf = Format(ContactInformationManagementService.PostalIndexOfAddresses(DataAddresses), "NG=");
	
	// Synthetic Settlement is received as presentation.
	Context.Settlement = ContactInformationManagementService.PresentationOfSettlement(DataAddresses);
	Context.Street = ContactInformationManagementService.PresentationStreet(DataAddresses);
	
	GenerateDetailedSettlement(Context, DataAddresses);
	
	// House, construction, unit
	BuildingsAndFacilities = ContactInformationManagementService.BuildingsAndFacilitiesAddresses(DataAddresses);
	
	// First two buildings have selected separately, the rest is in the list.
	DataTable = BuildingsAndFacilities.Buildings;
	
	// Kind = 1 - sign of building, ownership. Kind = 2, addit construction.
	StringHouses = DataTable.Find(1, "Kind");
	If StringHouses <> Undefined Then
		Context.HouseType = StringHouses.Type;
		Context.House     = StringHouses.Value;
		DataTable.Delete(StringHouses);
	EndIf;
	
	StringHouses = DataTable.Find(2, "Kind");
	If StringHouses<>Undefined Then
		Context.ConstructionType = StringHouses.Type;
		Context.Construction    = StringHouses.Value;
		DataTable.Delete(StringHouses);
	EndIf;
	
	LineNumber  = DataTable.Count();
	While LineNumber > 0 Do
		LineNumber = LineNumber - 1;
		FillPropertyValues(Context.AdditionalBuildings.Insert(0), DataTable[LineNumber]);
	EndDo;
	
	// The first unit is specified separately, the rest are in the list.
	DataTable = BuildingsAndFacilities.Units;
	LineNumber   = DataTable.Count();
	If LineNumber > 0 Then
		Context.UnitType = DataTable[0].Type;
		Context.Unit    = DataTable[0].Value;
	EndIf;
	While LineNumber > 1 Do
		LineNumber = LineNumber - 1;
		FillPropertyValues(Context.AdditionalUnits.Insert(0), DataTable[LineNumber]);
	EndDo;
	
EndProcedure

&AtServerNoContext
Function ContactInformationForAttributesValue(Context)
	TargetNamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	
	Result = XDTOFactory.Create( XDTOFactory.Type(TargetNamespace, "ContactInformation") );
	Result.Comment = Context.Comment;
	
	Result.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "Address"));
	Address = Result.Content;
	
	Address.Country = String(Context.Country);
	If Upper(Context.Country) <> Upper(Context.RussiaCountry.Description) Then
		Address.Content = Context.ForeignAddressPresentation;
		Result.Presentation = ContactInformationManagementService.AddressPresentation(Address, Context.ContactInformationKind);
		Return Result;
	EndIf;
	
	Address.Content = XDTOFactory.Create(XDTOFactory.Type(TargetNamespace, "AddressRF"));
	AddressRF = Address.Content;
	CompletedAddressParts = New ValueList;
	If Context.SettlementInDetail <> Undefined Then
		For Each KeyValue In Context.SettlementInDetail Do
			PointPart = KeyValue.Value;
			If Not IsBlankString(PointPart.Presentation) Then
				NoDetailedData = False;
				CompletedAddressParts.Add(PointPart.Level, PointPart.Presentation);
			EndIf;
			PathXPath = PointPart.PathXPath;
			ContactInformationManagementService.SetXDTOObjectAttribute(AddressRF, PathXPath, PointPart.Presentation);
		EndDo;
	EndIf;
	
	// Buildings and facilities
	TypeValueTable = Type("ValueTable");
	If TypeOf(Context.AdditionalBuildings)=TypeValueTable Then
		BuildingsTable = Context.AdditionalBuildings.Copy();
	Else
		BuildingsTable = FormDataToValue(Context.AdditionalBuildings, TypeValueTable);
	EndIf;
	
	If Not IsBlankString(Context.House) Then
		RowBuildings = BuildingsTable.Insert(0);
		RowBuildings.Type      = Context.HouseType;
		RowBuildings.Value = Context.House;
	EndIf;
	
	If Not IsBlankString(Context.Construction) Then
		RowBuildings = BuildingsTable.Insert(0);
		RowBuildings.Type      = Context.ConstructionType;
		RowBuildings.Value = Context.Construction;
	EndIf;
	
	If TypeOf(Context.AdditionalUnits)=TypeValueTable Then
		RoomTable = Context.AdditionalUnits.Copy();
	Else
		RoomTable = FormDataToValue(Context.AdditionalUnits, TypeValueTable);
	EndIf;
	
	If Not IsBlankString(Context.Unit) Then
		RowBuildings = BuildingsTable.Insert(0);
		RowBuildings.Type      = Context.UnitType;
		RowBuildings.Value = Context.Unit;
	EndIf;
	
	ContactInformationManagementService.BuildingsAndFacilitiesAddresses(AddressRF, 
		New Structure("Buildings, Rooms", BuildingsTable, RoomTable));
	
	// IndexOf
	ContactInformationManagementService.PostalIndexOfAddresses(AddressRF, Context.IndexOf);
	
	//
	If Not IsBlankString( Context.AdditionalItem) Then 
		ContactInformationManagementService.AddAdditionalAddressItems(AddressRF, Context.AdditionalItem, 90);
	EndIf;
	If Not IsBlankString(Context.SubordinateItem) Then 
		ContactInformationManagementService.AddAdditionalAddressItems(AddressRF, Context.SubordinateItem, 91);
	EndIf;
	
	// Presentation and free address entry.
	EstimatedPresentation = ContactInformationManagementService.AddressPresentation(Address, Context.ContactInformationKind);
	Presentation = TrimAll(Context.AddressPresentation);
	If Context.AllowInputAddressInFreeForm AND Context.AddressPresentationChanged Then
		If PresentationAddressesAreSame(Presentation, EstimatedPresentation) Then
			Result.Presentation = EstimatedPresentation;
			AddressRF.Unset("Address_to_document");
		Else
			Result.Presentation    = Presentation;
			AddressRF.Address_to_document = Presentation;
		EndIf;
	Else
		AddressRF.Unset("Address_to_document");
		Result.Presentation = EstimatedPresentation;
	EndIf;
	
	Return Result;
EndFunction

// Refills the SettlementInDetail structure by the current address data or form attribute data.
//
&AtServerNoContext
Procedure GenerateDetailedSettlement(Context, XDTODataAddresses = Undefined)
	
	If XDTODataAddresses = Undefined AND ValueIsFilled(Context.SettlementIdentifier) Then
		// Refill
		Context.SettlementInDetail = ContactInformationManagementService.AttributesListSettlement(
			Context.SettlementIdentifier,
			Context.ContactInformationKind.AddressFormat);
		Return;
		
	ElsIf TypeOf(XDTODataAddresses) = Type("String") Then
		// Try parsing
		AnalysisClassifier = SettlementsOnPresentation(XDTODataAddresses, Context.HideObsoleteAddresses);
		If AnalysisClassifier.ChoiceData.Count()=1 Then
			Variant = AnalysisClassifier.ChoiceData[0].Value.Value;
			Context.SettlementInDetail = ContactInformationManagementService.AttributesListSettlement(
				Variant.Code,
				Context.ContactInformationKind.AddressFormat);
			Return;
		EndIf;
	EndIf;
	
	Context.SettlementInDetail = ContactInformationManagementService.AttributesListSettlement(, 
		Context.ContactInformationKind.AddressFormat);
	
	If XDTODataAddresses = Undefined Then
		
		// All moves to the predefined detailed item from the form attributes.
		For Each KeyValue In Context.SettlementInDetail Do
			Value = KeyValue.Value;
			If Value.Predefined Then
				Value.Presentation = Context.Settlement;
				Break;
			EndIf;
		EndDo;
		
		Return;
	EndIf;
	
	// From the transferred XDTO
	AddressRF = ContactInformationManagementService.RussianAddress(XDTODataAddresses);
	If AddressRF <> Undefined Then
		
		For Each KeyValue In Context.SettlementInDetail Do
			Value = KeyValue.Value;
			If Value.Level <> 90 Then
				Presentation = ContactInformationManagementService.GetXDTOObjectAttribute(AddressRF, Value.PathXPath);
			Else
				Presentation = ContactInformationManagementService.FindAdditionalAddressItem(AddressRF);
			EndIf;
			
			Parts = ContactInformationManagementClientServer.DescriptionAbbreviation(Presentation);
			Value.Presentation = Presentation;
			Value.Description  = Parts.Description;
			Value.Abbr    = Parts.Abbr;
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteItemsGroup(Group)
	While Group.ChildItems.Count()>0 Do
		Item = Group.ChildItems[0];
		If TypeOf(Item)=Type("FormGroup") Then
			DeleteItemsGroup(Item);
		EndIf;
		Items.Delete(Item);
	EndDo;
	Items.Delete(Group);
EndProcedure

&AtServer
Function DrawAdditionalBuildingsAndFacilities() 
	Return New Structure("BuildingName, UnitName",
		DrawAdditionalBuildings(),
		DrawAdditionalUnits());
EndFunction

&AtServer
Function DrawAdditionalBuildings() 
	
	Delete = New Array;
	While Items.GroupConstructionsAdditionally.ChildItems.Count()>0 Do
		Group = Items.GroupConstructionsAdditionally.ChildItems[0];
		If TypeOf(Group)=Type("FormGroup") Then
			ID = Mid(Group.Name, 1 + StrLen("GroupConstruction"));
			If Not IsBlankString(ID) Then
				Delete.Add("ConstructionType" + ID);
				Delete.Add("Construction"    + ID);
				DeleteCommand = Commands.Find("DeleteConstruction" + ID);
				If DeleteCommand<>Undefined Then
					Commands.Delete(DeleteCommand);
				EndIf;
			EndIf;
			DeleteItemsGroup(Group);
		Else
			Items.Delete(Group);
		EndIf;
	EndDo;
	ChangeAttributes(,Delete);
	
	CountOfBuildings = AdditionalBuildings.Count()-1;
	TypeCount  = Items.ConstructionType.ChoiceList.Count()-2;
	
	Result = Undefined;
	For LineNumber=0 To CountOfBuildings Do
		String = AdditionalBuildings[LineNumber];
		ID = Format(LineNumber, "NZ=; NG=");
		
		NewFolder = Items.Add("GroupConstruction" + ID, Type("FormGroup"), Items.GroupConstructionsAdditionally);
		FillPropertyValues(NewFolder, Items.GroupConstructionPrimary, , "TitleDataPath");
		
		NewType = Items.Add("ConstructionType" + ID, Type("FormField"), NewFolder);
		FillPropertyValues(NewType, Items.ConstructionType, , "DataPath, ChoiceList, SelectedText, TypeLink");
		NewType.ChoiceList.LoadValues(Items.ConstructionType.ChoiceList.UnloadValues());
		NewType.SetAction("OnChange", "Attachable_TypeStructuresOnChange");
		
		NewItem = Items.Add("Construction" + ID, Type("FormField"), NewFolder);
		FillPropertyValues(NewItem, Items.Construction, , "DataPath, ChoiceList, SelectedText, TypeLink");
		NewItem.ChoiceList.LoadValues(Items.Construction.ChoiceList.UnloadValues());
		NewItem.SetAction("OnChange", "Attachable_ConstructionOnChange");
		
		If LineNumber=CountOfBuildings Then
			Result = NewItem.Name;
		EndIf;
		
		Add = New Array;
		Add.Add(New FormAttribute(NewType.Name, New TypeDescription("String")));
		Add.Add(New FormAttribute(NewItem.Name, New TypeDescription("String")));
		
		ChangeAttributes(Add);
		ThisObject[NewType.Name]     = String.Type;
		ThisObject[NewItem.Name] = String.Value;
		
		NewType.DataPath     = NewType.Name;
		NewItem.DataPath = NewItem.Name;
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Procedure Attachable_StructureTypeOnChange(Item)
	LineNumber = Mid(Item.Name, 1 + StrLen("ConstructionType"));
	TasksRow = AdditionalBuildings.Get(LineNumber);
	TasksRow.Type = ThisObject[Item.Name];
	TasksRow.PathXPath = ContactInformationManagementClientServerReUse.XNumberOfAdditionalObjectPathAddressing(TasksRow.Type);
	
	Context = ContextFormClient();
	UpdateIndexAndPresentation(Context);
	ContextFormClient(Context);
	
	Modified = True;
EndProcedure

&AtClient
Procedure Attachable_ConstructionOnChange(Item)
	LineNumber = Mid(Item.Name, 1 + StrLen("Construction"));
	TasksRow = AdditionalBuildings.Get(LineNumber);
	TasksRow.Value = ThisObject[Item.Name];
	
	Context = ContextFormClient();
	UpdateIndexAndPresentation(Context);
	ContextFormClient(Context);
	
	Modified = True;
EndProcedure

&AtServer
Function DrawAdditionalUnits()
	
	Delete = New Array;
	While Items.GroupPremisesAdditionally.ChildItems.Count()>0 Do
		Group = Items.GroupPremisesAdditionally.ChildItems[0];
		If TypeOf(Group)=Type("FormGroup") Then
			ID = Mid(Group.Name, 1 + StrLen("GroupUnit"));
			If Not IsBlankString(ID) Then
				Delete.Add("UnitType" + ID);
				Delete.Add("Unit"    + ID);
				DeleteCommand = Commands.Find("DeleteUnit" + ID);
				If DeleteCommand<>Undefined Then
					Commands.Delete(DeleteCommand);
				EndIf;
			EndIf;
			DeleteItemsGroup(Group);
		Else
			Items.Delete(Group);
		EndIf;
	EndDo;
	ChangeAttributes(,Delete);
	
	CountOfPremises = AdditionalUnits.Count()-1;
	TypeCount     = Items.UnitType.ChoiceList.Count()-2;
	
	Result = Undefined;
	For LineNumber=0 To CountOfPremises Do
		String = AdditionalUnits[LineNumber];
		ID = Format(LineNumber, "NZ=; NG=");
		
		NewFolder = Items.Add("GroupUnit" + ID, Type("FormGroup"), Items.GroupPremisesAdditionally);
		FillPropertyValues(NewFolder, Items.GroupUnitElementary, , "TitleDataPath");
		
		NewType = Items.Add("UnitType" + ID, Type("FormField"), NewFolder);
		FillPropertyValues(NewType, Items.UnitType, , "DataPath, ChoiceList, SelectedText, TypeLink");
		NewType.ChoiceList.LoadValues(Items.UnitType.ChoiceList.UnloadValues());
		NewType.SetAction("OnChange", "Attachable_UnitTypeOnChange");
		
		NewItem = Items.Add("Unit" + ID, Type("FormField"), NewFolder);
		FillPropertyValues(NewItem, Items.Unit, , "DataPath, ChoiceList, SelectedText, TypeLink");
		NewItem.ChoiceList.LoadValues(Items.Unit.ChoiceList.UnloadValues());
		NewItem.SetAction("OnChange", "Attachable_PuttingOnChange");
		
		If LineNumber=CountOfPremises Then
			Result = NewItem.Name;
		EndIf;
		
		Add = New Array;
		Add.Add(New FormAttribute(NewType.Name, New TypeDescription("String")));
		Add.Add(New FormAttribute(NewItem.Name, New TypeDescription("String")));
		
		ChangeAttributes(Add);
		ThisObject[NewType.Name]     = String.Type;
		ThisObject[NewItem.Name] = String.Value;
		
		NewType.DataPath     = NewType.Name;
		NewItem.DataPath = NewItem.Name;
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Procedure Attachable_UnitTypeOnChange(Item)
	LineNumber = Mid(Item.Name, 1 + StrLen("UnitType"));
	PlacingsRow = AdditionalUnits.Get(LineNumber);
	PlacingsRow.Type = ThisObject[Item.Name];
	PlacingsRow.PathXPath = ContactInformationManagementClientServerReUse.XNumberOfAdditionalObjectPathAddressing(PlacingsRow.Type);
	
	Context = ContextFormClient();
	FillAddressPresentation(Context);
	ContextFormClient(Context);
	
	Modified = True;
EndProcedure

&AtClient
Procedure Attachable_UnitOnChange(Item)
	LineNumber = Mid(Item.Name, 1 + StrLen("Unit"));
	TasksRow = AdditionalUnits.Get(LineNumber);
	TasksRow.Value = ThisObject[Item.Name];
	
	Context = ContextFormClient();
	FillAddressPresentation(Context);
	ContextFormClient(Context);
	
	Modified = True;
EndProcedure

&AtClient 
Procedure FillErrorMessage(ErrorList, WarnAboutMissing)
	
	ClearMessages();
	
	ErrorsCount = ErrorList.Count();
	If ErrorsCount = 0 AND WarnAboutMissing Then
		// No errors
		ShowMessageBox(, NStr("en='The address is entered correctly.'"));
		Return;
	EndIf;	
	
	If ErrorsCount = 1 Then
		ErrorPlace = ErrorList[0].Value;
		If IsBlankString(ErrorPlace) Or ErrorPlace = "/" Then
			// One address mistake not attached to a field.
			ShowMessageBox(, ErrorList[0].Presentation);
			Return;
		EndIf;
	EndIf;
	
	// Inform the list with reference to the fields.
	For Each Item In ErrorList Do
		CommonUseClientServer.MessageToUser(
			Item.Presentation,,,PathToFormDataByPathXPath(Item.Value));
	EndDo;
		
EndProcedure

&AtClient
Function PathToFormDataByPathXPath(PathXPath) 
	
	If PathXPath = "RFTerritorialEntity" Then
		Return "Settlement";
		
	ElsIf PathXPath = "District" Then
		Return "Settlement";
		
	ElsIf PathXPath = ContactInformationManagementClientServerReUse.RegionXPath() Then
		Return "Settlement";
		
	ElsIf PathXPath = "City" Then
		Return "Settlement";
		
	ElsIf PathXPath = "UrbDistrict" Then
		Return "Settlement";
		
	ElsIf PathXPath = "Settlement" Then
		Return "Settlement";
		
	ElsIf PathXPath = "Street" Then
		Return "Street";
		
	ElsIf PathXPath = ContactInformationManagementClientServerReUse.XMailPathIndex() Then
		Return "IndexOf";
		
	EndIf;
	
	// Additionally added buildings and facilities.
	Filter = New Structure("PathXPath", PathXPath);
	
	Rows = AdditionalBuildings.FindRows(Filter);
	If Rows.Count() > 0 Then
		// The first is not empty
		For Each RowBuildings In Rows Do
			AttributeName = "Construction" + Format(AdditionalBuildings.IndexOf(RowBuildings), "NZ=; NG=");
			If ValueIsFilled(ThisObject[AttributeName]) Then
				Return AttributeName;
			EndIf;
		EndDo;
	EndIf;
	
	Rows = AdditionalUnits.FindRows(Filter); 
	If Rows.Count() > 0 Then
		// The first is not empty
		For Each FacilityString In Rows Do
			AttributeName = "Unit" + Format(AdditionalUnits.IndexOf(FacilityString), "NZ=; NG=");
			If ValueIsFilled(ThisObject[AttributeName]) Then
				Return AttributeName;
			EndIf;
		EndDo;
	EndIf;
	
	// House variants
	For Each ItemOfList In Items.HouseType.ChoiceList Do
		If PathXPath = ContactInformationManagementClientServerReUse.XNumberOfAdditionalObjectPathAddressing(ItemOfList.Value) Then
			Return "House";
		EndIf;
	EndDo;
	
	// Block variants
	For Each ItemOfList In Items.ConstructionType.ChoiceList Do
		If PathXPath = ContactInformationManagementClientServerReUse.XNumberOfAdditionalObjectPathAddressing(ItemOfList.Value) Then
			Return "Construction";
		EndIf;
	EndDo;
	
	// Premises variants
	For Each ItemOfList In Items.UnitType.ChoiceList Do
		If PathXPath = ContactInformationManagementClientServerReUse.XNumberOfAdditionalObjectPathAddressing(ItemOfList.Value) Then
			Return "Unit";
		EndIf;
	EndDo;
		
	// It was not found
	Return "";
EndFunction

&AtClient
Procedure ClearAddressClient()
	
	Context = ContextFormClient();
	ClearAddressServer(Context);
	ContextFormClient(Context);
	
	Modified = True;
EndProcedure

&AtServer
Procedure ClearAddressServer(Context)
	
	If Context.Country<>Context.RussiaCountry Then
		Context.ForeignAddressPresentation = "";
		Return;
	EndIf;
	
	Context.Comment = "";
	
	Context.IndexOf = Undefined;
	
	Context.SettlementIdentifier = Undefined;
	Context.Settlement                = "";
	Context.SettlementInDetail = ContactInformationManagementService.AttributesListSettlement();
	
	Context.StreetIdentifier = Undefined;
	Context.Street = "";
	
	Context.HouseType      = ContactInformationManagementClientServer.FirstOrEmpty(Items.HouseType.ChoiceList);
	Context.ConstructionType  = ContactInformationManagementClientServer.FirstOrEmpty(Items.ConstructionType.ChoiceList);
	Context.UnitType = ContactInformationManagementClientServer.FirstOrEmpty(Items.UnitType.ChoiceList);
	
	Context.House       = "";
	Context.Construction  = "";
	Context.Unit = "";
	
	Context.AdditionalBuildings.Clear();
	Context.AdditionalUnits.Clear();
	
	XDTOContactInfo = ContactInformationForAttributesValue(Context);
	GenerateDetailedSettlement(Context, XDTOContactInfo.Content);
	FillAddressPresentation(Context, XDTOContactInfo);
	
	// Clear directly in the form, it is already cleared in the context.
	AdditionalBuildings.Clear();
	AdditionalUnits.Clear();
	DrawAdditionalBuildingsAndFacilities();
EndProcedure

&AtClient
Function UnusedItemsAdditionalTables(DataTable, ItemSource, MarkerValue)
	Used = New Map;
	Used.Insert(ThisObject[ItemSource.Name], True);
	For Each String In DataTable Do
		Used.Insert(String.Type, True);
	EndDo;
	
	Result = New ValueList;
	For Each ItemOfList In ItemSource.ChoiceList Do
		If Used[ItemOfList.Value]=Undefined Then
			Result.Add(MarkerValue, ItemOfList.Value, ItemOfList.Check, ItemOfList.Picture);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

&AtClient
Function CanAddAdditionalObjects()
	VariantsOfStructure  = UnusedItemsAdditionalTables(AdditionalBuildings, Items.ConstructionType, 1);
	PremisesVariants = UnusedItemsAdditionalTables(AdditionalUnits, Items.UnitType, 2);
	Return VariantsOfStructure.Count() + PremisesVariants.Count() > 0
EndFunction

&AtServer
Procedure SetKeyUseForms()
	WindowOptionsKey = String(Country);
	
	Quantity = 0;
	For Each String In AdditionalBuildings Do
		If Not IsBlankString(String.Value) Then
			Quantity = Quantity + 1;
		EndIf;
	EndDo;
	WindowOptionsKey = WindowOptionsKey + "/" + Format(Quantity, "NZ=; NG=");
	
	Quantity = 0;
	For Each String In AdditionalUnits Do
		If Not IsBlankString(String.Value) Then
			Quantity = Quantity + 1;
		EndIf;
	EndDo;
	
	WindowOptionsKey = WindowOptionsKey + "/" + Format(Quantity, "NZ=; NG=");
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////

&AtServerNoContext
Function LocalityAutofitList(Text, AdditionalParameters)
	
	Return ContactInformationManagementService.LocalityAutofitList(Text, AdditionalParameters);
	
EndFunction

&AtServerNoContext
Function StreetAutoselectionList(SettlementIdentifier, Text, AdditionalParameters)
	
	Return ContactInformationManagementService.StreetAutoselectionList(SettlementIdentifier, Text, AdditionalParameters);
		
EndFunction

&AtServerNoContext
Function SettlementsOnPresentation(Text, HideObsoleteAddresses = False, SelectRows = 50)
	
	Return ContactInformationManagementService.SettlementsOnPresentation(Text, HideObsoleteAddresses, SelectRows);
		
EndFunction

&AtServerNoContext
Function StreetsReporting(Parent, Text, HideObsoleteAddresses = False, SelectRows = 50)
	
	Return ContactInformationManagementService.StreetsReporting(Parent, Text, HideObsoleteAddresses, SelectRows);
	
EndFunction

// Convert the form Attributes <-> Structure
//
&AtClient
Function ContextFormClient(NewData = Undefined)
	
	AttributesList = "
		|ContactInformationKind,
		|Country,
		|CountryCode, RussiaCountry, HideObsoleteAddresses, IndexOf, AddressPresentation,
		|ForeignAddressPresentation, Comment, CopyComment,
		|Settlement, SettlementIdentifier,
		|SettlementInDetail, Street, StreetIdentifier, HouseType, House, ConstructionType,
		|Construction, UnitType,
		|Unit, AllowInputAddressInFreeForm, AddressPresentationChanged, Modified, ThereIsClassifier, AdditionalItem, SubordinateItem
		|";
		
	CollectionsList = "AdditionalBuildings, AdditionalUnits";
	
	If NewData = Undefined Then
		// Read
		Result = New Structure(AttributesList + "," + CollectionsList);
		FillPropertyValues(Result, ThisObject, AttributesList + "," + CollectionsList);
		Return Result;
	EndIf;
	
	FillPropertyValues(ThisObject, NewData, AttributesList, CollectionsList);
	FillCollectionsValues(ThisObject, NewData, CollectionsList);
	
	Return NewData;
EndFunction

&AtClient
Procedure FillCollectionsValues(Receiver, Source, PropertyList)
	For Each KeyValue In New Structure(PropertyList) Do
		PropertyName = KeyValue.Key;
		PropertyReceiver = Receiver[PropertyName];
		PropertyReceiver.Clear();
		For Each Value In Source[PropertyName] Do
			FillPropertyValues(PropertyReceiver.Add(), Value);
		EndDo;
	EndDo;
EndProcedure

// Item permission for entering in the free format.
//
// Parameters:
//    - Mode                    - Boolean - True - you can edit the address presentation, False - is not allowed.
//    - ToFormPresentation - Boolean - optional flag. It is set by default.
//
&AtClient
Procedure StateInputPresentationAddresses(Mode, ToFormPresentation=True)
	Item = Items.AddressPresentation;
	
	Item.TextEdit = Mode;
	If Mode Then
		Item.TextEdit = True;
		Item.BackColor = AutoColor;
	Else
		Item.TextEdit = False;
		Item.BackColor = FormBackColor;
		
		If ToFormPresentation Then
			Context = ContextFormClient();
			FillAddressPresentation(Context);
			ContextFormClient(Context);
		EndIf;
	EndIf;
	
	// Other input fields
	StateGroupsInput(Items.CountryOfAddress, Not Mode);
	StateGroupsInput(Items.AddressType, Not Mode);
	
	// Mode mark
	Items.EnterAddressInFreeForm.Check            = Mode;
	Items.InputAddressInFreeFormatAllActions.Check = Mode;
	
	Items.AddressPresentationContextMenuEnterAddressInFreeFormat.Check = Mode;
	
	// It is not allowed to check the address entered manually.
	If Country = RussiaCountry Then
		Items.CheckAddressFilling.Enabled = Not Mode;
	EndIf;
	
	// Country - still managing field.
	If Items.Country.Enabled Then
		Items.Country.BackColor = BackgroundColorFieldsManager;
	EndIf;
	
	// Switch the title presentation and the current entry item to display the mode.
	If Mode Then
		Items.AddressPresentation.TitleLocation = FormItemTitleLocation.Top;
		Items.AddressPresentation.Title          = NStr("en='Address in free form'");
		
		Items.CountryOfAddress.Representation        = UsualGroupRepresentation.None;
		
		CurrentItem = Items.AddressPresentation;
	Else 
		Items.AddressPresentation.TitleLocation = FormItemTitleLocation.None;
		Items.AddressPresentation.Title          = "";
		
		Items.CountryOfAddress.Representation        = UsualGroupRepresentation.NormalSeparation;
		
		CurrentItem = Items.Settlement;
	EndIf;
	
EndProcedure

// Setting of item availability in the group.
//
// Parameters:
//    - Group - FormGroup - Container for items.
//    - Mode  - Boolean      - Items permission flag. True - is allowed, False - no.
//
&AtClient
Procedure StateGroupsInput(Group, Mode)
	
	For Each Item In Group.ChildItems Do
		PointType = TypeOf(Item);
		If PointType = Type("FormGroup") Then
			If Item <> Items.ForeignAddress Then
				StateGroupsInput(Item, Mode);
			EndIf;
			
		ElsIf PointType = Type("FormButton") Then
			If Item = Items.AddObject Then
				Item.Enabled = Mode AND CanAddAdditionalObjects();
			Else
				Item.Enabled = Mode;
			EndIf;
			
		ElsIf PointType = Type("FormField") AND Item.Type = FormFieldType.InputField Then
			If Item <> Items.AddressPresentation Then
				Item.ReadOnly = Not Mode;
				Item.BackColor = ?(Mode, AutoColor, FormBackColor);
			EndIf;
			
		Else 
			Item.Enabled = Mode;
			
		EndIf;
	EndDo;

EndProcedure

// You can change the presentation only when entering in the mode of entering in free form.
// Therefore you should modify the rest fields to the changed presentation.
// Do not change the country, free entry mode is available only for Russia.
//
&AtServer
Procedure AddressPresentationOnChangeServer()
	
	// Try to parse again
	XDTOContact = ContactInformationManagementService.XDTOContactInformationByPresentation(AddressPresentation, ContactInformationKind);
	XDTOContact.Presentation = AddressPresentation;
	XDTOContact.Comment   = Comment;
	
	// And we fill in the details except for the country and presentation.
	CurrentPresentation = AddressPresentation;
	CurrentCountry        = Country;
	
	ClearAddressServer(ThisObject);
	
	// Perhaps the free entry will be disabled.
	ValueofAttributesByContactInformation(ThisObject, XDTOContact);
	
	AddressPresentation = CurrentPresentation;
	Country              = CurrentCountry;
	
	DrawAdditionalBuildingsAndFacilities();
	
	// Enable the mode of free entry forcefully.
	AllowInputAddressInFreeForm = True;
	Modified = True;
EndProcedure

// Compare two presentations for equivalence.
&AtServerNoContext
Function PresentationAddressesAreSame(Val Presentation1, Val Presentation2, Val IgnoreMarkNumber=False)
	Return PresentationHash(Presentation1, IgnoreMarkNumber)=PresentationHash(Presentation2, IgnoreMarkNumber);
EndFunction

&AtServerNoContext
Function PresentationHash(Val Presentation, Val IgnoreMarkNumber=False)
	Result = StrReplace(Presentation, Chars.LF, "");
	Result = StrReplace(Result, " ", "");
	If IgnoreMarkNumber Then
		Result = StrReplace(Result, "No.", "");
	EndIf;
	Return Upper(Result);
EndFunction

&AtServer
Function ServiceUnavailability()
	
	Return Items.GroupServerIsUnavailableDetails.CurrentPage = Items.ServiceUnavailable;
	
EndFunction

&AtServer
Procedure CheckClassifierAvailability(Val CheckResult = Undefined)
	
	If Not ThereIsClassifier Then
		Return;
	EndIf;
	
	AddressClassifierEnabled = PutToTempStorage(CheckResult, UUID);
	If CheckResult = Undefined Then
		If CommonUseClientServer.DebugMode() Then
			ContactInformationManagementService.CheckClassifierAvailability(AddressClassifierEnabled);
		Else
			ProcedureParameters = New Array;
			ProcedureParameters.Add(AddressClassifierEnabled);
			
			JobParameters = New Array;
			JobParameters.Add("ContactInformationManagementService.CheckClassifierAvailability");
			JobParameters.Add(ProcedureParameters);
			
			JobDescription = NStr("en = 'Check the address classifier service availability'");
			Task = BackgroundJobs.Execute("WorkInSafeMode.ExecuteConfigurationMethod", JobParameters,, JobDescription);
			JobID = Task.UUID;
			Return;
		EndIf;
	EndIf;
	
	UpdateClassifierAvailability(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateClassifierAvailability(Context)
	
	ClassifierAvailability = GetFromTempStorage(Context.AddressClassifierEnabled);
	Context.AddressClassifierEnabled = "";
	Context.JobID = "";
	
	Context.Items.GroupServerIsUnavailableDetails.CurrentPage = ?(ClassifierAvailability.Cancel,
		Context.Items.ServiceUnavailable, Context.Items.ServiceAvailable);
	If ClassifierAvailability.Cancel Then
		Context.ServiceMessageText = NStr("en = 'AutoComplete and Address Checking are not available:'") + Chars.LF 
			+ ClassifierAvailability.BriefErrorDescription;
	EndIf;

EndProcedure

&AtServerNoContext
Function SettlementInDetailByIdentifier(SettlementIdentifier, AddressFormat)
	Return ContactInformationManagementService.AttributesListSettlement(SettlementIdentifier, AddressFormat);
EndFunction

&AtClient
Procedure AuthorizationOnUserSupportSiteEnd(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		CheckClassifierAvailability();
	EndIf;
	
EndProcedure

&AtServer
Procedure SetPossibilityToSelectByCode(Val ThisWebService)
	
	PickByIndexAvailable = True;
	
	If ThisWebService OR Not CanImportClassifier Then
		PickByIndexAvailable = False;
		Return;
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
		Information = ModuleAddressClassifierService.BriefInformationAboutRFTerritorialEntitiesImport();
		
		If Information.StatesQuantity <= Information.ImportedStatesQuantity Then
			PickByIndexAvailable = False;
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function InformationAboutState(RFConstituentEntityName)
	
	ModuleAddressClassifierService = CommonUse.CommonModule("AddressClassifierService");
	InformationAboutState = ModuleAddressClassifierService.InformationAboutState(RFConstituentEntityName);
	
	Return InformationAboutState;
	
EndFunction

#EndRegion
