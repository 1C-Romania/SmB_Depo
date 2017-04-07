
#Region FormEvents

// Procedure - On create on read at server
//
// Parameters:
//  Form			- ManagedForm	 - Form for placing contact information
//  OwnerCI			- AnyRef	 - contact information owner
//  WidthKindField	- Number	 - the width of the kind field of contact information by default
//
Procedure OnCreateOnReadAtServer(Form, OwnerCI = Undefined, WidthKindField = 8) Export
	
	If OwnerCI = Undefined Then
		OwnerCI = Form.Object.Ref;
	EndIf;
	
	// Determination of auxiliary information
	MetadataObjectFullName = OwnerCI.Metadata().FullName();
	GroupKindsCI = Catalogs.ContactInformationKinds[StrReplace(MetadataObjectFullName, ".", "")];
	
	// Creation of tables-attributes, if there is no
	AddContactInformationFormAttributes(Form);
	
	// Caching information on the available types of contact information in the created table
	ReadContactInformationKindProperties(Form, GroupKindsCI);
	
	// Reading existing contact information in the created object table to display
	FillContactInformationTable(Form, OwnerCI);
	
	// Single preparation items and form commands 
	InitializeForm(Form);
	
	// Rebuilding the form items on the information from the table to display
	RefreshContactInformationItems(Form, WidthKindField);
	
EndProcedure

Procedure BeforeWriteAtServer(Form, CurrentObject) Export
	
	CurrentObject.ContactInformation.Clear();
	
	For Each DataCI In Form.ContactInformation Do
		ContactInformationManagement.WriteContactInformation(CurrentObject, DataCI.FieldValues, DataCI.Kind, DataCI.Type);
	EndDo;
	
EndProcedure

Procedure FillCheckProcessingAtServer(Form, Cancel) Export
	
	IsError	= False;
	Filter	= New Structure("Kind");
	
	For Each TableRow In Form.ContactInformation Do
		
		Filter.Kind	= TableRow.Kind;
		FindedRows	= Form.ContactInformationKindProperties.FindRows(Filter);
		If FindedRows.Count() = 0 Then
			Continue;
		EndIf;
		KindProperties = FindedRows[0];
		Index = Form.ContactInformation.IndexOf(TableRow);
		AttributeName = "ContactInformation["+Index+"].Presentation";
		
		If KindProperties.Mandatory And IsBlankString(TableRow.Presentation)
			And Not IsAnotherFilledRowsKindCI(Form, TableRow, TableRow.Kind) Then
			// And no another rows with multiply values.
			
			IsError = True;
			CommonUseClientServer.MessageToUser(
				StrTemplate(NStr("ru = 'Вид контактной информации ""%1"" не заполнен.'; en = 'Contact information kind ""%1"" is not filled.'"), KindProperties.KindPresentation),,, AttributeName);
			
		ElsIf KindProperties.CheckValidity And Not IsBlankString(TableRow.Presentation) Then
			
			ObjectCI = ContactInformationInternal.ContactInformationDeserialization(TableRow.FieldValues, TableRow.Kind);
			If TableRow.Comment <> Undefined Then
				ObjectCI.Comment = TableRow.Comment;
			EndIf;
			ObjectCI.Presentation = TableRow.Presentation;
			
			// Check
			If TableRow.Type = Enums.ContactInformationTypes.EmailAddress Then
				If Not EmailIsCorrect(ObjectCI, AttributeName) Then
					IsError = True;
				EndIf;
			ElsIf TableRow.Type = Enums.ContactInformationTypes.Address Then
				If ContactInformationManagement.ValidateContactInformation(TableRow.Presentation, TableRow.FieldValues, TableRow.Kind, TableRow.Type, AttributeName) > 0 Then
					IsError = True;
				EndIf;
			Else
				// Other types of contact information do not check
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If IsError Then
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region ProgramInterface

