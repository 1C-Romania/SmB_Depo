////////////////////////////////////////////////////////////////////////////////
// The Contact information subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Handler of event OnChange of the contact information field of the form.
// It is called from connected actions when implementing subsystem "Contact information".
//
// Parameters:
//     Form             - ManagedForm - Form of the contact information owner.
//     Item           - FormField        - Form item that contains a contact information presentation.
//     IsTabularSection - Boolean           - Shows that the item is a part of the form table.
//
Procedure PresentationOnChange(Form, Item, IsTabularSection = False) Export

	IsTabularSection = IsTabularSection(Item);
	
	If IsTabularSection Then
		FillingData = Form.Items[Form.CurrentItem.Name].CurrentData;
		If FillingData = Undefined Then
			Return;
		EndIf;
	Else
		FillingData = Form;
	EndIf;
	
	// If it is clearing, then reset the presentation.
	RowData = GetAdditionalValuesString(Form, Item, IsTabularSection);
	If RowData = Undefined Then 
		Return;
	EndIf;
	
	Text = Item.EditText;
	If IsBlankString(Text) Then
		FillingData[Item.Name] = "";
		If IsTabularSection Then
			FillingData[Item.Name + "FieldsValues"] = "";
		EndIf;
		RowData.Presentation = "";
		RowData.FieldsValues = Undefined;
		Return;
	EndIf;
	
	RowData.FieldsValues = ContactInformationManagementServiceServerCall.PresentationXMLContactInformation(Text, RowData.Type);
	RowData.Presentation = Text;
	
	If IsTabularSection Then
		FillingData[Item.Name + "FieldsValues"] = RowData.FieldsValues;
	EndIf;
	
EndProcedure

