
#Region FormEventHadlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Если Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
	
		OnCreateOnReadAtServer();
	
		If Not IsBlankString(Parameters.FillingText) Then
			FillAttributesByFillingText(Parameters.FillingText);
		EndIf;
		
		If Parameters.AdditionalParameters.Property("OperationKind") Тогда
			Relationship = ContactsClassification.CounterpartyRelationshipTypeByOperationKind(Parameters.AdditionalParameters.OperationKind);
			FillPropertyValues(Object, Relationship, "Customer,Supplier,OtherRelationship");
		EndIf;
		
	EndIf;
	
	ErrorCounterpartyHighlightColor	= StyleColors.ErrorCounterpartyHighlightColor;
	ExecuteAllChecks(ThisObject);
	
	SetFormTitle(ThisObject);

	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributes");
	// End StandardSubsystems.Properties
	
EndProcedure // OnCreateAtServer()

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SettlementAccountsAreChanged" Then
		Object.GLAccountCustomerSettlements = Parameter.GLAccountCustomerSettlements;
		Object.CustomerAdvancesGLAccount = Parameter.CustomerAdvanceGLAccount;
		Object.GLAccountVendorSettlements = Parameter.GLAccountVendorSettlements;
		Object.VendorAdvancesGLAccount = Parameter.AdvanceGLAccountToSupplier; 
		Modified = True;
	ElsIf EventName = "SettingMainAccount" And Parameter.Owner = Object.Ref Then
		
		Object.BankAccountByDefault = Parameter.NewMainAccount;
		If Not Modified Then
			Write();
		EndIf;
		Notify("SettingMainAccountCompleted");
		
	ElsIf EventName = "SettingMainContactPerson" And Parameter.Counterparty = Object.Ref Then
		
		Object.ContactPerson = Parameter.NewMainContactPerson;
		If Not Modified Then
			Write();
		EndIf;
		Notify("SettingMainContactPersonCompleted");
		
	ElsIf EventName = "Write_ContactPerson" And Parameter.Owner = Object.Ref Then
		
		FillAndRefreshContactPersons();
		
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure // NotificationProcessing()

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	OnCreateOnReadAtServer();
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // OnReadAtServer()

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("CatalogCounterpartiesWrite");
	// End StandardSubsystems.PerformanceEstimation
	