// Procedure updates form items in accordance with the data in table-attribute
//
// Parameters:
//  Form	 - ManagedForm	 - form-owner contact information
//
Procedure RefreshContactInformationItems(Form, WidthKindField = 8) Export
	
	AddingCommands = Form.Items.Find("ContactInformationAdding");
	If AddingCommands <> Undefined Then
		AddingCommands.Visible = ContactInformationSBClientServer.KindsListForAddingContactInformation(Form).Count() > 0;
	EndIf;
	
	Items = Form.Items;
	DeletingItems = New Array;
	
	For Each GroupItems In Items.ContactInformationValues.ChildItems Do
		DeletingItems.Add(GroupItems);
	EndDo;
	
	WidthCommentField = 11;
	If DeletingItems.Count() > 0 Then
		WidthKindField = Items["KindCI_0"].Width;
	EndIf;
	
	For Each DeletingItem In DeletingItems Do
		Items.Delete(DeletingItem);
	EndDo;
	
	Filter = New Structure("Kind");
	
	For Each DataCI In Form.ContactInformation Do
		
		IndexCI = Form.ContactInformation.IndexOf(DataCI);
		Filter.Kind = DataCI.Kind;
		FindedRows = Form.ContactInformationKindProperties.FindRows(Filter);
		If FindedRows.Count() = 0 Then
			Continue;
		EndIf;
		KindProperties = FindedRows[0];
		
		GroupValueCI = Items.Add("CI_" + IndexCI, Type("FormGroup"), Items.ContactInformationValues);
		GroupValueCI.Type			= FormGroupType.UsualGroup;
		GroupValueCI.Title			= DataCI.Kind;
		GroupValueCI.Representation	= UsualGroupRepresentation.None;
		GroupValueCI.Group			= ChildFormItemsGroup.Horizontal;
		GroupValueCI.ThroughAlign	= ThroughAlign.Use;
		GroupValueCI.ShowTitle		= False;
		
		DecorationAction = Items.Add("ActionCI_" + IndexCI, Type("FormDecoration"), GroupValueCI);
		DecorationAction.Type					= FormDecorationType.Picture;
		DecorationAction.Picture				= ActionPictureByContactInformationType(DataCI.Type);
		DecorationAction.Hyperlink				= True;
		DecorationAction.Width					= 2;
		DecorationAction.Height					= 1;
		DecorationAction.VerticalAlignInGroup	= ItemVerticalAlign.Center;
		DecorationAction.SetAction("Click", "Attachable_ActionCIClick");
		
		FieldKind = Items.Add("KindCI_" + IndexCI, Type("FormField"), GroupValueCI);
		FieldKind.Type				= FormFieldType.LabelField;
		FieldKind.DataPath			= "ContactInformation[" + IndexCI + "].Kind";
		FieldKind.TitleLocation		= FormItemTitleLocation.None;
		FieldKind.Width				= WidthKindField;
		FieldKind.HorizontalStretch	= False;
		
		EditInDialogAvailable = ForContactInformationTypeIsAvailableEditInDialog(DataCI.Type);
		
		FieldPresentation = Items.Add("PresentationCI_" + IndexCI, Type("FormField"), GroupValueCI);
		FieldPresentation.Type					= FormFieldType.InputField;
		FieldPresentation.DataPath				= "ContactInformation[" + IndexCI + "].Presentation";
		FieldPresentation.TitleLocation			= FormItemTitleLocation.None;
		FieldPresentation.ChoiceButton			= EditInDialogAvailable;
		FieldPresentation.AutoMarkIncomplete	= KindProperties.Mandatory;
		FieldPresentation.DropListWidth			= 40;
		FieldPresentation.SetAction("OnChange", "Attachable_PresentationCIOnChange");
		FieldPresentation.SetAction("Clearing", "Attachable_PresentationCIClearing");
		If KindProperties.EditInDialogOnly Then
			FieldPresentation.TextEdit	= False;
			FieldPresentation.BackColor	= StyleColors.ContactInformationWithEditingInDialogColor;
		EndIf;
		If EditInDialogAvailable Then
			FieldPresentation.SetAction("StartChoice", "Attachable_PresentationCIStartChoice");
		EndIf;
		
		// Context menu commands: show address on GoogleMaps
		If DataCI.Type = Enums.ContactInformationTypes.Address Then
			
			AddContextMenuCommand(Form,
				"ContextMenuMapGoogle_" + IndexCI,
				PictureLib.GoogleMaps,
				NStr("ru = 'Адрес на Google Maps'; en = 'Address on Google Maps'"),
				NStr("ru = 'Показывает адрес на карте Google Maps'; en = 'Show address on Google Maps'"),
				FieldPresentation
			);
			
		EndIf;
		
		If ForContactInformationTypeIsAvailableCommentInput(DataCI.Type) Then
			
			FieldPresentation.AutoMaxWidth	= False;
			FieldPresentation.MaxWidth		= 27;
			
			FieldComment = Items.Add("CommentCI_" + IndexCI, Type("FormField"), GroupValueCI);
			FieldComment.Type			= FormFieldType.InputField;
			FieldComment.DataPath = "ContactInformation[" + IndexCI + "].Comment";
			FieldComment.TitleLocation	= FormItemTitleLocation.None;
			FieldComment.SkipOnInput	= True;
			FieldComment.InputHint		= NStr("ru='Прим.'; en = 'Note'");
			FieldComment.AutoMaxWidth	= False;
			FieldComment.MaxWidth		= WidthCommentField;
			FieldComment.SetAction("OnChange", "Attachable_CommentCIOnChange");
			
		EndIf;
		
	EndDo;
	
	ContactInformationSBClientServer.FillChoiceListAddresses(Form);
	
