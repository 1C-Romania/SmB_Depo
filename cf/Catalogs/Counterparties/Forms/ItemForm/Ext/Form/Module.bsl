
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
	
	If Object.LegalEntityIndividual = Enums.CounterpartyKinds.Individual Then
		Items.DescriptionFull.Title	= NStr("ru = 'Фамилия, имя, отчество'; en = 'Name, surname'");
	Else
		Items.DescriptionFull.Title	= NStr("ru = 'Публичное наименование'; en = 'Legal name'");
	EndIf;
	
	ErrorCounterpartyHighlightColor	= StyleColors.ErrorCounterpartyHighlightColor;
	ExecuteAllChecks(ThisObject);
	
	SetFormTitle(ThisObject);

	SmallBusinessClientServer.SetPictureForComment(Items.GroupComment, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "GroupAdditionalAttributes");
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

	// SB.ContactInformation
	ContactInformationSB.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End SB.ContactInformation
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // BeforeWriteAtServer()

&AtClient
Procedure AfterWrite(WriteParameters)
	
	SetFormTitle(ThisObject);
	Notify("AfterRecordingOfCounterparty", Object.Ref);
	Notify("Write_Counterparty", Object.Ref, ThisObject);
	
EndProcedure // AfterWrite()

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	SmallBusinessClientServer.SetPictureForComment(Items.GroupComment, Object.Comment);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
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
	
	IsIndividual = Object.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyKinds.Individual");
	
	Items.GroupIndividual.Visible	= IsIndividual;
	Items.LegalForm.Visible			= Not IsIndividual;
	
	If IsIndividual Then
		Items.DescriptionFull.Title	= NStr("ru = 'Фамилия, имя, отчество'; en = 'Name, surname'");
	Else
		Items.DescriptionFull.Title	= NStr("ru = 'Публичное наименование'; en = 'Legal name'");
	EndIf;
	
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

#Region ServiceProceduresAndFunctions

&AtServer
Procedure OnCreateOnReadAtServer()

	// 2. Reading additional information
	
	ReadTagsData();
	RefreshTagsItems();
	
	GenerateDescriptionAutomatically = IsBlankString(Object.Description);
	
	// SB.ContactInformation
	ContactInformationSB.OnCreateOnReadAtServer(ThisObject);
	// End SB.ContactInformation
	
EndProcedure

&AtClient
Procedure FormManagement()
	
	IsIndividual = Object.LegalEntityIndividual = PredefinedValue("Enum.CounterpartyKinds.Individual");
	
	Items.GroupIndividual.Visible	= IsIndividual;
	Items.LegalForm.Visible			= Not IsIndividual;
	
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
	
	If RelationshipKinds.Count() > 0 Then
		Title = Object.Description + " (";
		For Each Kind In RelationshipKinds Do
			Title = Title + Kind + ", ";
		EndDo;
		StringFunctionsClientServer.DeleteLatestCharInRow(Title, 2);
	Else	
		Title = Object.Description + " (" + NStr("ru='Контрагент'; en = 'Counterparty'");
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