EndProcedure //BeforeWrite()

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WriteTagsData(CurrentObject);

	// Fill main contact person
	If Not ValueIsFilled(CurrentObject.ContactPerson) Then
		For Each DataCP In ContactPersonsData Do
			If ValueIsFilled(DataCP.ContactPerson) Then
				CurrentObject.ContactPerson = DataCP.ContactPerson;
				Break;
			ElsIf Not IsBlankString(DataCP.Description) Then
				CurrentObject.ContactPerson = Catalogs.ContactPersons.GetRef();
				CurrentObject.AdditionalProperties.Insert("NewMainContactPerson", CurrentObject.ContactPerson);
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	// Fill info about contact persons for attribute "BasicInformation"
	ArrayRows = New Array;
	For Each DataCP In ContactPersonsData Do
		
		If IsBlankString(DataCP.Description) Then
			Continue;
		EndIf;
		
		If ArrayRows.Count() > 0 Then
			ArrayRows.Add(Chars.LF);
		EndIf;
		
		ArrayRows.Add(DataCP.Description);
		
		For Each DataCI In DataCP.ContactInformation Do
			If IsBlankString(DataCI.Presentation) Then
				Continue;
			EndIf;
			ArrayRows.Add(DataCI.Presentation);
		EndDo;
		
	EndDo;
	CurrentObject.AdditionalProperties.Insert("BasicInformationContactPersons", ArrayRows);
	
	// SB.ContactInformation
	ContactInformationSB.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End SB.ContactInformation
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // BeforeWriteAtServer()

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)

	WriteContactPersonsData(CurrentObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	SetFormTitle(ThisObject);
	Notify("AfterRecordingOfCounterparty", Object.Ref);
	Notify("Write_Counterparty", Object.Ref, ThisObject);
	
EndProcedure // AfterWrite()

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	FillCheckContactPersons(Cancel);
	FillCheckContactPersonsContactInformation(Cancel);
	
	// SB.ContactInformation
	ContactInformationSB.FillCheckProcessingAtServer(ThisObject, Cancel);
	// End SB.ContactInformation
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure // FillCheckProcessingAtServer()

#EndRegion

#Region FormItemsEventHadlers

&AtClient
Procedure DescriptionFullOnChange(Item)
	
	Object.DescriptionFull = StrReplace(Object.DescriptionFull, Chars.LF, " ");
	If GenerateDescriptionAutomatically Then
		Object.Description = Object.DescriptionFull;
	EndIf;
	
EndProcedure // DescriptionFullOnChange()

&AtClient
Procedure LegalEntityIndividualOnChange(Item)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure TINOnChange(Item)
	
	GenerateDuplicateChecksPresentation(ThisObject);
	
	WorkWithCounterpartiesClientServerOverridable.GenerateDataChecksPresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure DataChecksPresentationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If StrFind(FormattedStringURL, "ShowDuplicates") > 0 Then
		
		StandardProcessing = False;
		
		FormParameters = New Structure;
		FormParameters.Insert("TIN", TrimAll(Object.TIN));
		FormParameters.Insert("IsLegalEntity", IsLegalEntity(Object.LegalEntityIndividual));
		
		NotifyDescription = New NotifyDescription("ProcessingDuplicatesChoiceFormClosing", ThisObject);
		OpenForm("Catalog.Counterparties.Form.DuplicatesChoiceForm", FormParameters, Item,,,,NotifyDescription);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TagsCloudURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	TagID = Mid(FormattedStringURL, StrLen("Tag_")+1);
	TagsRow = TagsData.FindByID(TagID);
	TagsData.Delete(TagsRow);
	
	RefreshTagsItems();
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure CustomerOnChange(Item)
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure AddFieldsContactPerson(Command)
	
	DataCP = ContactPersonsData.Add();
	
	FillAlwaysShowKindsCI(
		DataCP.ContactInformation,
		ContactPersonContactInformationKindProperties);
	
	RefreshContactPersonItems();
	CurrentItem = Items["ContactDescription_" + ContactPersonsData.IndexOf(DataCP)];
	
EndProcedure

&AtClient
Procedure AddFieldContactPersonContactInformation(Command)
	
	ContactIndex	= Number(Mid(CurrentItem.Name, StrLen("AddFieldContactPersonContactInformation_")+1));
	ContactData		= ContactPersonsData[ContactIndex];
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ContactIndex", ContactIndex);
	AdditionalParameters.Insert("MultiFormOwner", NStr("ru='контактных лиц'; en = 'contact persons'"));
	NotifyDescription = New NotifyDescription("AddContactContactInformationKindSelected", ThisObject, AdditionalParameters);
	
	ListAvailableKinds = New ValueList;
	Filter = New Structure("Kind");
	For Each TableRow In ContactPersonContactInformationKindProperties Do
		Filter.Kind = TableRow.Kind;
		If TableRow.AllowMultipleValueInput Or ContactData.ContactInformation.FindRows(Filter).Count() = 0 Then
			ListAvailableKinds.Add(TableRow.Kind, TableRow.KindPresentation);
		EndIf;
	EndDo;
	
	ShowChooseFromList(NotifyDescription, ListAvailableKinds, CurrentItem);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure OnCreateOnReadAtServer()

	// 2. Reading additional information
	
	ReadContactPersonContactInformationKindProperties();
	FillContactPersonContactInformationTable();
	RefreshContactPersonItems();
	
	ReadTagsData();
	RefreshTagsItems();
	
	GenerateDescriptionAutomatically = IsBlankString(Object.Description);
	
	// SB.ContactInformation
	ContactInformationSB.OnCreateOnReadAtServer(ThisObject);
	// End SB.ContactInformation
	
EndProcedure

&AtClient
Procedure FormManagement()
	
	If Object.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyKinds.LegalEntity") Then
		Items.Individual.Visible	= False;
		Items.TIN.Visible			= True;
	ElsIf Object.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyKinds.Individual") Then
		Items.Individual.Visible	= True;
		Items.TIN.Visible			= True;
	EndIf;
	
	Items.CustomerAcquisitionChannel.Visible = Object.Customer;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetFormTitle(Form)
	
	Object = Form.Object;
	If Not ValueIsFilled(Object.Ref) Then
		Form.AutoTitle = True;
		Return;
	EndIf;
	
	Form.AutoTitle	= False;
	RelationshipKinds = New Array;
	
	If Object.Customer Then
		RelationshipKinds.Add(NStr("ru='Покупатель'; en = 'Customer'"));
	EndIf;
	
	If Object.Supplier Then
		RelationshipKinds.Add(NStr("ru='Поставщик'; en = 'Supplier'"));
	EndIf;
	
	If Object.OtherRelationship Then
		RelationshipKinds.Add(NStr("ru='Прочие отношения'; en = 'Other relationship'"));
	EndIf;
	
	Title = Object.Description + " (" + NStr("ru='Контрагент'; en = 'Counterparty'");
	
	If RelationshipKinds.Count() > 0 Then
		Title = Title + ": ";
		For Each Kind In RelationshipKinds Do
			Title = Title + Kind + ", ";
		EndDo;
		StringFunctionsClientServer.DeleteLatestCharInRow(Title, 2);
	EndIf;
	
	Title = Title + ")";
	
	Form.Title = Title;
	
EndProcedure

&AtServer
Procedure FillAttributesByFillingText(Val FillingText)
	
	Object.DescriptionFull	= FillingText;
	CurrentItem = Items.DescriptionFull;
	
	GenerateDescriptionAutomatically = True;
	Object.Description	= Object.DescriptionFull;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillAlwaysShowKindsCI(CI, ContactPersonContactInformationKindProperties)
	
	FindedRows = ContactPersonContactInformationKindProperties.FindRows(New Structure("ShowInFormAlways", True));
	
	For Each FindedRow In FindedRows Do
		
		NewRowCI = CI.Add();
		NewRowCI.Kind = FindedRow.Kind;
		NewRowCI.Type = FindedRow.Type;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ContactPersons

&AtServer
Procedure ReadContactPersonContactInformationKindProperties()
	
	Query = New Query(
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
	|	ContactInformationKinds.AdditionalOrderingAttribute");
	
	Query.SetParameter("OrderTypesCI", ContactInformationSB.OrderTypesCI());
	Query.SetParameter("GroupKindsCI", Catalogs.ContactInformationKinds.CatalogContactPersons);
	
	PropertiesTable = Query.Execute().Unload();
	ContactPersonContactInformationKindProperties.Load(PropertiesTable);
	
EndProcedure
	
&AtServer
Procedure FillAndRefreshContactPersons()
	
	FillContactPersonContactInformationTable();
	RefreshContactPersonItems();
	
EndProcedure

&AtServer
Procedure FillContactPersonContactInformationTable()
	
	ContactPersonsData.Clear();
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ContactPersons.Ref AS ContactPerson,
		|	ContactPersons.Description AS Description,
		|	ContactPersons.AdditionalOrderingAttribute
		|INTO ttContacts
		|FROM
		|	Catalog.ContactPersons AS ContactPersons
		|WHERE
		|	ContactPersons.Invalid = FALSE
		|	AND ContactPersons.Owner = &Owner
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ttContacts.ContactPerson,
		|	ttContacts.Description AS Description
		|FROM
		|	ttContacts AS ttContacts
		|
		|ORDER BY
		|	ttContacts.AdditionalOrderingAttribute,
		|	Description
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	OrderTypes.Type,
		|	OrderTypes.Order
		|INTO ttOrderTypes
		|FROM
		|	&OrderTypes AS OrderTypes
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ttContacts.ContactPerson AS ContactPerson,
		|	ContactInformationKinds.Ref AS Kind,
		|	ContactInformationKinds.Type AS Type,
		|	ContactInformationKinds.AdditionalOrderingAttribute AS OrderKinds,
		|	ttOrderTypes.Order AS OrderTypes
		|INTO ttAlwaysShowKinds
		|FROM
		|	ttContacts AS ttContacts
		|		LEFT JOIN Catalog.ContactInformationKinds AS ContactInformationKinds
		|			LEFT JOIN ttOrderTypes AS ttOrderTypes
		|			ON ContactInformationKinds.Type = ttOrderTypes.Type
		|		ON (TRUE)
		|WHERE
		|	ContactInformationKinds.Ref IN(&AlwaysShowKinds)
		|
		|INDEX BY
		|	ContactPerson,
		|	Kind
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	OwnerContactInformation.Ref AS ContactPerson,
		|	OwnerContactInformation.Kind AS Kind,
		|	OwnerContactInformation.Type,
		|	OwnerContactInformation.Presentation,
		|	OwnerContactInformation.FieldValues,
		|	OwnerContactInformation.Kind.AdditionalOrderingAttribute AS OrderKinds,
		|	ttOrderTypes.Order AS OrderTypes
		|INTO ttDataCI
		|FROM
		|	Catalog.ContactPersons.ContactInformation AS OwnerContactInformation
		|		LEFT JOIN ttOrderTypes AS ttOrderTypes
		|		ON OwnerContactInformation.Type = ttOrderTypes.Type
		|WHERE
		|	OwnerContactInformation.Ref IN
		|			(SELECT
		|				ttContacts.ContactPerson
		|			FROM
		|				ttContacts)
		|
		|INDEX BY
		|	ContactPerson,
		|	Kind
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ISNULL(ttDataCI.ContactPerson, ttAlwaysShowKinds.ContactPerson) AS ContactPerson,
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
		|			AND ttAlwaysShowKinds.ContactPerson = ttDataCI.ContactPerson
		|
		|ORDER BY
		|	OrderTypes,
		|	OrderKinds";
	
	Query.SetParameter("Owner",			Object.Ref);
	Query.SetParameter("OrderTypes",	ContactInformationSB.OrderTypesCI());
	Query.SetParameter("AlwaysShowKinds",
		ContactPersonContactInformationKindProperties.Unload(New Structure("ShowInFormAlways", True), "Kind"));
	
	ArrayResults = Query.ExecuteBatch();
	
	SelectionContacts			= ArrayResults[1].Select();
	SelectionContactInformation	= ArrayResults[5].Select();
	Filter = New Structure("ContactPerson");
	
	While SelectionContacts.Next() Do
		
		DataCP = ContactPersonsData.Add();
		FillPropertyValues(DataCP, SelectionContacts, "ContactPerson,Description");
		
		SelectionContactInformation.Reset();
		Filter.ContactPerson = SelectionContacts.ContactPerson;
		
		While SelectionContactInformation.FindNext(Filter) Do
			
			DataCI = DataCP.ContactInformation.Add();
			FillPropertyValues(DataCI, SelectionContactInformation, "Type,Kind,Presentation,FieldValues");
			DataCI.Comment = ContactInformationManagement.ContactInformationComment(SelectionContactInformation.FieldValues);
			
		EndDo;
		
	EndDo;
	
	// There is always a field to fill in a contact person
	If ContactPersonsData.Count() = 0 Then
		
		DataCP = ContactPersonsData.Add();
		FillAlwaysShowKindsCI(
			DataCP.ContactInformation,
			ContactPersonContactInformationKindProperties);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshContactPersonItems()
	
	Items.Move(Items.AddFieldsContactPerson, Items.ContactAddingCommands_0);
	Items.AddingCommandsStretching_0.MaxWidth	= 41;
	
	DeletingItems = New Array;
	// The group of first contact person is created in the configurator
	For GroupIndex = 1 To Items.AllContacts.ChildItems.Count()-1 Do
		DeletingItems.Add(Items.AllContacts.ChildItems[GroupIndex]);
	EndDo;
	For Each GroupCI In Items.ContactContactInformation_0.ChildItems Do
		DeletingItems.Add(GroupCI);
	EndDo;
	For Each DeletingItem In DeletingItems Do
		Items.Delete(DeletingItem);
	EndDo;
	
	WidthKindCI			= 8;
	WidthCommentField	= 11;
	
	For Each ContactPersonData In ContactPersonsData Do
		
		ContactIndex = ContactPersonsData.IndexOf(ContactPersonData);
		
		// For the first contact person form items are created in the configurator
		If ContactIndex > 0 Then
			
			GroupContactPerson = Items.Add("Contact_" + ContactIndex, Type("FormGroup"), Items.AllContacts);
			GroupContactPerson.Type				= FormGroupType.UsualGroup;
			GroupContactPerson.Representation	= UsualGroupRepresentation.None;
			GroupContactPerson.Group			= ChildFormItemsGroup.Vertical;
			GroupContactPerson.ShowTitle		= False;
			
			FieldDescription = Items.Add("ContactDescription_" + ContactIndex, Type("FormField"), GroupContactPerson);
			FieldDescription.Type			= FormFieldType.InputField;
			FieldDescription.DataPath		= "ContactPersonsData[" + ContactIndex + "].Description";
			FieldDescription.TitleLocation	= FormItemTitleLocation.None;
			FieldDescription.InputHint		= NStr("ru='Имя Фамилия'; en = 'Name Surname'");
			FieldDescription.AutoMaxWidth	= False;
			FieldDescription.MaxWidth		= 52;
			
			GroupCI = Items.Add("ContactContactInformation_" + ContactIndex, Type("FormGroup"), GroupContactPerson);
			GroupCI.Type			= FormGroupType.UsualGroup;
			GroupCI.Representation	= UsualGroupRepresentation.None;
			GroupCI.Group			= ChildFormItemsGroup.Vertical;
			GroupCI.ShowTitle		= False;
			
			GroupAdding = Items.Add("ContactAddingCommands_" + ContactIndex, Type("FormGroup"), GroupContactPerson);
			GroupAdding.Type		= FormGroupType.UsualGroup;
			GroupAdding.Отображение	= UsualGroupRepresentation.None;
			GroupAdding.Группировка	= ChildFormItemsGroup.Horizontal;
			GroupAdding.ShowTitle	= False;
			
			DecorationStretching = Items.Add("AddingCommandsStretching_" + ContactIndex, Type("FormDecoration"), GroupAdding);
			DecorationStretching.Type				= FormDecorationType.Label;
			DecorationStretching.AutoMaxWidth		= False;
			DecorationStretching.MaxWidth			= 41;
			//DecorationStretching.HorizontalStretch	= True;
			
			Button = Items.Add("AddFieldContactPersonContactInformation_" + ContactIndex, Type("FormButton"), GroupAdding);
			Button.CommandName				= "AddFieldContactPersonContactInformation";
			Button.ShapeRepresentation		= ButtonShapeRepresentation.None;
			Button.HorizontalAlignInGroup	= ItemHorizontalLocation.Right;
			
		Else
			
			GroupCI = Items.ContactContactInformation_0;
			
		EndIf;
		
		Filter = New Structure("Kind");
		
		For Each DataCI In ContactPersonData.ContactInformation Do
			
			IndexCI = ContactPersonData.ContactInformation.IndexOf(DataCI);
			Filter.Kind	= DataCI.Kind;
			FindedRows	= ContactPersonContactInformationKindProperties.FindRows(Filter);
			If FindedRows.Count() = 0 Then
				Continue;
			EndIf;
			KindProperties = FindedRows[0];
			
			GroupValueCI = Items.Add("Contact_" + ContactIndex + "_CI_" + IndexCI, Type("FormGroup"), GroupCI);
			GroupValueCI.Type			= FormGroupType.UsualGroup;
			GroupValueCI.Title			= DataCI.Kind;
			GroupValueCI.Representation	= UsualGroupRepresentation.None;
			GroupValueCI.Group			= ChildFormItemsGroup.Horizontal;
			GroupValueCI.ShowTitle		= False;
			
			DecorationAction = Items.Add("ContactAction_" + ContactIndex + "_CI_" + IndexCI, Type("FormDecoration"), GroupValueCI);
			DecorationAction.Type					= FormDecorationType.Picture;
			DecorationAction.Picture				= ContactInformationSB.ActionPictureByContactInformationType(DataCI.Type);
			DecorationAction.Hyperlink				= True;
			DecorationAction.Width					= 2;
			DecorationAction.Height					= 1;
			DecorationAction.VerticalAlignInGroup	= ItemVerticalAlign.Center;
			DecorationAction.SetAction("Click", "Attachable_ContactActionCIClick");
			
			FieldKind = Items.Add("ContactKind_" + ContactIndex + "_CI_" + IndexCI, Type("FormField"), GroupValueCI);
			FieldKind.Type				= FormFieldType.LabelField;
			FieldKind.DataPath			= "ContactPersonsData[" + ContactIndex + "].ContactInformation[" + IndexCI + "].Kind";
			FieldKind.TitleLocation		= FormItemTitleLocation.None;
			FieldKind.Width				= WidthKindCI;
			FieldKind.HorizontalStretch	= False;
			
			EditInDialogAvailable = ContactInformationSB.ForContactInformationTypeIsAvailableEditInDialog(DataCI.Type);
			
			FieldPresentation = Items.Add("ContactPresentation_" + ContactIndex + "_CI_" + IndexCI, Type("FormField"), GroupValueCI);
			FieldPresentation.Type					= FormFieldType.InputField;
			FieldPresentation.DataPath				= "ContactPersonsData[" + ContactIndex + "].ContactInformation[" + IndexCI + "].Presentation";
			FieldPresentation.TitleLocation			= FormItemTitleLocation.None;
			FieldPresentation.ChoiceButton			= EditInDialogAvailable;
			FieldPresentation.AutoMarkIncomplete	= KindProperties.Mandatory;
			FieldPresentation.DropListWidth			= 40;
			FieldPresentation.SetAction("OnChange", "Attachable_ContactPresentationCIOnChange");
			FieldPresentation.SetAction("Clearing", "Attachable_ContactPresentationCIClearing");
			If KindProperties.EditInDialogOnly Then
				FieldPresentation.TextEdit	= False;
				FieldPresentation.BackColor	= StyleColors.ContactInformationWithEditingInDialogColor;
			EndIf;
			If EditInDialogAvailable Then
				FieldPresentation.SetAction("StartChoice", "Attachable_ContactPresentationCIStartChoice");
			EndIf;
			If DataCI.Type = Enums.ContactInformationTypes.Other Then
				FieldPresentation.MultiLine			= True;
				FieldPresentation.Height			= 2;
				FieldPresentation.VerticalStretch	= False;
			EndIf;
			
			If ContactInformationSB.ForContactInformationTypeIsAvailableCommentInput(DataCI.Type) Then
				
				FieldPresentation.AutoMaxWidth	= False;
				FieldPresentation.MaxWidth		= 27;
				
				FieldComment = Items.Add("ContactComment_" + ContactIndex + "_CI_" + IndexCI, Type("FormField"), GroupValueCI);
				FieldComment.Type			= FormFieldType.InputField;
				FieldComment.DataPath		= "ContactPersonsData[" + ContactIndex + "].ContactInformation[" + IndexCI + "].Comment";
				FieldComment.TitleLocation	= FormItemTitleLocation.None;
				FieldComment.SkipOnInput	= True;
				FieldComment.InputHint		= NStr("ru='Прим.'; en = 'Note'");
				FieldComment.AutoMaxWidth	= False;
				FieldComment.MaxWidth		= WidthCommentField;
				FieldComment.SetAction("OnChange", "Attachable_ContactCommentCIOnChange");
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	FillChoiceListContactPersonsAddresses(ThisObject);
	
	IndexLastCP	= ContactPersonsData.Count()-1;
	AddingCommandCI	= Items["AddFieldContactPersonContactInformation_" + IndexLastCP];
	Items.Move(Items.AddFieldsContactPerson, AddingCommandCI.Parent, AddingCommandCI);
	Items["AddingCommandsStretching_" + IndexLastCP].MaxWidth	= 10;
	
EndProcedure

&AtServer
Procedure FillCheckContactPersons(Cancel)
	
	// Check filling contact person name, if contact information is filled
	For Each ContactPersonData In ContactPersonsData Do
		
		If Not IsBlankString(ContactPersonData.Description) Then
			Continue;
		EndIf;
		
		AttributeName = "ContactPersonsData[" + ContactPersonsData.IndexOf(ContactPersonData) + "].Description";
		For Each TableRow In ContactPersonData.ContactInformation Do
			If Not IsBlankString(TableRow.FieldValues) Or Not IsBlankString(TableRow.Presentation) Then
				CommonUseClientServer.MessageToUser(NStr("ru = 'ФИО контакта не заполнено.'; en = 'Contact name is not filled'"),,,AttributeName, Cancel);
				Break;
			EndIf;
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillCheckContactPersonsContactInformation(Cancel)
	
	IsError = False;
	Filter = New Structure("Kind");
	
	For Each ContactPersonData In ContactPersonsData Do
		
		If IsBlankString(ContactPersonData.Description) Then
			Continue;
		EndIf;
		
		ContactPersonIndex = ContactPersonsData.IndexOf(ContactPersonData);
		
		For Each TableRow In ContactPersonData.ContactInformation Do
			
			Filter.Kind = TableRow.Kind;
			FindedRows = ContactPersonContactInformationKindProperties.FindRows(Filter);
			If FindedRows.Count() = 0 Then
				Continue;
			EndIf;
			KindProperties = FindedRows[0];
			Index = ContactPersonData.ContactInformation.IndexOf(TableRow);
			AttributeName = "ContactPersonsData["+ContactPersonIndex+"].ContactInformation["+Index+"].Presentation";
			
			If KindProperties.Mandatory And IsBlankString(TableRow.Presentation)
				And Not IsAnotherFilledRowsKindCI(ContactPersonData, TableRow, TableRow.Kind) Then
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
					If Not ContactInformationSB.EmailIsCorrect(ObjectCI, AttributeName) Then
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
		
	EndDo;
	
	If IsError Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServer
Function IsAnotherFilledRowsKindCI(Val ContactPersonData, Val CheckingRow, Val ContactInformationKind)
	
	AllRowsThisKind = ContactPersonData.ContactInformation.FindRows(
		New Structure("Kind", ContactInformationKind));
	
	For Each KindRow In AllRowsThisKind Do
		
		If KindRow <> CheckingRow And Not IsBlankString(KindRow.Presentation) Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

&AtServer
Procedure WriteContactPersonsData(CurrentObject)
	
	For Each DataCP In ContactPersonsData Do
		
		If IsBlankString(DataCP.Description) Then
			Continue;
		EndIf;
		
		SetPrivilegedMode(True);
		
		If ValueIsFilled(DataCP.ContactPerson) Then
			ContactPersonObject = DataCP.ContactPerson.GetObject();
		EndIf;
		
		If Not ValueIsFilled(DataCP.ContactPerson) Or ContactPersonObject = Undefined Then
			
			// Creating
			ContactPersonObject = Catalogs.ContactPersons.CreateItem();
			ContactPersonObject.Fill(CurrentObject.Ref);
			ItemOrderSetup.FillOrderingAttributeValue(ContactPersonObject, False);
			
			// Set ref of new by primary contact person
			If CurrentObject.AdditionalProperties.Property("NewMainContactPerson") Then
				ContactPersonObject.SetNewObjectRef(CurrentObject.AdditionalProperties.NewMainContactPerson);
				CurrentObject.AdditionalProperties.Delete("NewMainContactPerson");
			EndIf;
			
		EndIf;
		
		// editing
		FillPropertyValues(ContactPersonObject, DataCP, "Description");
		ContactPersonObject.ContactInformation.Clear();
		For Each DataCI In DataCP.ContactInformation Do
			ContactInformationManagement.WriteContactInformation(ContactPersonObject, DataCI.FieldValues, DataCI.Kind, DataCI.Type);
		EndDo;
		
		// Write object
		ContactPersonObject.Write();
		
		// Saving the ref to the created object
		DataCP.ContactPerson = ContactPersonObject.Ref;
		
		SetPrivilegedMode(False);
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillChoiceListContactPersonsAddresses(Form) Export
	
	ArrayAddresses = New Array;
	Filter = New Structure("Kind");
	
	For Each ContactPersonData In Form.ContactPersonsData Do
		For Each TableRow In ContactPersonData.ContactInformation Do
			
			If TableRow.Type <> PredefinedValue("Enum.ContactInformationTypes.Address") Then
				Continue;
			EndIf;
			
			Filter.Kind = TableRow.Kind;
			FindedRows = Form.ContactPersonContactInformationKindProperties.FindRows(Filter);
			If FindedRows.Count() = 0 Then
				Continue;
			EndIf;
			
			If Not IsBlankString(TableRow.Presentation)
				And ArrayAddresses.Find(TableRow.Presentation) = Undefined Then
				
				ArrayAddresses.Add(TableRow.Presentation);
			EndIf;
			
		EndDo;
	EndDo;
	
	For Each ContactPersonData In Form.ContactPersonsData Do
		For Each TableRow In ContactPersonData.ContactInformation Do
			
			If TableRow.Type <> PredefinedValue("Enum.ContactInformationTypes.Address") Then
				Continue;
			EndIf;
			
			Filter.Kind = TableRow.Kind;
			FindedRows = Form.ContactPersonContactInformationKindProperties.FindRows(Filter);
			If FindedRows.Count() = 0 Then
				Continue;
			EndIf;
			
			FieldName = "ContactPresentation_" + Form.ContactPersonsData.IndexOf(ContactPersonData) + "_CI_" + ContactPersonData.ContactInformation.IndexOf(TableRow);
			FieldPresentation = Form.Items[FieldName];
			FieldPresentation.ChoiceList.LoadValues(ArrayAddresses);
			
			FieldPresentation.DropListButton = FieldPresentation.ChoiceList.Count() > 0;
			
		EndDo;
	EndDo;
	
EndProcedure

&AtClient
Процедура AddContactContactInformationKindSelected(SelectedItem, AdditionalParameters) Export
	
	If SelectedItem = Undefined Then
		Return;
	EndIf;
	
	Filter = New Structure("Kind", SelectedItem.Value);
	FindedRows = ContactPersonContactInformationKindProperties.FindRows(Filter);
	If FindedRows.Count() = 0 Then
		Return;
	EndIf;
	KindProperties = FindedRows[0];
	
	If KindProperties.ShowInFormAlways = False Then
		
		AdditionalParameters.Insert("AddingKind", SelectedItem.Value);
		NotifyDescription = New NotifyDescription("AddContactContactInformationQuestionAsked", ThisObject, AdditionalParameters);
		
		QuestionText = StrTemplate(NStr("ru='Возможность ввода ""%1"" будет добавлена для всех %2.
			|Продолжить?'; en = 'The ability to input ""%1"" will be added to all %2.
			|Continue?'"), SelectedItem.Value, AdditionalParameters.MultiFormOwner);
		QuestionTitle = NStr("ru='Подтверждение добавления'; en = 'Confirm adding'");
		
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.OKCancel, , DialogReturnCode.OK, QuestionTitle);
		
	Else
		
		AddContactContactInformationServer(SelectedItem.Value, AdditionalParameters.ContactIndex);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddContactContactInformationQuestionAsked(QuestionResult, AdditionalParameters) Export 
	
	If QuestionResult <> DialogReturnCode.OK Then
		Return;
	EndIf;
	
	AddContactContactInformationServer(AdditionalParameters.AddingKind, AdditionalParameters.ContactIndex, True);
	
EndProcedure

&AtServer
Procedure AddContactContactInformationServer(AddingKind, ContactIndex, SetShowInFormAlways = False)
	
	AddingType = CommonUse.ObjectAttributeValue(AddingKind, "Type");
	ContactData = ContactPersonsData[ContactIndex];
	
	NumberCollectionItems = ContactData.ContactInformation.Count();
	InsertIndex = NumberCollectionItems;
	
	For ReverseIndex = 1 To NumberCollectionItems Do
		CurrentIndex = NumberCollectionItems - ReverseIndex;
		If ContactData.ContactInformation[CurrentIndex].Kind = AddingKind Then
			InsertIndex = CurrentIndex+1;
			Break;
		EndIf;
	EndDo;
	
	DataCI = ContactData.ContactInformation.Insert(InsertIndex);
	DataCI.Kind = AddingKind;
	DataCI.Type = AddingType;
	
	If SetShowInFormAlways Then
		
		ContactInformationSB.SetFlagShowInFormAlways(AddingKind);
		
		FindedRows = ContactPersonContactInformationKindProperties.FindRows(New Structure("Kind", AddingKind));
		If FindedRows.Count() > 0 Then
			FindedRows[0].ShowInFormAlways = True;
		EndIf;
		
		For CurrentIndex = 0 To ContactPersonsData.Count()-1 Do
			
			If CurrentIndex = ContactIndex Then
				Continue;
			EndIf;
			
			DataCI = ContactPersonsData[CurrentIndex].ContactInformation.Add();
			DataCI.Kind = AddingKind;
			DataCI.Type = AddingType;
			
		EndDo;
		
	EndIf;
	
	RefreshContactPersonItems();
	CurrentItem = Items["ContactPresentation_" + ContactIndex + "_CI_" + InsertIndex];
	
EndProcedure

&AtClient
Procedure Attachable_ContactActionCIClick(Item)
	
	PositionUnderscoreOne	= StrFind(Item.Name, "_",,,1);
	PositionUnderscoreTwo	= StrFind(Item.Name, "_",,,2);
	PositionUnderscoreThree	= StrFind(Item.Name, "_",,,3);
	
	IndexCP = Number(Mid(Item.Name, PositionUnderscoreOne+1, PositionUnderscoreTwo-PositionUnderscoreOne-1));
	IndexCI = Number(Mid(Item.Name, PositionUnderscoreThree+1));
	
	DataCI = ContactPersonsData[IndexCP].ContactInformation[IndexCI];
	
	If DataCI.Type = PredefinedValue("Enum.ContactInformationTypes.Skype") Then
		
		AdditionalParameters = New Structure("LoginSkype");
		AdditionalParameters.LoginSkype = DataCI.Presentation;
		List = New ValueList;
		List.Add("Call", NStr("ru = 'Позвонить'; en = 'Call'"));
		List.Add("StartChat", NStr("ru = 'Начать чат'; en = 'Start chat'"));
		NotifyDescription = New NotifyDescription("AfterSelectionFromMenuSkype", ContactInformationManagementClient, AdditionalParameters);
		ThisObject.ShowChooseFromMenu(NotifyDescription, List, Item);
		Return;
		
	EndIf;
	
	FillBasis = New Structure("Contact", ContactPersonsData[IndexCP].ContactPerson);
	
	FillingValues = New Structure("EventType,FillBasis", 
		ContactInformationSBClient.EventTypeByContactInformationType(DataCI.Type),
		FillBasis);
		
	FormParameters = New Structure("FillingValues", FillingValues);
	OpenForm("Document.Event.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_ContactPresentationCIOnChange(Item)
	
	PositionUnderscoreOne	= StrFind(Item.Name, "_",,,1);
	PositionUnderscoreTwo	= StrFind(Item.Name, "_",,,2);
	PositionUnderscoreThree	= StrFind(Item.Name, "_",,,3);
	
	IndexCP = Number(Mid(Item.Name, PositionUnderscoreOne+1, PositionUnderscoreTwo-PositionUnderscoreOne-1));
	IndexCI = Number(Mid(Item.Name, PositionUnderscoreThree+1));
	
	DataCI = ContactPersonsData[IndexCP].ContactInformation[IndexCI];
	
	If IsBlankString(DataCI.Presentation) Then
		DataCI.FieldValues = "";
	Else
		DataCI.FieldValues = ContactInformationSBServerCall.ContactInformationXMLByPresentation(DataCI.Presentation, DataCI.Kind);
	EndIf;
	
	If DataCI.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		FillChoiceListContactPersonsAddresses(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ContactPresentationCIStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	PositionUnderscoreOne	= StrFind(Item.Name, "_",,,1);
	PositionUnderscoreTwo	= StrFind(Item.Name, "_",,,2);
	PositionUnderscoreThree	= StrFind(Item.Name, "_",,,3);
	
	IndexCP = Number(Mid(Item.Name, PositionUnderscoreOne+1, PositionUnderscoreTwo-PositionUnderscoreOne-1));
	IndexCI = Number(Mid(Item.Name, PositionUnderscoreThree+1));
	
	DataCI = ContactPersonsData[IndexCP].ContactInformation[IndexCI];
	
	// If the presentation was changed in the field and does not match the requisites, then brought into conformity.
	If DataCI.Presentation <> Item.EditText Then
		DataCI.Presentation = Item.EditText;
		Attachable_ContactPresentationCIOnChange(Item);
		Modified = True;
	EndIf;
	
	FormParameters = ContactInformationManagementClient.ContactInformationFormParameters(
						DataCI.Kind,
						DataCI.FieldValues,
						DataCI.Presentation,
						DataCI.Comment);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("IndexCP", IndexCP);
	AdditionalParameters.Insert("IndexCI", IndexCI);
	
	NotifyDescription = New NotifyDescription("ContactValueCIEditingInDialogCompleted", ThisObject, AdditionalParameters);
	
	ContactInformationManagementClient.OpenContactInformationForm(FormParameters,,,, NotifyDescription);
	
EndProcedure

&AtClient
Procedure Attachable_ContactPresentationCIClearing(Item, StandardProcessing)
	
	PositionUnderscoreOne	= StrFind(Item.Name, "_",,,1);
	PositionUnderscoreTwo	= StrFind(Item.Name, "_",,,2);
	PositionUnderscoreThree	= StrFind(Item.Name, "_",,,3);
	
	IndexCP = Number(Mid(Item.Name, PositionUnderscoreOne+1, PositionUnderscoreTwo-PositionUnderscoreOne-1));
	IndexCI = Number(Mid(Item.Name, PositionUnderscoreThree+1));
	
	DataCI = ContactPersonsData[IndexCP].ContactInformation[IndexCI];
	DataCI.FieldValues = "";
	
	If DataCI.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		FillChoiceListContactPersonsAddresses(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ContactCommentCIOnChange(Item)
	
	PositionUnderscoreOne	= StrFind(Item.Name, "_",,,1);
	PositionUnderscoreTwo	= StrFind(Item.Name, "_",,,2);
	PositionUnderscoreThree	= StrFind(Item.Name, "_",,,3);
	
	IndexCP = Number(Mid(Item.Name, PositionUnderscoreOne+1, PositionUnderscoreTwo-PositionUnderscoreOne-1));
	IndexCI = Number(Mid(Item.Name, PositionUnderscoreThree+1));
	
	DataCI = ContactPersonsData[IndexCP].ContactInformation[IndexCI];
	
	ExpectedKind = ?(IsBlankString(DataCI.FieldValues), DataCI.Kind, Undefined);
	ContactInformationSBServerCall.SetContactInformationComment(DataCI.FieldValues, DataCI.Comment, ExpectedKind);
	
EndProcedure

&AtClient
Procedure ContactValueCIEditingInDialogCompleted(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) <> Type("Structure") Then
		Return;
	EndIf;
	
	DataCI = ContactPersonsData[AdditionalParameters.IndexCP].ContactInformation[AdditionalParameters.IndexCI];
	
	DataCI.Presentation	= ClosingResult.Presentation;
	DataCI.FieldValues	= ClosingResult.ContactInformation;
	DataCI.Comment		= ClosingResult.Comment;
	
	Modified = True;
	
	If DataCI.Type = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		FillChoiceListContactPersonsAddresses(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#Region Tags

&AtServer
Procedure ReadTagsData()
	
	TagsData.Clear();
	
	If Not ValueIsFilled(Object.Ref) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	CounterpartiesTags.Tag AS Tag,
		|	CounterpartiesTags.Tag.DeletionMark AS DeletionMark,
		|	CounterpartiesTags.Tag.Description AS Description
		|FROM
		|	Catalog.Counterparties.Tags AS CounterpartiesTags
		|WHERE
		|	CounterpartiesTags.Ref = &Ref";
	
	Query.SetParameter("Ref", Object.Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		NewTagData	= TagsData.Add();
		URLFS	= "Tag_" + NewTagData.GetID();
		
		NewTagData.Tag				= Selection.Tag;
		NewTagData.DeletionMark		= Selection.DeletionMark;
		NewTagData.TagPresentation	= FormattedStringTagPresentation(Selection.Description, Selection.DeletionMark, URLFS);
		NewTagData.TagLength		= StrLen(Selection.Description);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshTagsItems()
	
	FS = TagsData.Unload(, "TagPresentation").UnloadColumn("TagPresentation");
	
	Index = FS.Count()-1;
	While Index > 0 Do
		FS.Insert(Index, "  ");
		Index = Index - 1;
	EndDo;
	
	Items.TagsCloud.Title	= New FormattedString(FS);
	Items.TagsCloud.Visible	= FS.Count() > 0;
	
EndProcedure

&AtServer
Procedure WriteTagsData(CurrentObject)
	
	CurrentObject.Tags.Load(TagsData.Unload(,"Tag"));
	
EndProcedure

&AtServer
Procedure AttachTagAtServer(Tag)
	
	If TagsData.FindRows(New Structure("Tag", Tag)).Count() > 0 Then
		Return;
	EndIf;
	
	TagData = CommonUse.ObjectAttributesValues(Tag, "Description, DeletionMark");
	
	TagsRow = TagsData.Add();
	URLFS = "Tag_" + TagsRow.GetID();
	
	TagsRow.Tag = Tag;
	TagsRow.DeletionMark = TagData.DeletionMark;
	TagsRow.TagPresentation = FormattedStringTagPresentation(TagData.Description, TagData.DeletionMark, URLFS);
	TagsRow.TagLength = StrLen(TagData.Description);
	
	RefreshTagsItems();
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure CreateAndAttachTagAtServer(Val TagTitle)
	
	Tag = FindCreateTag(TagTitle);
	AttachTagAtServer(Tag);
	
EndProcedure

&AtServerNoContext
Function FindCreateTag(Val TagTitle)
	
	Tag = Catalogs.Tags.FindByDescription(TagTitle, True);
	
	If Tag.IsEmpty() Then
		
		TagObject = Catalogs.Tags.CreateItem();
		TagObject.Description = TagTitle;
		TagObject.Write();
		Tag = TagObject.Ref;
		
	EndIf;
	
	Return Tag;
	
EndFunction

&AtClientAtServerNoContext
Function FormattedStringTagPresentation(TagDescription, DeletionMark, URLFS)
	
	#If Client Then
	Color		= CommonUseClientReUse.StyleColor("MinorInscriptionText");
	BaseFont	= CommonUseClientReUse.StyleFont("NormalTextFont");
	#Else
	Color		= StyleColors.MinorInscriptionText;
	BaseFont	= StyleFonts.NormalTextFont;
	#EndIf
	
	Font	= New Font(BaseFont,,,True,,?(DeletionMark, True, Undefined));
	
	ComponentsFS = New Array;
	ComponentsFS.Add(New FormattedString(TagDescription + Chars.NBSp, Font, Color));
	ComponentsFS.Add(New FormattedString(PictureLib.Clear, , , , URLFS));
	
	Return New FormattedString(ComponentsFS);
	
EndFunction

&AtClient
Procedure TagInputFieldChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If TypeOf(SelectedValue) = Type("CatalogRef.Tags") Then
		AttachTagAtServer(SelectedValue);
	EndIf;
	Item.UpdateEditText();
	
EndProcedure

&AtClient
Procedure TagInputFieldTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	
	If Not IsBlankString(Text) Then
		StandardProcessing = False;
		CreateAndAttachTagAtServer(Text);
		CurrentItem = Items.TagInputField;
	EndIf;
	
EndProcedure

#EndRegion

#Region CounterpartiesChecks

&AtClientAtServerNoContext
Procedure ExecuteAllChecks(Form)
	
	GenerateDuplicateChecksPresentation(Form);
	
	WorkWithCounterpartiesClientServerOverridable.GenerateDataChecksPresentation(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateDuplicateChecksPresentation(Form)
	
	Object = Form.Object;
	ErrorDescription = "";
	
	If Not IsBlankString(Object.TIN) Then
		
		DuplicatesArray = GetCounterpartyDuplicatesServer(TrimAll(Object.TIN), Object.Ref);
		
		DuplicatesNumber = DuplicatesArray.Count();
		
		If DuplicatesNumber > 0 Then
			
			DuplicatesMessageParametersStructure = New Structure;
			DuplicatesMessageParametersStructure.Insert("TIN", НСтр("ru = 'ИНН'; en = 'TIN'"));
			
			If DuplicatesNumber = 1 Then
				DuplicatesMessageParametersStructure.Insert("DuplicatesNumber", NStr("ru = 'один'; en = 'one'"));
				DuplicatesMessageParametersStructure.Insert("CounterpartyDeclension", NStr("ru = 'контрагент'; en = 'counterparty'"));
			ElsIf DuplicatesNumber < 5 Then
				DuplicatesMessageParametersStructure.Insert("DuplicatesNumber", DuplicatesNumber);
				DuplicatesMessageParametersStructure.Insert("CounterpartyDeclension", NStr("ru = 'контрагента'; en = 'counterparties'"));
			Else
				DuplicatesMessageParametersStructure.Insert("DuplicatesNumber", DuplicatesNumber);
				DuplicatesMessageParametersStructure.Insert("CounterpartyDeclension", NStr("ru = 'контрагентов'; en = 'counterparties'"));
			EndIf;
			
			ErrorDescription = NStr("ru = 'С таким [ИННиКПП] есть [DuplicatesNumber] [CounterpartyDeclension]'; en = 'With such [TIN] there are [DuplicatesNumber] [CounterpartyDeclension]'");
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(ErrorDescription, DuplicatesMessageParametersStructure);
			
		EndIf;
	EndIf;
	
	Form.DuplicateChecksPresentation = New FormattedString(ErrorDescription, , Form.ErrorCounterpartyHighlightColor, , "ShowDuplicates");
	
КонецПроцедуры

&AtServerNoContext
Function GetCounterpartyDuplicatesServer(TIN, ExcludingRef)
	
	Return Catalogs.Counterparties.CheckCatalogDuplicatesCounterpartiesByTIN(TIN, ExcludingRef);
	
EndFunction

&AtClientAtServerNoContext
Function IsLegalEntity(CounterpartyKind)
	
	Return CounterpartyKind = PredefinedValue("Enum.CounterpartyKinds.LegalEntity");
	
EndFunction

#EndRegion

#Region CounterpartyContactInformationSB

&AtServer
Procedure AddContactInformationServer(AddingKind, SetShowInFormAlways = False) Export
	
	ContactInformationSB.AddContactInformation(ThisObject, AddingKind, SetShowInFormAlways);
	
EndProcedure

&AtClient
Procedure Attachable_ActionCIClick(Item)
	
	ContactInformationSBClient.ActionCIClick(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIOnChange(Item)
	
	ContactInformationSBClient.PresentationCIOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIStartChoice(Item, ChoiceData, StandardProcessing)
	
	ContactInformationSBClient.PresentationCIStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIClearing(Item, StandardProcessing)
	
	ContactInformationSBClient.PresentationCIClearing(ThisObject, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_CommentCIOnChange(Item)
	
	ContactInformationSBClient.CommentCIOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationSBExecuteCommand(Command)
	
	ContactInformationSBClient.ExecuteCommand(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
	
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisObject, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure // Attachable_EditPropertyContent()

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure // UpdateAdditionalAttributeItems()

// End StandardSubsystems.Properties

#EndRegion