EndProcedure

// The procedure adds the input fields of the form of contact information on the form
//
// Parameters:
//  Form					 - ManagedForm	 - contact information form-owner
//  AddingKind				 - CatalogRef.ContactInformationKinds	 - kindfor adding
//  SetShowInFormAlways		 - Boolean	 - sign setting "ShowInFormAlways"
//
Procedure AddContactInformation(Form, AddingKind, SetShowInFormAlways = False) Export
	
	If SetShowInFormAlways Then
		SetFlagShowInFormAlways(AddingKind);
		FindedRows = Form.ContactPersonContactInformationKindProperties.FindRows(New Structure("Kind", AddingKind));
		If FindedRows.Count() > 0 Then
			FindedRows[0].ShowInFormAlways = True;
		EndIf;
	EndIf;
	
	NumberCollectionItems = Form.ContactInformation.Count();
	InsertIndex = NumberCollectionItems;
	
	For ReverseIndex = 1 To NumberCollectionItems Do
		CurrentIndex = NumberCollectionItems - ReverseIndex;
		If Form.ContactInformation[CurrentIndex].Kind = AddingKind Then
			InsertIndex = CurrentIndex+1;
			Break;
		EndIf;
	EndDo;
	
	DataCI = Form.ContactInformation.Insert(InsertIndex);
	DataCI.Kind = AddingKind;
	DataCI.Type = CommonUse.ObjectAttributeValue(AddingKind, "Type");
	
	RefreshContactInformationItems(Form);
	Form.CurrentItem = Form.Items["PresentationCI_" + InsertIndex];
	
EndProcedure

// Function - For contact information type is available edit in dialog
//
// Parameters:
//  TypeCI	 - EnumRef.ContactInformationTypes	 - type for which availability is checked editing in dialog
// 
// Returned value:
//  Boolean - flag of editing in dialog
//
Function ForContactInformationTypeIsAvailableEditInDialog(TypeCI) Export
	
	If TypeCI = Enums.ContactInformationTypes.Address Then
		Return True;
	ElsIf TypeCI = Enums.ContactInformationTypes.Phone Then
		Return True;
	ElsIf TypeCI = Enums.ContactInformationTypes.Fax Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Function - For contact information type is available comment input