// Handler of event StartChoice of the contact information form field.
// It is called from connected actions when implementing subsystem "Contact information".
//
// Parameters:
//     Form                - ManagedForm - Form of the contact information owner.
//     Item              - FormField        - Form item that contains a contact information presentation.
//     Modified   - Boolean           - Set flag of the form modification.
//     StandardProcessing - Boolean           - Set flag of the standard data processor of the form event.
//
// Returns:
//     Undefined
//
Function PresentationStartChoice(Form, Item, Modified = True, StandardProcessing = False) Export
	StandardProcessing = False;
	
	Result = New Structure;
	Result.Insert("AttributeName", Item.Name);
	
	IsTabularSection = IsTabularSection(Item);
	
	If IsTabularSection Then
		FillingData = Form.Items[Form.CurrentItem.Name].CurrentData;
		If FillingData = Undefined Then
			Return Undefined;
		EndIf;
	Else
		FillingData = Form;
	EndIf;
	
	RowData = GetAdditionalValuesString(Form, Item, IsTabularSection);
	
	// If the field is changed and does not correspond with the attribute, then make them similar.
	If FillingData[Item.Name] <> Item.EditText Then
		FillingData[Item.Name] = Item.EditText;
		PresentationOnChange(Form, Item, IsTabularSection);
		Form.Modified = True;
	EndIf;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ContactInformationKind", RowData.Kind);
	OpenParameters.Insert("FieldsValues", RowData.FieldsValues);
	OpenParameters.Insert("Presentation", Item.EditText);
	
	If Not IsTabularSection Then
		OpenParameters.Insert("Comment", RowData.Comment);
	EndIf;
	
	Notification = New NotifyDescription("PresentationStartChoiceEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("FillingData",  FillingData);
	Notification.AdditionalParameters.Insert("IsTabularSection", IsTabularSection);
	Notification.AdditionalParameters.Insert("RowData",      RowData);
	Notification.AdditionalParameters.Insert("Item",           Item);
	Notification.AdditionalParameters.Insert("Result",         Result);
	Notification.AdditionalParameters.Insert("Form",             Form);
	
	OpenContactInformationForm(OpenParameters,, Notification);
	
	Return Undefined;
EndFunction

// Handler of event Clearing fields of the contact information form.
// It is called from connected actions when implementing subsystem "Contact information".
//
// Parameters:
//     Form        - ManagedForm - Form of the contact information owner.
//     AttributeName - String           - Form attribute name that is associated with the contact information presentation.
//
// Returns:
//     Undefined
//
Function ClearingPresentation(Val Form, Val AttributeName) Export
	
	Result = New Structure("AttributeName", AttributeName);
	FoundString = Form.ContactInformationAdditionalAttributeInfo.FindRows(Result)[0];
	FoundString.FieldsValues = "";
	FoundString.Presentation = "";
	FoundString.Comment   = "";
	
	Form[AttributeName] = "";
	Form.Modified = True;
	
	RefreshFormContactInformation(Form, Result);
	Return Undefined;
EndFunction

// Handler of the command related to the contact information (write an email, open the address, etc.)
// It is called from connected actions when implementing subsystem "Contact information".
//
// Parameters:
//     Form      - ManagedForm - Form of the contact information owner.
//     CommandName - String           - Name of the automatically generated action command.
//
// Returns:
//     Undefined
//
Function LinkCommand(Val Form, Val CommandName) Export
	
	If CommandName = "ContactInformationAddInputField" Then
		Notification = New NotifyDescription("AddContactInformationInputFieldEnd", ThisObject, New Structure);
			
		Notification.AdditionalParameters.Insert("Form", Form);
		Form.ShowChooseFromMenu(Notification, Form.ContactInformationParameters.AddedItemsList, Form.Items.ContactInformationAddInputField);
		Return Undefined;
		
	ElsIf Left(CommandName, 7) = "Command" Then
		AttributeName = StrReplace(CommandName, "Command", "");
		CommandContextMenu = False;
		
	Else
		AttributeName = StrReplace(CommandName, "ContextMenu", "");
		CommandContextMenu = True;
		
	EndIf;
	
	Result = New Structure("AttributeName", AttributeName);
	FoundString = Form.ContactInformationAdditionalAttributeInfo.FindRows(Result)[0];
	ContactInformationType = FoundString.Type;
	
	If CommandContextMenu Then
		EnterComment(Form, AttributeName, FoundString, Result);
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		FillAddress(Form, AttributeName, FoundString, Result);
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.EmailAddress") Then
		MailAddress = Form.Items[AttributeName].EditText;
		// SB. Begin
		SmallBusinessClient.CreateEmail("", MailAddress, ContactInformationType, Form.Object);
		Return Undefined;
		// SB. End
		CreateEmail("", MailAddress, ContactInformationType);
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.WebPage") Then
		RefAddress = Form.Items[AttributeName].EditText;
		GotoWebLink("", RefAddress, ContactInformationType);
		
	EndIf;
	
	Return Undefined;
EndFunction

// Opening an address form of the contact information form.
// It is called from connected actions when implementing subsystem "Contact information".
//
// Parameters:
//     Form     - ManagedForm - Form of the contact information owner.
//     Result - Arbitrary     - Data passed by the command handler.
//
Procedure OpenAddressEntryForm(Form, Result) Export
	
	If Result <> Undefined Then
		
		If Result.Property("AddressesFormItem") Then
			PresentationStartChoice(Form, Form.Items[Result.AddressesFormItem]);
		EndIf;
		
	EndIf;
	
EndProcedure

// Handler of a possible update of the contact information form.
// It is called from connected actions when implementing subsystem "Contact information".
//
// Parameters:
//     Form     - ManagedForm - Form of the contact information owner.
//     Result - Arbitrary     - Data passed by the command handler.
//
Procedure ControlUpdateForms(Form, Result) Export
	
	// Analysis of reverse call of the input address form.
	OpenAddressEntryForm(Form, Result);
	
EndProcedure

// Handler of event ChoiceProcessing of the world country. 
// Automatically creates a new item in the WorldCountries catalog after selection.
//
// Parameters:
//     Item              - FormField    - Item that contains a world country being edited.
//     ValueSelected    - Arbitrary - Selection value.
//     StandardProcessing - Boolean       - Set flag of the standard data processor of the form event.
//
Procedure WorldCountryChoiceProcessing(Item, ValueSelected, StandardProcessing) Export
	If Not StandardProcessing Then 
		Return;
	EndIf;
	
	TypeOfSelected = TypeOf(ValueSelected);
	If TypeOfSelected = Type("Array") Then
		ConversionList = New Map;
		For IndexOf = 0 To ValueSelected.UBound() Do
			Data = ValueSelected[IndexOf];
			If TypeOf(Data) = Type("Structure") AND Data.Property("Code") Then
				ConversionList.Insert(IndexOf, Data.Code);
			EndIf;
		EndDo;
		
		If ConversionList.Count() > 0 Then
			ContactInformationManagementServiceServerCall.CollectionOfWorldCountriesAccordingToClassifier(ConversionList);
			For Each KeyValue In ConversionList Do
				ValueSelected[KeyValue.Key] = KeyValue.Value;
			EndDo;
		EndIf;
		
	ElsIf TypeOfSelected = Type("Structure") AND ValueSelected.Property("Code") Then
		ValueSelected = ContactInformationManagementServiceServerCall.WorldCountryAccordingToClassifier(ValueSelected.Code);
		
	EndIf;
	
EndProcedure

// Constructor for a structure of parameters to open the contact information form.
//
//  Parameters:
//      ContactInformationKind - CatalogRef.ContactInformationTypes - kind of the
//  information being edited, Value                - String - serialized value of the contact information fields.
//      Presentation           - String - optional presentation.
//
Function ContactInformationFormParameters(ContactInformationKind, Value, Presentation = Undefined, 
	Comment = Undefined) Export
	
	Return New Structure("ContactInformationKind, FieldsValues, Presentation, Comment",
		ContactInformationKind, Value, Presentation, Comment);
		
EndFunction

// Opens a relevant contact information form for editing or read-only.
//
//  Parameters:
//      Parameters    - Arbitrary - ContactInformationFormParameters function result.
//      Owner     - Arbitrary - parameter for the form being opened.
//      Notification   - NotifyDescription - for processing the form closure.
//
//  Return value: required form.
//
Function OpenContactInformationForm(Parameters, Owner = Undefined, Notification = Undefined) Export
	
	InformationKind = Parameters.ContactInformationKind;
	
	OpenableFormName = ContactInformationManagementClientServerReUse.FormInputNameContactInformation(InformationKind);
	If OpenableFormName = Undefined Then
		Raise NStr("en = 'Non-processed address type: """ + InformationKind + """'");
	EndIf;
	
	If Not Parameters.Property("Title") Then
		Parameters.Insert("Title", String(ContactInformationManagementServiceServerCall.TypeKindContactInformation(InformationKind)));
	EndIf;
	
	Parameters.Insert("OpenByScenario", True);
	
	Return OpenForm(OpenableFormName, Parameters, Owner,,,, Notification);
EndFunction

// UseModality

//  Outdated. You shall use OpenContactInformationForm
//
//  Modally opens a relevant contact information form for editing or read-only
//
//  Parameters:
//      Parameters    - Arbitrary - ContactInformationFormParameters
//      function result Owner     - Arbitrary - parameter for
//      the form being opened Uniqueness - Arbitrary - parameter for
//      the form being opened Window         - Arbitrary - parameter for the form being opened
//
//  Return value: edited result or Undefined if it is refused to edit
//
Function OpenContactInformationFormModally(Parameters, Owner = Undefined, Uniqueness = Undefined, Window = Undefined) Export
	
	InformationKind = Parameters.ContactInformationKind;
	
	OpenableFormName = ContactInformationManagementClientServerReUse.FormInputNameContactInformation(InformationKind);
	If OpenableFormName = Undefined Then
		Raise NStr("en = 'Non-processed address type: """ + InformationKind + """'");
	EndIf;
	
	If Not Parameters.Property("Title") Then
		Parameters.Insert("Title", String(ContactInformationManagementServiceServerCall.TypeKindContactInformation(InformationKind)));
	EndIf;
	
	Parameters.Insert("OpenByScenario", True);
	Return OpenFormModal(OpenableFormName, Parameters, Owner);
	
EndFunction

// End ModalityUse

// Creates email by contact information.
//
//  Parameters:
//    FieldsValues - String, Structure, Match, ValuesList - contact information.
//    Presentation - String  - presentation. Used if it is impossible to determine presentation from parameter.
//                    FieldsValues (there is no "Presentation" field).
//    ExpectedKind  - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes,
//                    Structure Used to determine a type if it can not be calculated by field FieldsValues.
//
Procedure CreateEmail(Val FieldsValues, Val Presentation = "", ExpectedKind = Undefined) Export
	
	ContactInformation = ContactInformationManagementServiceServerCall.CastContactInformationXML(
		New Structure("FieldsValues, Presentation, ContactInformationKind", FieldsValues, Presentation, ExpectedKind));
		
	InformationType = ContactInformation.ContactInformationType;
	If InformationType <> PredefinedValue("Enum.ContactInformationTypes.EmailAddress") Then
		Raise StrReplace(NStr("en = 'You can not create email by contact information with the type ""%1""'"),
			"%1", InformationType);
	EndIf;
	
	If FieldsValues = "" AND IsBlankString(Presentation) Then
		ShowMessageBox(,NStr("en = 'Enter an email address to send the email.'"));
		Return;
	EndIf;
	
	XMLData = ContactInformation.DataXML;
	MailAddress = ContactInformationManagementServiceServerCall.RowCompositionContactInformation(XMLData);
	If TypeOf(MailAddress) <> Type("String") Then
		Raise NStr("en = 'Error of the email address obtaining, incorrect type of the contact details'");
	EndIf;
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleWorkWithPostalMailClient = CommonUseClient.CommonModule("EmailOperationsClient");
		
		SendingParameters = New Structure("Recipient", MailAddress);
		ModuleWorkWithPostalMailClient.CreateNewEmail(SendingParameters);
		Return; 
	EndIf;
	
	// No email subsystem, run the system one.
	Notification = New NotifyDescription("CreateEmailByContactInformationEnd", ThisObject, MailAddress);
	SuggestionText = NStr("en = 'To send email, you should install extension for work with files.'");
	CommonUseClient.CheckFileOperationsExtensionConnected(Notification, SuggestionText);
	
EndProcedure

// Opens a reference by contact information.
//
// Parameters:
//    FieldsValues - String, Structure, Match, ValuesList - contact information.
//    Presentation - String  - presentation. Used if it is impossible to determine presentation from parameter.
//                    FieldsValues (there is no "Presentation" field).
//    ExpectedKind  - CatalogRef.ContactInformationTypes, EnumRef.ContactInformationTypes,
//                    Structure Used to determine a type if it can not be calculated by field FieldsValues.
//
Procedure GotoWebLink(Val FieldsValues, Val Presentation = "", ExpectedKind = Undefined) Export
	
	ContactInformation = ContactInformationManagementServiceServerCall.CastContactInformationXML(
		New Structure("FieldsValues, Presentation, ContactInformationKind", FieldsValues, Presentation, ExpectedKind));
	InformationType = ContactInformation.ContactInformationType;
	
	If InformationType <> PredefinedValue("Enum.ContactInformationTypes.WebPage") Then
		Raise StrReplace(NStr("en = 'Cannot open a reference by contact information of type ""%1""'"),
			"%1", InformationType);
	EndIf;
		
	XMLData = ContactInformation.DataXML;

	RefAddress = ContactInformationManagementServiceServerCall.RowCompositionContactInformation(XMLData);
	If TypeOf(RefAddress) <> Type("String") Then
		Raise NStr("en = 'Error of the link receiving, invalid type of contact information'");
	EndIf;
	
	If Find(RefAddress, "://") > 0 Then
		GotoURL(RefAddress);
	Else
		GotoURL("http://" + RefAddress);
	EndIf;
EndProcedure

#EndRegion

#Region ServiceProgramInterface

// End modeless dialogs.
Procedure PresentationStartChoiceEnd(Val ClosingResult, Val AdditionalParameters) Export
	If TypeOf(ClosingResult) <> Type("Structure") Then
		Return;
	EndIf;
	
	FillingData = AdditionalParameters.FillingData;
	RowData     = AdditionalParameters.RowData;
	Result        = AdditionalParameters.Result;
	Item          = AdditionalParameters.Item;
	Form            = AdditionalParameters.Form;
	
	PresentationText = ClosingResult.Presentation;
	
	If AdditionalParameters.IsTabularSection Then
		FillingData[Item.Name + "FieldsValues"] = ClosingResult.ContactInformation;
		
	Else
		If IsBlankString(RowData.Comment) AND Not IsBlankString(ClosingResult.Comment) Then
			Result.Insert("IsAddingComment", True);
			
		ElsIf Not IsBlankString(RowData.Comment) AND IsBlankString(ClosingResult.Comment) Then
			Result.Insert("IsAddingComment", False);
			
		Else
			If Not IsBlankString(RowData.Comment) Then
				Form.Items["Comment" + Item.Name].Title = ClosingResult.Comment;
			EndIf;
			
		EndIf;
		
		RowData.Presentation = PresentationText;
		RowData.FieldsValues = ClosingResult.ContactInformation;
		RowData.Comment   = ClosingResult.Comment;
	EndIf;
	
	FillingData[Item.Name] = PresentationText;
	
	Form.Modified = True;
	RefreshFormContactInformation(Form, Result);
EndProcedure

// End modeless dialogs.
Procedure AddContactInformationInputFieldEnd(Val SelectedItem, Val AdditionalParameters) Export
	If SelectedItem = Undefined Then
		// Refusal to select
		Return;
	EndIf;
	
	Result = New Structure("AddedKind", SelectedItem.Value);
	
	RefreshFormContactInformation(AdditionalParameters.Form, Result);
EndProcedure

//  The StartChoice event handler for a street.
//
//  Parameters:
//      Owner                       - Arbitrary - form item that is calling.
//      SettlementIdentifier - UUID - restriction by a locality.
//      CurrentValue                - UUID, Row - current value - either
//                                       a classifier code or a text.
//      AdditionalParameters        - Structure - additional parameter structure.
//
Procedure StartChoiceStreet(Owner, SettlementIdentifier, CurrentValue, AdditionalParameters) Export
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Return;
	EndIf;
	
	HideObsoleteAddresses = Undefined;
	AdditionalParameters.Property("HideObsoleteAddresses", HideObsoleteAddresses);
	If HideObsoleteAddresses = Undefined Then
		HideObsoleteAddresses = False;
	EndIf;
	
	Parameters = New Structure;
	Parameters.Insert("Parent", SettlementIdentifier);
	Parameters.Insert("PresentationStreet", CurrentValue);
	Parameters.Insert("Level",  7);
	Parameters.Insert("HideObsoleteAddresses",        HideObsoleteAddresses);
	
	OpenForm("DataProcessor.InputContactInformation.Form.SelectStreet", Parameters, Owner, 
		,,,, FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

//  Handler of event StartChoice for the address item (RF territorial entity, district, city, etc.)
//
//  Parameters:
//      Item        - Arbitrary - form item that is calling.
//      CodePartsAddress - Number - identifier of the processed address part, it depends on the classifier.
//      PartsAddresses    - Arbitrary - values for other address parts, depends on the classifier.
//      FormParameters - Structure - optional  additional parameter structure for the selection form.
//
Procedure StartChoiceItemAddress(Item, CodePartsAddress, PartsAddresses, FormParameters = Undefined) Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		StartChoiceItemAddressesCLADR(Item, CodePartsAddress, PartsAddresses, FormParameters);
	EndIf;
	
EndProcedure

//  Offers to export the address classifier.
//
//  Parameters:
//      Text  - String        - Additional offer text.
//      State - Number, String - Code or state name for import.
//
Procedure OfferExportClassifier(Val Text = "", Val State = Undefined) Export
	
	If Not CommonUseClient.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Return;
	EndIf;
	
	StateParameterType = TypeOf(State);
	ImportParameters   = New Structure;
	
	If StateParameterType = Type("Number") Then
		ImportParameters.Insert("StateCodeForImport", State);
		
	ElsIf StateParameterType = Type("String") Then
		ImportParameters.Insert("StateNameForImporting", State);
	EndIf;
	
	Notification = New NotifyDescription("OfferExportClassifierEnd", ThisObject, ImportParameters);
	OpenForm("DataProcessor.InputContactInformation.Form.AddressClassifierExport", ImportParameters, ThisObject,,,, Notification, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

Procedure OfferExportClassifierEnd(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ImportAddressClassifier(AdditionalParameters);
EndProcedure

//  Imports the address classifier.
//
Procedure ImportAddressClassifier(Val AdditionalParameters = Undefined) Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierClient = CommonUseClient.CommonModule("AddressClassifierClient");
		ModuleAddressClassifierClient.ImportAddressClassifier(AdditionalParameters);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////

// End of a modal dialog of an email creation.
Procedure CreateEmailByContactInformationEnd(Action, MailAddress) Export
	
	NotifyDescription = New NotifyDescription("CreateEmailByContactInformationAfterLaunchApplications", ThisObject);
	BeginRunningApplication(NotifyDescription, "mailto:" + MailAddress);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////////////////////
// CLADR implementation
//

Function ClientModuleCLADR()
	
	Return CommonUseClient.CommonModule("AddressClassifierClient");

EndFunction

Procedure StartChoiceItemAddressesCLADR(Item, CodePartsAddress, PartsAddresses, Parameters = Undefined)
	
	CodeAttribute = Upper(CodePartsAddress);
	If CodeAttribute = "REGION" Then
		Level = 1;
		
	ElsIf CodeAttribute = "district" Then
		Level = 2;
		
	ElsIf CodeAttribute = "CITY" Then
		Level = 3;
		
	ElsIf CodeAttribute = "Settlement" Then
		Level = 4;
		
	ElsIf CodeAttribute = "Street" Then
		Level = 5;
		
	Else
		Return;
		
	EndIf;
	
	FormParameters = ?(Parameters = Undefined, New Structure, Parameters);
	
	FormParameters.Insert("State", PartsAddresses.State.Value);
	If PartsAddresses.State.Property("ClassifierCode") Then
		FormParameters.Insert("ClassifierStateCode", PartsAddresses.State.ClassifierCode);
	EndIf;
	
	FormParameters.Insert("Region", PartsAddresses.Region.Value);
	If PartsAddresses.Region.Property("ClassifierCode") Then
		FormParameters.Insert("RegionCodeClassifier", PartsAddresses.Region.ClassifierCode);
	EndIf;
	
	FormParameters.Insert("City", PartsAddresses.City.Value);
	If PartsAddresses.City.Property("ClassifierCode") Then
		FormParameters.Insert("CityCodeClassifier", PartsAddresses.City.ClassifierCode);
	EndIf;
	
	FormParameters.Insert("Settlement", PartsAddresses.Settlement.Value);
	If PartsAddresses.Settlement.Property("ClassifierCode") Then
		FormParameters.Insert("SettlementCodeClassifier", PartsAddresses.Settlement.ClassifierCode);
	EndIf;
	
	FormParameters.Insert("Level", Level);
	
	ModuleCLADR = ClientModuleCLADR();
	ModuleCLADR.OpenChoiceFormCLADR(FormParameters, Item);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns a string of additional values by an attribute name.
//
// Parameters:
//    Form   - ManagedForm - passed form.
//    Item - FormDataStructureWithCollection - form data.
//
// Returns:
//    CollectionRow - found data.
//    Undefined    - when there is no data.
//
Function GetAdditionalValuesString(Form, Item, IsTabularSection = False)
	
	Filter = New Structure("AttributeName", Item.Name);
	Rows = Form.ContactInformationAdditionalAttributeInfo.FindRows(Filter);
	RowData = ?(Rows.Count() = 0, Undefined, Rows[0]);
	
	If IsTabularSection AND RowData <> Undefined Then
		
		PathToRow = Form.Items[Form.CurrentItem.Name].CurrentData;
		
		RowData.Presentation = PathToRow[Item.Name];
		RowData.FieldsValues = PathToRow[Item.Name + "FieldsValues"];
		
	EndIf;
	
	Return RowData;
	
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
// Returns:
//    String - phone presentation.
//
Function GeneratePhonePresentation(CountryCode, CityCode, PhoneNumber, Supplementary, Comment) Export
	
	Presentation = ContactInformationManagementClientServer.GeneratePhonePresentation(
	CountryCode, CityCode, PhoneNumber, Supplementary, Comment);
	
	Return Presentation;
	
EndFunction

// Fills out an address with a different address.
Procedure FillAddress(Val Form, Val AttributeName, Val FoundString, Val Result)
	
	// All rows - addresses,
	AllRows = Form.ContactInformationAdditionalAttributeInfo;
	FoundStrings = AllRows.FindRows( New Structure("Type, ThisAttributeOfTabularSection", FoundString.Type, False) );
	FoundStrings.Delete( FoundStrings.Find(FoundString) );
	
	FieldsForAnalysisValues = New Array;
	For Each Address In FoundStrings Do
		FieldsForAnalysisValues.Add(New Structure("Identifier, Presentation, FieldsValue, AddressKind",
			Address.GetID(), Address.Presentation, Address.FieldsValues, Address.Kind));
	EndDo;
	
	AddressesForFilling = ContactInformationManagementServiceServerCall.AddressesAvailableForCopying(FieldsForAnalysisValues, FoundString.Kind);
		
	If AddressesForFilling.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'Not to type an address several times, you can copy and paste the typed value into the field.'")
			,, NStr("en = 'Copying an address'"));
		Return;
	EndIf;
	
	Notification = New NotifyDescription("FillAddressEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Form", Form);
	Notification.AdditionalParameters.Insert("FoundString", FoundString);
	Notification.AdditionalParameters.Insert("AttributeName",    AttributeName);
	Notification.AdditionalParameters.Insert("Result",       Result);
	
	Form.ShowChooseFromMenu(Notification, AddressesForFilling, Form.Items["Command" + AttributeName]);
EndProcedure

// End a modeless dialog.
Procedure FillAddressEnd(Val SelectedItem, Val AdditionalParameters) Export
	If SelectedItem = Undefined Then
		Return;
	EndIf;
	
	AllRows = AdditionalParameters.Form.ContactInformationAdditionalAttributeInfo;
	RowSource = AllRows.FindByID(SelectedItem.Value);
	If RowSource = Undefined Then
		Return;
	EndIf;
		
	AdditionalParameters.FoundString.FieldsValues = RowSource.FieldsValues;
	AdditionalParameters.FoundString.Presentation = RowSource.Presentation;
	AdditionalParameters.FoundString.Comment   = RowSource.Comment;
		
	AdditionalParameters.Form[AdditionalParameters.AttributeName] = RowSource.Presentation;
		
	AdditionalParameters.Form.Modified = True;
	RefreshFormContactInformation(AdditionalParameters.Form, AdditionalParameters.Result);

EndProcedure

// Enter a comment from the context menu.
Procedure EnterComment(Val Form, Val AttributeName, Val FoundString, Val Result)
	Comment = FoundString.Comment;
	
	Notification = New NotifyDescription("EnterCommentEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Form", Form);
	Notification.AdditionalParameters.Insert("AttributeNameComment", "Comment" + AttributeName);
	Notification.AdditionalParameters.Insert("FoundString", FoundString);
	Notification.AdditionalParameters.Insert("PreviousComment", Comment);
	Notification.AdditionalParameters.Insert("Result", Result);
	
	CommonUseClient.ShowMultilineTextEditingForm(Notification, Comment, 
		NStr("en = 'Comment'"));
EndProcedure

// End a modeless dialog.
Procedure EnterCommentEnd(Val Comment, Val AdditionalParameters) Export
	If Comment = Undefined Or Comment = AdditionalParameters.PreviousComment Then
		// Refuse to enter or no changes.
		Return;
	EndIf;
	
	CommentWasEmpty  = IsBlankString(AdditionalParameters.PreviousComment);
	CommentIsEmpty = IsBlankString(Comment);
	
	AdditionalParameters.FoundString.Comment = Comment;
	
	If CommentWasEmpty AND Not CommentIsEmpty Then
		AdditionalParameters.Result.Insert("IsAddingComment", True);
	ElsIf Not CommentWasEmpty AND CommentIsEmpty Then
		AdditionalParameters.Result.Insert("IsAddingComment", False);
	Else
		Item = AdditionalParameters.Form.Items[AdditionalParameters.AttributeNameComment];
		Item.Title = Comment;
	EndIf;
	
	AdditionalParameters.Form.Modified = True;
	RefreshFormContactInformation(AdditionalParameters.Form, AdditionalParameters.Result)
EndProcedure

// Context call
Procedure RefreshFormContactInformation(Form, Result)

	Form.RefreshContactInformation(Result);
	
EndProcedure

Function IsTabularSection(Item)
	
	Parent = Item.Parent;
	
	While TypeOf(Parent) <> Type("ManagedForm") Do
		
		If TypeOf(Parent) = Type("FormTable") Then
			Return True;
		EndIf;
		
		Parent = Parent.Parent;
		
	EndDo;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of the conditional calls into other subsystems.

// Opens an import form of the address classifier.
//
Procedure WhenImportingAddressClassifier() Export
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierClient = CommonUseClient.CommonModule("AddressClassifierClient");
		ModuleAddressClassifierClient.ImportAddressClassifier();
	EndIf;
	
EndProcedure

Procedure CreateEmailByContactInformationAfterLaunchApplications(ReturnCode, AdditionalParameters) Export
	// Action is not required
EndProcedure

#EndRegion