//
// Parameters:
//  TypeCI	 - EnumRef.ContactInformationTypes	 - type for which you checked the availability of a comment input
// 
// Returned value:
//  Boolean - a sign of the availability of the comment field on the form
//
Function ForContactInformationTypeIsAvailableCommentInput(TypeCI) Export
	
	If TypeCI = Enums.ContactInformationTypes.Address Or TypeCI = Enums.ContactInformationTypes.Other Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

// Function - Action picture by contact information type
//
// Parameters:
//  TypeCI	 - EnumRef.ContactInformationTypes	 - type for which you get the picture
// 
// Returned value:
//  Picture - to display the icon
//
Function ActionPictureByContactInformationType(TypeCI) Export
	
	If TypeCI = Enums.ContactInformationTypes.Phone Then
		ActionPicture = PictureLib.ContactInformationPhone;
	ElsIf TypeCI = Enums.ContactInformationTypes.EmailAddress Then
		ActionPicture = PictureLib.ContactInformationEmail;
	ElsIf TypeCI = Enums.ContactInformationTypes.Address Then
		ActionPicture = PictureLib.ContactInformationAddress;
	ElsIf TypeCI = Enums.ContactInformationTypes.Skype Then
		ActionPicture = PictureLib.ContactInformationSkype;
	ElsIf TypeCI = Enums.ContactInformationTypes.WebPage Then
		ActionPicture = PictureLib.ContactInformationWebpage;
	ElsIf TypeCI = Enums.ContactInformationTypes.Fax Then
		ActionPicture = PictureLib.ContactInformationFax;
	ElsIf TypeCI = Enums.ContactInformationTypes.Other Then
		ActionPicture = PictureLib.ContactInformationOther;
	Else
		ActionPicture = PictureLib.Empty;
	EndIf;
	
	Return ActionPicture;
	
EndFunction

// The function checks the correctness of e-mail addresses
//
// Parameters:
//  ObjectCI	 - ObjectXDTO	 - contact information XDTO-object
//  AttributeName - string	 - form attribute name, which will be connected with an error message
// 
// Returned value:
//  Boolean - sign of correctness
//
Function EmailIsCorrect(ObjectCI, Val AttributeName = "") Export
	
	ErrorString = "";
	
	EmailAddress = ObjectCI.Content;
	Namespace = ContactInformationClientServerCached.Namespace();
	If EmailAddress <> Undefined And EmailAddress.Type() = XDTOFactory.Type(Namespace, "Email") Then
		Try
			Result = CommonUseClientServer.SplitStringWithEmailAddresses(EmailAddress.Value);
			If Result.Count() > 1 Then
				
				ErrorString = NStr("ru = 'Допускается ввод только одного адреса электронной почты'; en = 'You can enter only one email address'");
				
			EndIf;
		Except
			ErrorString = BriefErrorDescription(ErrorInfo());
		EndTry;
	EndIf;
	
	If Not IsBlankString(ErrorString) Then
		CommonUseClientServer.MessageToUser(ErrorString,,AttributeName);
	EndIf;
	
	Return IsBlankString(ErrorString);
	
EndFunction

// Function returns a contact information types table to the default order
// 
// Return value:
//  ValueTable - Standard order of contact information types to display in the interface
//
Function OrderTypesCI() Export
	
	OrderTypesCI = New ValueTable;
	OrderTypesCI.Columns.Add("Type", New TypeDescription("EnumRef.ContactInformationTypes"));
	OrderTypesCI.Columns.Add("Order", New TypeDescription("Number"));
	
	RowTypes = OrderTypesCI.Add();
	RowTypes.Type	= Enums.ContactInformationTypes.Phone;
	RowTypes.Order	= 1;
	
	RowTypes = OrderTypesCI.Add();
	RowTypes.Type	= Enums.ContactInformationTypes.EmailAddress;
	RowTypes.Order	= 2;
	
	RowTypes = OrderTypesCI.Add();
	RowTypes.Type	= Enums.ContactInformationTypes.Address;
	RowTypes.Order	= 3;
	
	RowTypes = OrderTypesCI.Add();
	RowTypes.Type	= Enums.ContactInformationTypes.Skype;
	RowTypes.Order	= 4;
	
	RowTypes = OrderTypesCI.Add();
	RowTypes.Type	= Enums.ContactInformationTypes.WebPage;
	RowTypes.Order	= 5;
	
	RowTypes = OrderTypesCI.Add();
	RowTypes.Type	= Enums.ContactInformationTypes.Fax;
	RowTypes.Order	= 6;
	
	RowTypes = OrderTypesCI.Add();
	RowTypes.Type	= Enums.ContactInformationTypes.Other;
	RowTypes.Order	= 7;
	
	Return OrderTypesCI;
	
EndFunction

// The procedure sets the setting of contact information "ShowInFormAlways"
//
// Parameters:
//  ContactInformationKind	 - CatalogRef.ContactInformationKinds	 - kind for which the setting is set
//  SwitchOn				 - boolean	 - setting value
//
Procedure SetFlagShowInFormAlways(ContactInformationKind, SwitchOn = True) Export
	
	RecordSet = InformationRegisters.ContactInformationKindSettings.CreateRecordSet();
	
	// Read record set.
	RecordSet.Filter.Kind.Set(ContactInformationKind);
	RecordSet.Read();
	
	If RecordSet.Count() = 0 Then
		Record = RecordSet.Add();
	ElsIf RecordSet[0].ShowInFormAlways = SwitchOn Then
		Return; // Setting already, additional action is not required
	Else
		Record = RecordSet[0];
	EndIf;
	
	Record.Kind = ContactInformationKind;
	Record.ShowInFormAlways = SwitchOn;
	
	RecordSet.Write();
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

// The procedure for updating / refilled with predefined kinds of contact information. Initial filling of the base.
//
Procedure SetPropertiesPredefinedContactInformationKinds() Export
	
	Counterparties_SetKindProperties();
	ContactPersons_SetKindProperties();
	Companies_SetKindProperties();
	Individuals_SetKindProperties();
	StructuralUnits_SetKindProperties();
	Users_SetKindProperties();
	
EndProcedure

Procedure Counterparties_SetKindProperties()
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyEmail;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.VerificationSettings.CheckValidity	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyLegalAddress;
	KindParameters.Order					= 3;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyActualAddress;
	KindParameters.Order					= 4;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyDeliveryAddress;
	KindParameters.Order					= 5;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Skype");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartySkype;
	KindParameters.Order					= 6;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("WebPage");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyWebpage;
	KindParameters.Order					= 7;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Fax");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyFax;
	KindParameters.Order					= 8;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyPostalAddress;
	KindParameters.Order					= 9;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Other");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyOtherInformation;
	KindParameters.Order					= 10;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
EndProcedure

Procedure ContactPersons_SetKindProperties()
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.ContactPersonPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.ContactPersonEmail;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.VerificationSettings.CheckValidity	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Skype");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.ContactPersonSkype;
	KindParameters.Order					= 3;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("WebPage");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.ContactPersonSocialNetwork;
	KindParameters.Order					= 4;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Other");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.ContactPersonMessenger;
	KindParameters.Order					= 5;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
EndProcedure

Procedure Companies_SetKindProperties()
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CompanyLegalAddress;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= True;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CompanyActualAddress;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= True;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CompanyPostalAddress;
	KindParameters.Order					= 3;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CompanyPhone;
	KindParameters.Order					= 4;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CompanyEmail;
	KindParameters.Order					= 5;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.VerificationSettings.CheckValidity	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Fax");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CompanyFax;
	KindParameters.Order					= 6;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Other");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CompanyOtherInformation;
	KindParameters.Order					= 7;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
EndProcedure

Procedure Individuals_SetKindProperties()
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.IndividualPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.IndividualActualAddress;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMode		= False;
	KindParameters.EditInDialogOnly			= True;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.IndividualPostalAddress;
	KindParameters.Order					= 4;
	KindParameters.CanChangeEditMode		= False;
	KindParameters.EditInDialogOnly			= True;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.IndividualEmail;
	KindParameters.Order					= 6;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.VerificationSettings.CheckValidity	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Other");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.IndividualOtherInformation;
	KindParameters.Order					= 7;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	
EndProcedure

Procedure StructuralUnits_SetKindProperties()
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.StructuralUnitsPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.StructuralUnitsActualAddress;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= True;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.VerificationSettings.DomesticAddressOnly				= False;
	KindParameters.VerificationSettings.CheckValidity					= False;
	KindParameters.VerificationSettings.HideObsoleteAddresses			= False;
	KindParameters.VerificationSettings.IncludeCountryInPresentation	= False;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
EndProcedure

Procedure Users_SetKindProperties()
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.UserPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.UserEmail;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.VerificationSettings.CheckValidity		= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationManagement.ContactInformationKindParameters("WebPage");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.UserWebpage;
	KindParameters.Order					= 3;
	KindParameters.CanChangeEditMode		= True;
	KindParameters.EditInDialogOnly			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactInformationManagement.SetContactInformationKindProperties(KindParameters);
	ContactInformationSB.SetFlagShowInFormAlways(KindParameters.Kind);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure AddContactInformationFormAttributes(Form)
	
	ArrayAddingAttributes	= New Array;
	FormAttributesList		= Form.GetAttributes();
	
	CreateTableContactInformation = True;
	CreateTableContactInformationKindProperties	= True;
	
	For Each Attribute In FormAttributesList Do
		If Attribute.Name = "ContactInformation" Then
			CreateTableContactInformation = False;
		ElsIf Attribute.Name = "ContactInformationKindProperties" Then
			CreateTableContactInformationKindProperties = False;
		EndIf;
	EndDo;
	
	DescriptionString	= New TypeDescription("String");
	DescriptionBoolean	= New TypeDescription("Boolean");
	
	If CreateTableContactInformation Then
		
		TableName = "ContactInformation";
		ArrayAddingAttributes.Add(New FormAttribute(TableName, New TypeDescription("ValueTable"),,, True));
		ArrayAddingAttributes.Add(New FormAttribute("Kind", New TypeDescription("CatalogRef.ContactInformationKinds"), TableName));
		ArrayAddingAttributes.Add(New FormAttribute("Type", New TypeDescription("EnumRef.ContactInformationTypes"), TableName));
		ArrayAddingAttributes.Add(New FormAttribute("Presentation", New TypeDescription("String", , New StringQualifiers(500)), TableName));
		ArrayAddingAttributes.Add(New FormAttribute("Comment", DescriptionString, TableName));
		ArrayAddingAttributes.Add(New FormAttribute("FieldValues", DescriptionString, TableName));
		
	EndIf;
	
	If CreateTableContactInformationKindProperties Then
		
		TableName = "ContactInformationKindProperties";
		ArrayAddingAttributes.Add(New FormAttribute(TableName, New TypeDescription("ValueTable")));
		ArrayAddingAttributes.Add(New FormAttribute("Kind", New TypeDescription("CatalogRef.ContactInformationKinds"), TableName));
		ArrayAddingAttributes.Add(New FormAttribute("KindPresentation", DescriptionString, TableName));
		ArrayAddingAttributes.Add(New FormAttribute("Type", New TypeDescription("EnumRef.ContactInformationTypes"), TableName));
		ArrayAddingAttributes.Add(New FormAttribute("ShowInFormAlways", DescriptionBoolean, TableName));
		ArrayAddingAttributes.Add(New FormAttribute("AllowMultipleValueInput", DescriptionBoolean, TableName));
		ArrayAddingAttributes.Add(New FormAttribute("Mandatory", DescriptionBoolean, TableName));
		ArrayAddingAttributes.Add(New FormAttribute("CheckValidity", DescriptionBoolean, TableName));
		ArrayAddingAttributes.Add(New FormAttribute("EditInDialogOnly", DescriptionBoolean, TableName));
		
	EndIf;
	
	If ArrayAddingAttributes.Count() > 0 Then
		Form.ChangeAttributes(ArrayAddingAttributes);
	EndIf;
	
EndProcedure

Procedure ReadContactInformationKindProperties(Form, GroupKindsCI)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	OrderTypesCI.Type,
		|	OrderTypesCI.Order
		|INTO ttOrderTypes
		|FROM
		|	&OrderTypesCI AS OrderTypesCI
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ContactInformationKinds.Ref AS Kind,
		|	PRESENTATION(ContactInformationKinds.Ref) AS KindPresentation,
		|	ContactInformationKinds.Type AS Type,
		|	ISNULL(ContactInformationKindSettings.ShowInFormAlways, FALSE) AS ShowInFormAlways,
		|	ContactInformationKinds.AllowMultipleValueInput AS AllowMultipleValueInput,
		|	ContactInformationKinds.Mandatory,
		|	ContactInformationKinds.CheckValidity,
		|	ContactInformationKinds.EditInDialogOnly
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationKinds
		|		LEFT JOIN ttOrderTypes AS ttOrderTypes
		|		ON ContactInformationKinds.Type = ttOrderTypes.Type
		|		LEFT JOIN InformationRegister.ContactInformationKindSettings AS ContactInformationKindSettings
		|		ON ContactInformationKinds.Ref = ContactInformationKindSettings.Kind
		|WHERE
		|	ContactInformationKinds.DeletionMark = FALSE
		|	AND ContactInformationKinds.Parent = &GroupKindsCI
		|
		|ORDER BY
		|	ttOrderTypes.Order,
		|	ContactInformationKinds.AdditionalOrderingAttribute";
	
	Query.SetParameter("OrderTypesCI", OrderTypesCI());
	Query.SetParameter("GroupKindsCI", GroupKindsCI);
	
	PropertiesTable = Query.Execute().Unload();
	Form.ContactInformationKindProperties.Load(PropertiesTable);
	
EndProcedure

Procedure FillContactInformationTable(Form, OwnerCI)
	
	Form.ContactInformation.Clear();
	
	Query = New Query;
	Query.Текст = 
		"SELECT
		|	OrderTypes.Type,
		|	OrderTypes.Order
		|INTO ttOrderTypes
		|FROM
		|	&OrderTypes AS OrderTypes
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ContactInformationKinds.Ref AS Kind,
		|	ContactInformationKinds.Type AS Type,
		|	ContactInformationKinds.AdditionalOrderingAttribute AS OrderKinds,
		|	ttOrderTypes.Order AS OrderTypes
		|INTO ttAlwaysShowKinds
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationKinds
		|		LEFT JOIN ttOrderTypes AS ttOrderTypes
		|		ON ContactInformationKinds.Type = ttOrderTypes.Type
		|WHERE
		|	ContactInformationKinds.Ref IN(&AlwaysShowKinds)
		|
		|INDEX BY
		|	Kind
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	OwnerContactInformation.Kind AS Kind,
		|	OwnerContactInformation.Type,
		|	OwnerContactInformation.Presentation,
		|	OwnerContactInformation.FieldValues,
		|	OwnerContactInformation.Kind.AdditionalOrderingAttribute AS OrderKinds,
		|	ttOrderTypes.Order AS OrderTypes
		|INTO ttDataCI
		|FROM
		|	Catalog.Counterparties.ContactInformation AS OwnerContactInformation
		|		LEFT JOIN ttOrderTypes AS ttOrderTypes
		|		ON OwnerContactInformation.Type = ttOrderTypes.Type
		|WHERE
		|	OwnerContactInformation.Ref = &OwnerCI
		|	AND OwnerContactInformation.Kind <> VALUE(Catalog.ContactInformationKinds.EmptyRef)
		|
		|INDEX BY
		|	Kind
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ISNULL(ttDataCI.Kind, ttAlwaysShowKinds.Kind) AS Kind,
		|	ISNULL(ttDataCI.Type, ttAlwaysShowKinds.Type) AS Type,
		|	ISNULL(ttDataCI.Presentation, """") AS Presentation,
		|	ISNULL(ttDataCI.FieldValues, """") AS FieldValues,
		|	ISNULL(ttDataCI.OrderTypes, ttAlwaysShowKinds.OrderTypes) AS OrderTypes,
		|	ISNULL(ttDataCI.OrderKinds, ttAlwaysShowKinds.OrderKinds) AS OrderKinds
		|FROM
		|	ttAlwaysShowKinds AS ttAlwaysShowKinds
		|		FULL JOIN ttDataCI AS ttDataCI
		|		ON ttAlwaysShowKinds.Kind = ttDataCI.Kind
		|
		|ORDER BY
		|	OrderTypes,
		|	OrderKinds";
	
	Query.Text = StrReplace(Query.Text, "Catalog.Counterparties", OwnerCI.Metadata().FullName());
	Query.SetParameter("OwnerCI",		OwnerCI);
	Query.SetParameter("OrderTypes",	OrderTypesCI());
	Query.SetParameter("AlwaysShowKinds", 
		Form.ContactInformationKindProperties.Unload(New Structure("ShowInFormAlways", True), "Kind"));
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NewRow = Form.ContactInformation.Add();
		FillPropertyValues(NewRow, Selection);
		NewRow.Comment = ContactInformationManagement.ContactInformationComment(Selection.FieldValues);
	EndDo;
	
EndProcedure

Procedure InitializeForm(Form)
	
	Items = Form.Items;
	
	If Items.Find("ContactInformationValues") <> Undefined Then
		Return; // The form has already been initialized earlier
	EndIf;
	
	GroupValuesCI = Items.Add("ContactInformationValues", Type("FormGroup"), Items.ContactInformation);
	GroupValuesCI.Type				= FormGroupType.UsualGroup;
	GroupValuesCI.Title				= NStr("ru='Значения контактной информации'; en = 'Contact information values'");
	GroupValuesCI.Representation	= UsualGroupRepresentation.None;
	GroupValuesCI.Group				= ChildFormItemsGroup.Vertical;
	GroupValuesCI.ThroughAlign		= ThroughAlign.Use;
	GroupValuesCI.ShowTitle			= False;
	
	If ContactInformationSBClientServer.KindsListForAddingContactInformation(Form).Count() = 0 Then
		Return;
	EndIf;
	
	CommandName = "AddFieldContactInformation";
	Command = Form.Commands.Add(CommandName);
	Command.Title	= NStr("ru='+ телефон, адрес'; en = '+ phone, address'");
	Command.Action	= "Attachable_ContactInformationSBExecuteCommand";
	
	Button = Items.Add(CommandName, Type("FormButton"), Items.ContactInformation);
	Button.CommandName = CommandName;
	Button.ShapeRepresentation		= ButtonShapeRepresentation.None;
	Button.HorizontalAlignInGroup	= ItemHorizontalLocation.Right;
	
EndProcedure

Function IsAnotherFilledRowsKindCI(Val Form, Val CheckingRow, Val ContactInformationKind)
	
	AllRowsThisKind = Form.ContactInformation.FindRows(
		New Structure("Kind", ContactInformationKind));
	
	For Each KindRow In AllRowsThisKind Do
		
		If KindRow <> CheckingRow And Not IsBlankString(KindRow.Presentation) Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

Procedure AddContextMenuCommand(Form, CommandName, Picture, Title, ToolTip, FieldOwner)
	
	If Form.Commands.Find(CommandName) = Undefined Then
		Command = Form.Commands.Add(CommandName);
		Command.Picture	= Picture;
		Command.Title	= Title;
		Command.ToolTip	= ToolTip;
		Command.Action	= "Attachable_ContactInformationSBExecuteCommand";
	EndIf;
	
	Button = Form.Items.Add(CommandName, Type("FormButton"), FieldOwner.ContextMenu);
	Button.CommandName = CommandName;
	
EndProcedure

#EndRegion
