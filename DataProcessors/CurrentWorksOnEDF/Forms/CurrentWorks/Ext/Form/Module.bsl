
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UseDS = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
															"UseDigitalSignatures");
	
	InitializeTree();
	
	If Not ElectronicDocumentsService.ImmediateEDSending() Then
		Items.CommandSign.Title = NStr("en = 'Sign'");
		Items.GenerateSignAndSend.Title = NStr("en = 'Approve and sign'");
		Commands.ApproveSignAndSend.ToolTip = NStr("en = 'Approve, sign and prepare
																	|the selected electronic documents for sending'");
		If Not UseDS Then
			Items.GenerateSignAndSend.Title = NStr("en = 'Approve'");
			Commands.ApproveSignAndSend.ToolTip = NStr("en = 'Approve and prepare
																		|the selected electronic documents for sending'");
		EndIf;
	ElsIf Not UseDS Then
		Items.GenerateSignAndSend.Title = NStr("en = 'Approve and send'");
		Commands.ApproveSignAndSend.ToolTip = NStr("en = 'Approve
																	|and prepare the selected electronic documents'");
	EndIf;

	Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
	
	GenerateTableRapidFilter();
	
	Items.PageSign.Visible = UseDS;
		
	Filters = CommonUse.CommonSettingsStorageImport(FormName, "Filters", New ValueTable);
	
	For Each FilterItem IN Filters Do
		For Each CollectionItem IN QuickFilters Do
			If FilterItem.Parameter = CollectionItem.Parameter Then
				FillPropertyValues(CollectionItem, FilterItem);
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	If Filters.Count() > 0 Then
		SetDynamicListFilters(ThisObject, Filters);
	EndIf;
	
	If Not ElectronicDocumentsServiceCallServer.IsRightToProcessED(False) Then
		Items.SendPackages.Visible                              = False;
		Items.CommandSign.Visible                             = False;
		Items.CommandApproveED.Visible                           = False;
		Items.SendAndReceiveED.Visible                         = False;
		Items.TableGenerateED.Visible                        = False;
		Items.UnpackSelectedPackages.Visible                  = False;
		Items.GenerateSignAndSend.Visible              = False;
		Items.GenerateCloseForcedly.Visible             = False;
		Items.SignSetResponsible.Visible            = False;
		Items.ApproveSetResponsible.Visible            = False;
		Items.ProcessSetResponsible.Visible           = False;
		Items.OnControlSetResponsible.Visible           = False;
		Items.OnRefiningSetResponsible.Visible          = False;
		Items.OnCorrectingSetResponsible.Visible        = False;
		Items.CommandGenerateSignAndSend.Visible       = False;
		Items.UnknownPackagesSetStatusCanceled.Visible     = False;
		Items.UnshippedPackagesSetCancelStatus.Visible  = False;
		Items.UnpackedPackagesSetCancelStatus.Visible = False;
	EndIf;
	
	DocumentsTypesArray = Metadata.InformationRegisters.EDStates.Dimensions.ObjectReference.Type.Types();
	PaymentOrderName = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution(
		"PaymentOrderInMetadata");
	NameAccountsInvoiceReceived = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution(
		"InvoiceReceivedInMetadata");
	SupplierInvoiceNoteAdvanceName = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution(
		"SupplierInvoiceNoteAdvanceInMetadata");
	SupplierProductsAndServicesPricesRegistration = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution(
		"SupplierProductsAndServicesPricesRegistration");

	ExcludedTypes = New Structure;
	ExcludedTypes.Insert("RandomED");
	ExcludedTypes.Insert("EDPackage");
	ExcludedTypes.Insert("EDUsageAgreements");
	If ValueIsFilled(PaymentOrderName) Then
		ExcludedTypes.Insert(PaymentOrderName);
	EndIf;
	If ValueIsFilled(NameAccountsInvoiceReceived) Then
		ExcludedTypes.Insert(NameAccountsInvoiceReceived);
	EndIf;
	If ValueIsFilled(SupplierInvoiceNoteAdvanceName) Then
		ExcludedTypes.Insert(SupplierInvoiceNoteAdvanceName);
	EndIf;
	If ValueIsFilled(SupplierProductsAndServicesPricesRegistration) Then
		ExcludedTypes.Insert(SupplierProductsAndServicesPricesRegistration);
	EndIf;
	
	ArrayOfAvailableDocuments = New Array;
	
	For Each Item IN DocumentsTypesArray Do
		DocumentRef = New(Item);
		Name = DocumentRef.Metadata().Name;
		If ExcludedTypes.Property(Name) Then
			Continue;
		EndIf;
		
		If AccessRight("view", Metadata.Documents[Name]) Then
			ArrayOfAvailableDocuments.Add(Name);
		EndIf;
	EndDo;
	
	IssuedInvoiceName = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution(
		"CustomerInvoiceNoteInMetadata");
	IssuedInvoiceNameAdvance = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution(
		"CustomerInvoiceNoteAdvanceInMetadata");
	NameOfCommercialOffers = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution(
		"CommercialOfferToClient");
	
	If ArrayOfAvailableDocuments.Count() > 0 Then
		
		QueryText =
		"SELECT ALLOWED
		|	EDStates.ObjectReference AS Document,
		|	NestedSelect.Date AS Date,
		|	NestedSelect.Company AS Company,
		|	NestedSelect.Counterparty AS Counterparty,
		|	NestedSelect.DocumentAmount AS DocumentAmount
		|FROM
		|	InformationRegister.EDStates AS EDStates
		|		RIGHT JOIN (&Subquery) AS NestedSelect
		|		ON EDStates.ObjectReference = NestedSelect.Ref
		|WHERE
		|	EDStates.EDVersionState = VALUE(Enum.EDVersionsStates.NotFormed)";
		SubqueryTextPattern =
		"SELECT
		|	DocumentType.Ref AS Ref,
		|	DocumentType.Company AS Company,
		|	DocumentType.Counterparty AS Counterparty,
		|	ISNULL(DocumentType.DocumentAmount, 0) AS DocumentAmount,
		|	DocumentType.Date AS Date
		|FROM
		|	Document.DocumentType AS DocumentType
		|WHERE
		|	Not DocumentType.DeletionMark";
		
		SubqueryText = "";
		FirstItem = True;
		For Each DocumentType IN ArrayOfAvailableDocuments Do
			If DocumentType = PaymentOrderName Then
				Continue;
			EndIf;
			If Not FirstItem Then
				SubqueryText = SubqueryText + "
				| UNION ALL
				|";
			EndIf;
			FirstItem = False;
			SubqueryText = SubqueryText + StrReplace(SubqueryTextPattern, "DocumentType", DocumentType);
			
			
			If (DocumentType = IssuedInvoiceName
					AND CommonUse.IsObjectAttribute("BasisDocument", Metadata.Documents[IssuedInvoiceName]))
				OR (DocumentType = IssuedInvoiceNameAdvance
					AND CommonUse.IsObjectAttribute("BasisDocument", Metadata.Documents[IssuedInvoiceNameAdvance]))
				Then
				
				SubqueryText = StrReplace(
					SubqueryText, DocumentType + ".Counterparty", DocumentType + ".BasisDocument.Counterparty");
				SubqueryText = StrReplace(
					SubqueryText, DocumentType + ".DocumentAmount", DocumentType + ".BasisDocument.DocumentAmount");
			EndIf;
				
			If DocumentType = NameOfCommercialOffers Then
				SubqueryText = StrReplace(
					SubqueryText, DocumentType + ".Counterparty", DocumentType + ".Agreement.Counterparty");
			EndIf;
			
		EndDo;
		
		QueryText = StrReplace(QueryText, "&Subquery", SubqueryText);
		Generate.QueryText = QueryText;
	
	EndIf;

	For Each Page IN Items.Pages.ChildItems Do
		
		DescriptionList = StrReplace(Page.Name, "Page", "");
		Queries.Add(DescriptionList, ThisObject[DescriptionList].QueryText);
		
	EndDo;
	
	RefreshDataTree(Queries);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshStateED" Then
		RefreshDataTreeAtClient();
		UpdateDynamicLists();
		RefreshDataRepresentation();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	CurrentPageName = Items.Pages.CurrentPage.Name;
	
	OnFilterChange();
	
	ElectronicDocumentsServiceClient.FillDataServiceSupport(ServiceSupportPhoneNumber, ServiceSupportEmailAddress);
	
EndProcedure

&AtClient
Procedure OnClose()
	
	SaveFilters(FormName, "Filters", QuickFilters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EVENTS HANDLERS TABLES FORMS QuickFilters

&AtClient
Procedure QuickFiltersValueOnChange(Item)
	
	SetFilters();
	If Item.Parent.CurrentData.Type = "Number" Then
		EnteredNumber = True;
	EndIf;
	
	OnFilterChange();
	
EndProcedure

&AtClient
Procedure QuickFiltersOnStartEdit(Item, NewRow, Copy)
	
	If Item.CurrentData.Value = Undefined Then
		Item.CurrentData.Value = 0;
	Else
		EnteredNumber = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure QuickFiltersOnEditEnd(Item, NewRow, CancelEdit)
	
	If Not EnteredNumber AND Item.CurrentData.Type = "Number" Then
		Item.CurrentData.Value = Undefined;
	EndIf;
	
	EnteredNumber = False;
	
EndProcedure

&AtClient
Procedure QuickFiltersValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Items.QuickFilters.CurrentData.Parameter = "EDKind" Then
		ChoiceData = ListOfCurrentTypesOfED();
		StandardProcessing = False;
	EndIf
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENTS HANDLERS ActionsTree

&AtClient
Procedure TreeActionsOnActivateRow(Item)
	
	Items.Pages.CurrentPage = Items["Page" + Item.CurrentData.Value];
	CurrentPageName = Items.Pages.CurrentPage.Name;
	UpdateDynamicLists();
	CurrentItem = Items[StrReplace(Items.Pages.CurrentPage.Name, "Page", "")];
	
EndProcedure

&AtClient
Procedure QuickFiltersValueClearing(Item, StandardProcessing)
	
	DescriptionCounterpartiesCatalog = AppliedCatalogName("Counterparties");
	If Not ValueIsFilled(DescriptionCounterpartiesCatalog) Then
		DescriptionCounterpartiesCatalog = "Counterparties";
	EndIf;
	
	DescriptionCompanyCatalog = AppliedCatalogName("Companies");
	If Not ValueIsFilled(DescriptionCompanyCatalog) Then
		DescriptionCompanyCatalog = "Companies";
	EndIf;

	
	String = Items.QuickFilters.CurrentData;
	If String.Type = "String" Then
		String.Value = "";
	ElsIf String.Type = "Date" Then
		String.Value = Date(1, 1, 1);
	ElsIf String.Type = "Number" Then
		String.Value = Undefined;
	ElsIf String.Type = "EnumRef.EDKinds" Then
		String.Value = PredefinedValue("Enum.EDKinds.EmptyRef");
	ElsIf String.Type = "CatalogRef."+ DescriptionCounterpartiesCatalog Then
		String.Value = PredefinedValue("Catalog."+ DescriptionCounterpartiesCatalog +".EmptyRef");
	ElsIf String.Type = "CatalogRef." + DescriptionCompanyCatalog Then
		String.Value = PredefinedValue("Catalog." + DescriptionCompanyCatalog + ".EmptyRef");
	ElsIf String.Type = "CatalogRef.Users" Then
		String.Value = PredefinedValue("Catalog.Users.EmptyRef");
	ElsIf String.Type = "EnumRef.EDDirections" Then
		String.Value = PredefinedValue("Enum.EDDirections.EmptyRef");
	EndIf;
	Items.QuickFilters.EndEditRow(False);
	
	SetFilters();
	
	OnFilterChange();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENTS HANDLERS Approve

&AtClient
Procedure ApproveSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	ElectronicDocumentsServiceClient.OpenEDForViewing(SelectedRow);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENTS HANDLERS Correct

&AtClient
Procedure CorrectSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	ElectronicDocumentsServiceClient.OpenEDForViewing(SelectedRow);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENTS HANDLERS Sign

&AtClient
Procedure SignSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	ElectronicDocumentsServiceClient.OpenEDForViewing(SelectedRow);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENTS HANDLERS Handle

&AtClient
Procedure ProcessSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	ElectronicDocumentsServiceClient.OpenEDForViewing(SelectedRow);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENTS HANDLERS Generate

&AtClient
Procedure GenerateSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	ShowValue(, Item.CurrentData.Document);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENTS HANDLERS OnControl

&AtClient
Procedure OnControlSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	ElectronicDocumentsServiceClient.OpenEDForViewing(SelectedRow);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENTS HANDLERS Invitations

&AtClient
Procedure InvitationsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("EDFSetup", SelectedRow);
	FormParameters.Insert("FormIsOpenableFromEDFSetup", False);
	OpenForm("Catalog.EDUsageAgreements.Form.InvitationForm", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// TABLE FORM EVENT HANDLERS InvitationRequired

&AtClient
Procedure InvitationRequiredSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("EDFSetup", SelectedRow);
	FormParameters.Insert("FormIsOpenableFromEDFSetup", False);
	OpenForm("Catalog.EDUsageAgreements.Form.InvitationForm", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENTS HANDLERS WaitingForApproval

&AtClient
Procedure WaitingForApprovalSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("EDFSetup", SelectedRow);
	FormParameters.Insert("FormIsOpenableFromEDFSetup", False);
	OpenForm("Catalog.EDUsageAgreements.Form.InvitationForm", FormParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENTS HANDLERS ApprovalRequired

&AtClient
Procedure ApprovalRequiredSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("EDFSetup", SelectedRow);
	FormParameters.Insert("FormIsOpenableFromEDFSetup", False);
	OpenForm("Catalog.EDUsageAgreements.Form.InvitationForm", FormParameters);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Refresh(Command)
	
	Action = StrReplace(Items.Pages.CurrentPage.Name, "Page", "");
	Items[Action].Refresh();
	RefreshDataTreeAtClient();
	
EndProcedure

&AtClient
Procedure SendAndReceiveED(Command)
	
	ElectronicDocumentsServiceClient.SendReceiveElectronicDocuments();
	
EndProcedure

&AtClient
Procedure ChangeDocument(Command)
	
	If Items.Generate.CurrentData <> Undefined Then
		ShowValue(, Items.Generate.CurrentData.Document);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetStatusUnshippedPackagesCanceled(Command)
	
	SetCancelStatus(Items.Send.SelectedRows);
	
EndProcedure

&AtClient
Procedure SetStatusUnpackedPackagesCanceled(Command)
	
	SetCancelStatus(Items.Unpack.SelectedRows);
	
EndProcedure

&AtClient
Procedure SetCancelStatusUnknownPackages(Command)
	
	SetCancelStatus(Items.Unmake.SelectedRows);
	
EndProcedure

&AtClient
Procedure Unpack(Command)
	
	ElectronicDocumentsServiceClient.UnpackEDPackagesArray(Items.Unpack.SelectedRows);
	
EndProcedure

&AtClient
Procedure GenerateSignAndSend(Command)
	
	DocumentArray = DocumentArray(Items.Generate.SelectedRows);
	ElectronicDocumentsServiceClient.ProcessED(DocumentArray, "GenerateConfirmSignSend");
	
EndProcedure

&AtClient
Procedure GenerateED(Command)
	
	DocumentArray = DocumentArray(Items.Generate.SelectedRows);
	ElectronicDocumentsServiceClient.ProcessED(DocumentArray, "GenerateShow");
	
EndProcedure

&AtClient
Procedure CloseForcedly(Command)
	
	RefArray = ArrayRefsToOwnersED(Items[StrReplace(Items.Pages.CurrentPage.Name, "Page", "")].SelectedRows);
	ElectronicDocumentsClient.CloseEDFForcibly(RefArray);
	
	RefreshDataTreeAtClient();
	UpdateDynamicLists();
	
EndProcedure

&AtClient
Procedure ConfirmED(Command)
	
	RefArray = Items.Approve.SelectedRows;
	ElectronicDocumentsServiceClient.ProcessED(Undefined, "ApproveSend", , RefArray);
	
EndProcedure

&AtClient
Procedure CommandSign(Command)
	
	SignAndSend(Items.Sign.SelectedRows);
	
EndProcedure

&AtClient
Procedure ApproveSignAndSend(Command)
	
	SignAndSend(Items.Process.SelectedRows);
	
EndProcedure

&AtClient
Procedure SendPackages(Command)
	
	#If ThickClientOrdinaryApplication Then
		If Not ElectronicDocumentsOverridable.IsRightToProcessED() Then
			ElectronicDocumentsServiceClient.MessageToUserAboutViolationOfRightOfAccess();
			Return;
		EndIf;
		If Not ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseEDExchange") Then
			MessageText = ElectronicDocumentsServiceCallServer.MessageTextAboutSystemSettingRequirement(
																										"WorkWithED");
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		EndIf;
	#EndIf
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("EDKindsArray", Items.Send.SelectedRows);
	NotificationHandler = New NotifyDescription("SendPackagesAlert", ThisObject, AdditionalParameters);
	
	ElectronicDocumentsServiceClient.GetAgreementsAndCertificatesParametersMatch(NotificationHandler);
		
EndProcedure


&AtClient
Procedure UnsetFilter(Command)
	
	DescriptionCounterpartiesCatalog = AppliedCatalogName("Counterparties");
	If Not ValueIsFilled(DescriptionCounterpartiesCatalog) Then
		DescriptionCounterpartiesCatalog = "Counterparties";
	EndIf;

	For Each String IN QuickFilters Do
		If String.Type = "String" Then
			String.Value = "";
		ElsIf String.Type = "Date" Then
			String.Value = Date(1,1,1);
		ElsIf String.Type = "Number" Then
			String.Value = Undefined;
		ElsIf String.Type = "EnumRef.EDKinds" Then
			String.Value = PredefinedValue("Enum.EDKinds.EmptyRef");
		ElsIf String.Type = "CatalogRef." + DescriptionCounterpartiesCatalog Then
			String.Value = PredefinedValue("Catalog." + DescriptionCounterpartiesCatalog + ".EmptyRef");
		ElsIf String.Type = "CatalogRef.Companies" Then
			String.Value = PredefinedValue("Catalog.Companies.EmptyRef");
		ElsIf String.Type = "CatalogRef.Users" Then
			String.Value = PredefinedValue("Catalog.Users.EmptyRef");
		ElsIf String.Type = "EnumRef.EDDirections" Then
			String.Value = PredefinedValue("Enum.EDDirections.EmptyRef");
		EndIf;
	EndDo;
	
	SetFilters();
	
	SetCommandsEnabledOfFilterReset(False);
	
EndProcedure

&AtClient
Procedure SendInvitations(Command)
	
	ClearMessages();
	
	SettingArrayEDF = Items.InvitationRequired.SelectedRows;
	EDFSettingProfilesArray = EDFProfileSettings(SettingArrayEDF);
	
	If Not ValueIsFilled(EDFSettingProfilesArray) Then
		Return;
	EndIf;
	
	NotificationProcessing = New NotifyDescription("SendInvitationNotification", ThisObject);
	
	ElectronicDocumentsServiceClient.GetAgreementsAndCertificatesParametersMatch(NotificationProcessing, EDFSettingProfilesArray);
	
EndProcedure

&AtClient
Procedure AcceptInvitations(Command)
	
	ClearMessages();
	
	SettingArrayEDF = Items.ApprovalRequired.SelectedRows;
	EDFSettingProfilesArray = EDFProfileSettings(SettingArrayEDF);
	
	If Not ValueIsFilled(EDFSettingProfilesArray) Then
		Return;
	EndIf;
	
	NotificationProcessing = New NotifyDescription("AcceptInvitationsAlert", ThisObject);
	
	ElectronicDocumentsServiceClient.GetAgreementsAndCertificatesParametersMatch(NotificationProcessing, EDFSettingProfilesArray);
	
EndProcedure

&AtClient
Procedure RejectInvitations(Command)
	
	ClearMessages();
	
	SettingArrayEDF = Items.ApprovalRequired.SelectedRows;
	EDFSettingProfilesArray = EDFProfileSettings(SettingArrayEDF);
	
	If Not ValueIsFilled(EDFSettingProfilesArray) Then
		Return;
	EndIf;
	
	NotificationProcessing = New NotifyDescription("RejectInvitationsAlert", ThisObject);
	
	ElectronicDocumentsServiceClient.GetAgreementsAndCertificatesParametersMatch(NotificationProcessing, EDFSettingProfilesArray);

EndProcedure

&AtClient
Procedure OpenEDFSettings(Command)
	ElectronicDocumentsClient.OpenFormSettingsVISITORSOfCounterparties();
EndProcedure

&AtClient
Procedure OpenEDFArchive(Command)
	OpenForm("DataProcessor.ElectronicDocuments.Form.ElectronicDocumentsArchive");
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	HandleCancellationOffer(False);
	
EndProcedure

&AtClient
Procedure RejectCancellation(Command)
	
	HandleCancellationOffer(True);
	
EndProcedure

&AtClient
Procedure Forward(Command)
	
	CurrentTable = Items[ThisForm.CurrentItem.Name];
	If TypeOf(CurrentTable) = Type("FormTable")
		AND CurrentTable.SelectedRows.Count() > 0 Then
		SetResponsible(CurrentTable.SelectedRows);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenLinkTo1CBuhphoneItem(Command)
	ElectronicDocumentsServiceClient.OpenStatement1CBuhphone();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure HandleCancellationOffer(RejectCancellation)
	
	RefArray = Items[StrReplace(Items.Pages.CurrentPage.Name, "Page", "")].SelectedRows;
	For Each ED IN RefArray Do
		ElectronicDocumentsServiceClient.HandleCancellationOffer(ED, RejectCancellation);
	EndDo;
	If RefArray.Count() > 0 Then
		RefreshDataTreeAtClient();
		UpdateDynamicLists();
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetFilterOnAdditionalInformationInList(Filter, FilterValue)
	
	GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	OrGroup = CommonUseClientServer.CreateGroupOfFilterItems(Filter.Items, "Add. information", GroupType);
	
	SelectionItemsComparisonType = DataCompositionComparisonType.Contains;
	RightValue             = FilterValue;
	
	FieldName                    = "AdditionalInformation";
	CommonUseClientServer.AddCompositionItem(OrGroup, FieldName, SelectionItemsComparisonType, RightValue);
	FieldName                    = "RejectionReason";
	CommonUseClientServer.AddCompositionItem(OrGroup, FieldName, SelectionItemsComparisonType, RightValue);
	
EndProcedure

&AtServerNoContext
Function ArrayRefsToOwnersED(Val SelectedRowArray)
	
	RefArray = New Array;
	For Each Record IN SelectedRowArray Do
		If TypeOf(Record) = Type("CatalogRef.EDAttachedFiles") Then
			RefArray.Add(Record.FileOwner);
		Else
			RefArray.Add(Record.ObjectReference);
		EndIf;
	EndDo;
	
	Return RefArray;

EndFunction

&AtServerNoContext
Function DocumentArray(Val KeyArray)
	
	ReturnArray = New Array;
	For Each Record IN KeyArray Do
		ReturnArray.Add(Record.ObjectReference);
	EndDo;
	
	Return ReturnArray;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetFilterBySUM(Form, Value, ComparisonType)

	CommonUseClientServer.AddCompositionItem(
													Form.Generate.Filter,
													"DocumentAmount",
													ComparisonType,
													Value);
	CommonUseClientServer.AddCompositionItem(
													Form.OnControl.Filter,
													"DocumentAmount",
													ComparisonType,
													Value);
	CommonUseClientServer.AddCompositionItem(
													Form.Approve.Filter,
													"DocumentAmount",
													ComparisonType,
													Value);
	CommonUseClientServer.AddCompositionItem(
													Form.Process.Filter,
													"DocumentAmount",
													ComparisonType,
													Value);
	CommonUseClientServer.AddCompositionItem(
													Form.Sign.Filter,
													"DocumentAmount",
													ComparisonType,
													Value);
	CommonUseClientServer.AddCompositionItem(
													Form.Correct.Filter,
													"DocumentAmount",
													ComparisonType,
													Value);
	CommonUseClientServer.AddCompositionItem(
													Form.Cancel.Filter,
													"DocumentAmount",
													ComparisonType,
													Value);

EndProcedure

&AtClientAtServerNoContext
Procedure SetFilterByDate(Form, FilterValue, ComparisonType)

	CommonUseClientServer.AddCompositionItem(Form.Sign.Filter, "Date", ComparisonType, FilterValue);
	CommonUseClientServer.AddCompositionItem(
											Form.Correct.Filter,
											"Date",
											ComparisonType,
											FilterValue);
	CommonUseClientServer.AddCompositionItem(
											Form.Cancel.Filter,
											"Date",
											ComparisonType,
											FilterValue);
	CommonUseClientServer.AddCompositionItem(
											Form.Process.Filter,
											"Date",
											ComparisonType,
											FilterValue);
	CommonUseClientServer.AddCompositionItem(
											Form.Approve.Filter,
											"Date",
											ComparisonType,
											FilterValue);
	CommonUseClientServer.AddCompositionItem(
											Form.Unmake.Filter,
											"Date",
											ComparisonType,
											FilterValue);
	CommonUseClientServer.AddCompositionItem(
											Form.OnControl.Filter,
											"Date",
											ComparisonType,
											FilterValue);
	CommonUseClientServer.AddCompositionItem(
											Form.Send.Filter,
											"Date",
											ComparisonType,
											FilterValue);
	CommonUseClientServer.AddCompositionItem(
											Form.Unpack.Filter,
											"Date",
											ComparisonType,
											FilterValue);
	CommonUseClientServer.AddCompositionItem(
											Form.Generate.Filter,
											"Date",
											ComparisonType,
											FilterValue);
EndProcedure

&AtClientAtServerNoContext
Procedure SetFilterByResponsible(Form, FilterValue)
	
	UseFilter = ValueIsFilled(FilterValue);
	
	CommonUseClientServer.SetFilterItem(
										Form.Approve.Filter,
										"Responsible",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Sign.Filter,
										"Responsible",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Correct.Filter,
										"Responsible",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Cancel.Filter,
										"Responsible",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Process.Filter,
										"Responsible",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.OnControl.Filter,
										"Responsible",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Unpack.Filter,
										"Responsible",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Send.Filter,
										"Responsible",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Unmake.Filter,
										"Responsible",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);

EndProcedure

&AtClientAtServerNoContext
Procedure SetFilterOnCounterparty(Form, FilterValue)
	
	UseFilter = ValueIsFilled(FilterValue);
	
	CommonUseClientServer.SetFilterItem(
										Form.Generate.Filter,
										"Counterparty",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Approve.Filter,
										"Counterparty",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Sign.Filter,
										"Counterparty",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Correct.Filter,
										"Counterparty",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Cancel.Filter,
										"Counterparty",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Process.Filter,
										"Counterparty",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.OnControl.Filter,
										"Counterparty",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Send.Filter,
										"Counterparty",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Unpack.Filter,
										"Counterparty",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetFilterByCompany(Form, FilterValue)
	
	UseFilter = ValueIsFilled(FilterValue);
	
	CommonUseClientServer.SetFilterItem(
										Form.Generate.Filter,
										"Company",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Approve.Filter,
										"Company",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Sign.Filter,
										"Company",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Correct.Filter,
										"Company",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Cancel.Filter,
										"Company",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Process.Filter,
										"Company",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.OnControl.Filter,
										"Company",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Send.Filter,
										"Company",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Unpack.Filter,
										"Company",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Unmake.Filter,
										"Company",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);

EndProcedure

&AtClientAtServerNoContext
Procedure SetFilterTypeED(Form, FilterValue)
	
	UseFilter = ValueIsFilled(FilterValue);
	
	CommonUseClientServer.SetFilterItem(
										Form.Approve.Filter,
										"EDKind",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Sign.Filter,
										"EDKind",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Correct.Filter,
										"EDKind",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Cancel.Filter,
										"EDKind",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Process.Filter,
										"EDKind",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.OnControl.Filter,
										"EDKind",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Unpack.Filter,
										"EDKind",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Unmake.Filter,
										"EDKind",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);

EndProcedure

&AtClientAtServerNoContext
Procedure FilterSetInED(Form, FilterValue)
	
	UseFilter = ValueIsFilled(FilterValue);
	
	CommonUseClientServer.SetFilterItem(
										Form.Approve.Filter,
										"EDDirection",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Sign.Filter,
										"EDDirection",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Correct.Filter,
										"EDDirection",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Cancel.Filter,
										"EDDirection",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Process.Filter,
										"EDDirection",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.OnControl.Filter,
										"EDDirection",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Unpack.Filter,
										"EDDirection",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);
	CommonUseClientServer.SetFilterItem(
										Form.Unmake.Filter,
										"EDDirection",
										FilterValue,
										DataCompositionComparisonType.Equal,
										,
										UseFilter);

EndProcedure

&AtClientAtServerNoContext
Procedure SetFilterOnAdditionalInformation(Form, FilterValue)

	UseFilter = ValueIsFilled(FilterValue);
	
	SetFilterOnAdditionalInformationInList(Form.Approve.Filter, FilterValue);
	SetFilterOnAdditionalInformationInList(Form.Correct.Filter, FilterValue);
	SetFilterOnAdditionalInformationInList(Form.Sign.Filter, FilterValue);
	SetFilterOnAdditionalInformationInList(Form.Process.Filter, FilterValue);
	SetFilterOnAdditionalInformationInList(Form.OnControl.Filter, FilterValue);
	SetFilterOnAdditionalInformationInList(Form.Cancel.Filter, FilterValue);

EndProcedure

&AtClient
Procedure UpdateDynamicLists()
	
	If Items.Pages.CurrentPage = Items.PageGenerate Then
		Items.Generate.Refresh();
	ElsIf Items.Pages.CurrentPage = Items.PageApprove Then
		Items.Approve.Refresh();
	ElsIf Items.Pages.CurrentPage = Items.PageSign Then
		Items.Sign.Refresh();
	ElsIf Items.Pages.CurrentPage = Items.PageProcess Then
		Items.Process.Refresh();
	ElsIf Items.Pages.CurrentPage = Items.PageCorrect Then
		Items.Correct.Refresh();
	ElsIf Items.Pages.CurrentPage = Items.PageCancel Then
		Items.Cancel.Refresh();
	ElsIf Items.Pages.CurrentPage = Items.PageOnControl Then
		Items.OnControl.Refresh();
	ElsIf Items.Pages.CurrentPage = Items.SendPage Then
		Items.Send.Refresh();
	ElsIf Items.Pages.CurrentPage = Items.UnpackPage Then
		Items.Unpack.Refresh();
	ElsIf Items.Pages.CurrentPage = Items.InvitationsPage Then
		Items.Invitation.Refresh();
	ElsIf Items.Pages.CurrentPage = Items.PageInvitationRequired Then
		Items.InvitationRequired.Refresh();
	ElsIf Items.Pages.CurrentPage = Items.PageWaitingForApproval Then
		Items.WaitingForApproval.Refresh();
	ElsIf Items.Pages.CurrentPage = Items.PageApprovalRequired Then
		Items.ApprovalRequired.Refresh();
	EndIf;
	
EndProcedure

&AtServer
Function DataTreeAction(Val ActionsTree, Queries)
	
	Tree = FormDataToValue(ActionsTree, Type("ValueTree"));
	
	DataOnQuantities = DataOnQuantities(Queries);
	
	RowPresentation = NStr("en = 'Generate'");
	SetPresentationRowsTreeRecursively(Tree, "Generate", RowPresentation, DataOnQuantities[0]);
	
	SetPresentationRowsTreeRecursively(Tree, "Process", NStr("en = 'Process'"), DataOnQuantities[1]);
	
	SetPresentationRowsTreeRecursively(Tree, "Approve", NStr("en = 'Approve'"), DataOnQuantities[2]);

	SetPresentationRowsTreeRecursively(Tree, "Sign", NStr("en = 'Sign'"), DataOnQuantities[3]);
	
	SetPresentationRowsTreeRecursively(Tree, "Correct", NStr("en = 'Correct'"), DataOnQuantities[4]);
	
	SetPresentationRowsTreeRecursively(Tree, "Cancel", NStr("en = 'Cancel'"), DataOnQuantities[5]);

	SetPresentationRowsTreeRecursively(Tree, "OnControl", NStr("en = 'On control'"), DataOnQuantities[6]);
	
	SetPresentationRowsTreeRecursively(Tree, "Send", NStr("en = 'Send'"), DataOnQuantities[7]);

	RowPresentation = NStr("en = 'Unpack'");
	SetPresentationRowsTreeRecursively(Tree, "Unpack", RowPresentation, DataOnQuantities[8]);

	SetPresentationRowsTreeRecursively(Tree, "Unmake", NStr("en = 'Unmake'"), DataOnQuantities[9]);
	
	SetPresentationRowsTreeRecursively(Tree, "Invitation", NStr("en = 'Invitation'"), DataOnQuantities[10]);
	SetPresentationRowsTreeRecursively(Tree, "InvitationRequired", NStr("en = 'Is necessary to invite'"), DataOnQuantities[11]);
	SetPresentationRowsTreeRecursively(Tree, "WaitingForApproval", NStr("en = 'Waiting for approval'"), DataOnQuantities[12]);
	SetPresentationRowsTreeRecursively(Tree, "ApprovalRequired", NStr("en = 'Consent required'"), DataOnQuantities[13]);
	
	Return Tree;

EndFunction

&AtServerNoContext
Procedure SetPackagesStatus(Val EDKindsArray, Val PackageStatus, CountOfChanged)
	
	CountOfChanged = 0;
	For Each TableRow IN EDKindsArray Do
		Try
			Package = TableRow.Ref.GetObject();
			Package.PackageStatus = PackageStatus;
			Package.Write();
			CountOfChanged = CountOfChanged + 1;
		Except
			MessageText = BriefErrorDescription(ErrorInfo());
			ErrorText    = DetailErrorDescription(ErrorInfo());
			TextOperations  = NStr("en = 'modification of ED packages status'");
			ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(TextOperations,
																						ErrorText,
																						MessageText);
		EndTry;
	EndDo;
	
EndProcedure

&AtServer
Procedure InitializeTree()

	Tree = FormAttributeToValue("ActionsTree");
	NewRecord = Tree.Rows.Add();
	NewRecord.Value = "Generate";
	StringHandle = Tree.Rows.Add();
	StringHandle.Value = "Process";
	NewRecord = StringHandle.Rows.Add();
	NewRecord.Value = "Approve";
	If UseDS Then
		NewRecord = StringHandle.Rows.Add();
		NewRecord.Value = "Sign";
	EndIf;
	NewRecord = StringHandle.Rows.Add();
	NewRecord.Value = "Correct";
	NewRecord = StringHandle.Rows.Add();
	NewRecord.Value = "Cancel";
	NewRecord = Tree.Rows.Add();
	NewRecord.Value = "Send";
	NewRecord = Tree.Rows.Add();
	NewRecord.Value = "Unpack";
	NewRecord = Tree.Rows.Add();
	NewRecord.Value = "OnControl";
	NewRecord = Tree.Rows.Add();
	NewRecord.Value = "Unmake";
	StringInvitation = Tree.Rows.Add();
	StringInvitation.Value = "Invitation";
	NewRecord = StringInvitation.Rows.Add();
	NewRecord.Value = "InvitationRequired";
	NewRecord = StringInvitation.Rows.Add();
	NewRecord.Value = "WaitingForApproval";
	NewRecord = StringInvitation.Rows.Add();
	NewRecord.Value = "ApprovalRequired";
	
	ValueToFormAttribute(Tree, "ActionsTree");
	
EndProcedure

&AtServerNoContext
Procedure SetPresentationRowsTreeRecursively(Tree, Value, Presentation, Quantity)
	
	For Each String IN Tree.Rows Do
		
		If String.Rows.Count() > 0 Then
			SetPresentationRowsTreeRecursively(String, Value, Presentation, Quantity);
		EndIf;
		
		If String.Value = Value Then
			String.Presentation = Presentation + ?(Quantity > 0, " (" + Quantity + ")", "");
			Return;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure GenerateTableRapidFilter()
	
	QuickFilters.Clear();
	
	DescriptionCounterpartiesCatalog = ElectronicDocumentsReUse.GetAppliedCatalogName("Counterparties");
	If Not ValueIsFilled(DescriptionCounterpartiesCatalog) Then
		DescriptionCounterpartiesCatalog = "Counterparties";
	EndIf;
	
	DescriptionCompanyCatalog = ElectronicDocumentsReUse.GetAppliedCatalogName("Companies");
	If Not ValueIsFilled(DescriptionCompanyCatalog) Then
		DescriptionCompanyCatalog = "Companies";
	EndIf;

	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "Company";
	NewRow.ParameterPresentation = NStr("en = 'Company:'");
	NewRow.Type = "CatalogRef."+ DescriptionCompanyCatalog;
	NewRow.Value = ElectronicDocumentsReUse.GetEmptyRef("Companies");
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "Counterparty";
	NewRow.ParameterPresentation = NStr("en = 'Counterparty:'");
	NewRow.Type = "CatalogRef."+ DescriptionCounterpartiesCatalog;
	NewRow.Value = ElectronicDocumentsReUse.GetEmptyRef("Counterparties");
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "Date_From";
	NewRow.ParameterPresentation = NStr("en = 'Date from:'");
	NewRow.Type = "Date";
	NewRow.Value = Date(1,1,1);
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "Date_To";
	NewRow.ParameterPresentation = NStr("en = 'Date to:'");
	NewRow.Type = "Date";
	NewRow.Value = Date(1,1,1);
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "Amount_From";
	NewRow.ParameterPresentation = NStr("en = 'Amount from:'");
	NewRow.Type = "Number";
	NewRow.Value = Undefined;
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "Amount_To";
	NewRow.ParameterPresentation = NStr("en = 'Amount to:'");
	NewRow.Type = "Number";
	NewRow.Value = Undefined;
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "EDKind";
	NewRow.ParameterPresentation = NStr("en = 'Document kind:'");
	NewRow.Type = "EnumRef.EDKinds";
	NewRow.Value = Enums.EDKinds.EmptyRef();
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "EDDirection";
	NewRow.ParameterPresentation = NStr("en = 'Direction:'");
	NewRow.Type = "EnumRef.EDDirections";
	NewRow.Value = Enums.EDDirections.EmptyRef();
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "AdditionalInformation";
	NewRow.ParameterPresentation = NStr("en = 'Add. information:'");
	NewRow.Type = "String";
	NewRow.Value = "";
	
	NewRow = QuickFilters.Add();
	NewRow.Parameter = "Responsible";
	NewRow.ParameterPresentation = NStr("en = 'Responsible:'");
	NewRow.Type = "CatalogRef.Users";
	NewRow.Value = Users.AuthorizedUser();
	
EndProcedure

&AtClient
Procedure SetFilters()
	
	DeleteFiltersByAmount();
	DeleteFiltersByDate();
	
	SetDynamicListFilters(ThisObject, QuickFilters);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetDynamicListFilters(Form, Filters)
	
	For Each FilterRow IN Filters Do
		If FilterRow.Parameter = "Responsible" Then
			SetFilterByResponsible(Form, FilterRow.Value);
		ElsIf FilterRow.Parameter = "Counterparty" Then
			SetFilterOnCounterparty(Form, FilterRow.Value);
		ElsIf FilterRow.Parameter = "Company" Then
			SetFilterByCompany(Form, FilterRow.Value);
		ElsIf FilterRow.Parameter = "EDDirection" Then
			FilterSetInED(Form, FilterRow.Value);
		ElsIf FilterRow.Parameter = "EDKind" Then
			SetFilterTypeED(Form, FilterRow.Value);
		ElsIf FilterRow.Parameter = "Amount_From"
				AND (ValueIsFilled(FilterRow.Value) OR FilterRow.Value = 0) Then
			SetFilterBySUM(Form, FilterRow.Value, DataCompositionComparisonType.GreaterOrEqual);
		ElsIf FilterRow.Parameter = "Amount_To"
				AND (ValueIsFilled(FilterRow.Value) OR FilterRow.Value = 0) Then
			SetFilterBySUM(Form, FilterRow.Value, DataCompositionComparisonType.LessOrEqual);
		ElsIf FilterRow.Parameter = "Date_From" AND ValueIsFilled(FilterRow.Value) Then
			SetFilterByDate(Form, BegOfDay(FilterRow.Value), DataCompositionComparisonType.GreaterOrEqual);
		ElsIf FilterRow.Parameter = "Date_To" AND ValueIsFilled(FilterRow.Value) Then
			SetFilterByDate(Form, EndOfDay(FilterRow.Value), DataCompositionComparisonType.LessOrEqual);
		ElsIf FilterRow.Parameter = "AdditionalInformation" Then
			SetFilterOnAdditionalInformation(Form, FilterRow.Value);
		EndIf;
	EndDo
	
EndProcedure

&AtClient
Procedure DeleteFiltersByAmount()
	
	CommonUseClientServer.DeleteItemsOfFilterGroup(Generate.Filter, "DocumentAmount");
	CommonUseClientServer.DeleteItemsOfFilterGroup(Process.Filter,   "DocumentAmount");
	CommonUseClientServer.DeleteItemsOfFilterGroup(OnControl.Filter,   "DocumentAmount");
	CommonUseClientServer.DeleteItemsOfFilterGroup(Sign.Filter,    "DocumentAmount");
	CommonUseClientServer.DeleteItemsOfFilterGroup(Approve.Filter,    "DocumentAmount");
	CommonUseClientServer.DeleteItemsOfFilterGroup(Correct.Filter,    "DocumentAmount");
	CommonUseClientServer.DeleteItemsOfFilterGroup(Cancel.Filter, "DocumentAmount");
	
EndProcedure

&AtClient
Procedure DeleteFiltersByDate()
	
	CommonUseClientServer.DeleteItemsOfFilterGroup(Generate.Filter, "Date");
	CommonUseClientServer.DeleteItemsOfFilterGroup(Unpack.Filter,  "Date");
	CommonUseClientServer.DeleteItemsOfFilterGroup(Process.Filter,   "Date");
	CommonUseClientServer.DeleteItemsOfFilterGroup(OnControl.Filter,   "Date");
	CommonUseClientServer.DeleteItemsOfFilterGroup(Send.Filter,    "Date");
	CommonUseClientServer.DeleteItemsOfFilterGroup(Unmake.Filter,    "Date");
	CommonUseClientServer.DeleteItemsOfFilterGroup(Approve.Filter,    "Date");
	CommonUseClientServer.DeleteItemsOfFilterGroup(Correct.Filter,    "Date");
	CommonUseClientServer.DeleteItemsOfFilterGroup(Sign.Filter,    "Date");
	CommonUseClientServer.DeleteItemsOfFilterGroup(Cancel.Filter, "Date");
	
EndProcedure

&AtClient
Procedure SetCancelStatus(EDKindsArray)
	
	Quantity = 0;
	SetPackagesStatus(EDKindsArray,
							PredefinedValue("Enum.EDPackagesStatuses.Canceled"),
							Quantity);
	NotificationText = NStr("en = 'Packages status is changed on ""Canceled"": (%1)'");
	NotificationText = StrReplace(NotificationText, "%1", Quantity);
	ShowUserNotification(NStr("en = 'Electronic document exchange'"), , NotificationText);
	RefreshDataTreeAtClient();
	UpdateDynamicLists();
	
EndProcedure

&AtClient
Procedure SetResponsible(EDKindsArray)
	
	NotificationProcessing = New NotifyDescription("SetResponsibleAlert", ThisObject);
	
	ElectronicDocumentsServiceClient.ChangeResponsiblePerson(EDKindsArray, NotificationProcessing);
	
EndProcedure

&AtServerNoContext
Procedure SaveFilters(Val FormName, Val Key, Val Value)

	CommonUse.CommonSettingsStorageSave(FormName, Key, Value.Unload());
	
EndProcedure

&AtServerNoContext
Function ListOfCurrentTypesOfED()
	
	ArrayLatestED = ElectronicDocumentsReUse.GetEDActualKinds();
	BankExchangeUsing = GetFunctionalOption("UseEDExchangeWithBanks");
	If Not BankExchangeUsing Then
		ArrayExceptionsED = New Array();
		ArrayExceptionsED.Add(Enums.EDKinds.BankStatement);
		ArrayExceptionsED.Add(Enums.EDKinds.QueryStatement);
		ArrayExceptionsED.Add(Enums.EDKinds.PaymentOrder);
		ArrayLatestED = CommonUseClientServer.ReduceArray(ArrayLatestED, ArrayExceptionsED);
	EndIf;
	ReturnList = New ValueList;
	ReturnList.LoadValues(ArrayLatestED);
	Return ReturnList;
	
EndFunction

&AtClient
Procedure SetCommandsEnabledOfFilterReset(Enabled)
	
	Items.UnsetFilter.Enabled = Enabled;
	
EndProcedure

&AtClient
Procedure OnFilterChange()
	
	SetCommandsEnabledOfFilterReset(False);
	
	For Each String IN QuickFilters Do
		If ValueIsFilled(String.Value) OR TypeOf(String.Value) = Type("Number") Then
			SetCommandsEnabledOfFilterReset(True);
			Break;
		EndIf
	EndDo
	
EndProcedure

&AtServer
Function AppliedCatalogName(Description)
	
	Return ElectronicDocumentsReUse.GetAppliedCatalogName(Description);
	
EndFunction

&AtServer
Procedure RefreshDataTree(Val Queries)
	
	Tree = DataTreeAction(ActionsTree, Queries);
	
	Collection = ActionsTree.GetItems();
	Collection.Clear();
	
	For Each String IN Tree.Rows Do
		FillRowsRecursively(Collection, String);
	EndDo
	
EndProcedure

&AtServer
Procedure FillRowsRecursively(Receiver, Val Source);
	
	NewCollectionRow = Receiver.Add();
	FillPropertyValues(NewCollectionRow, Source);
	If Source.Rows.Count() > 0 Then
		For Each String IN Source.Rows Do
			FillRowsRecursively(NewCollectionRow.GetItems(), String);
		EndDo
	EndIf;
	
EndProcedure

&AtServerNoContext
Function DataOnQuantities(Val Queries)
	
	QueryTextCommon = "";
	
	For Each QueryText IN Queries Do
		QueryTextCommon = QueryTextCommon + QueryText + ";" + Chars.LF;
	EndDo;
	
	Query = New Query;
	Query.Text = QueryTextCommon;
	QueryResult = Query.ExecuteBatch();
	
	ResultsArray = New Array;
	
	For Each Selection IN QueryResult Do
		ResultsArray.Add(Selection.Select().Count());
	EndDo;
	
	Return ResultsArray;
	
EndFunction

&AtClient
Procedure RefreshDataTreeAtClient()
	
	CurrentRow = Items.ActionsTree.CurrentData.Value;
	RefreshDataTree(Queries);
	TreeItems = ActionsTree.GetItems();
	For Each Item IN TreeItems Do
		If Item.Value = CurrentRow Then
			Items.ActionsTree.CurrentRow = Item.GetID();
		EndIf;
		If Item.Value = "Process" Then
			Items.ActionsTree.Expand(Item.GetID());
		EndIf;
		ChildItemsForRows = Item.GetItems();
		If ChildItemsForRows.Count() > 0 Then
			For Each SubordinateItem IN ChildItemsForRows Do
				If SubordinateItem.Value = CurrentRow Then
					Items.ActionsTree.CurrentRow = SubordinateItem.GetID();
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure NotifyAboutResults(CountOfDigitallySigned, PreparedCnt, SentCnt)
	
	StatusText = NStr("en = 'Undefined
		| ED: signed: (%1)'");
	Quantity = 0;
	If SentCnt > 0 Then
		StatusText = StatusText + Chars.LF + NStr("en = ' sent: (%2)'");
		Quantity = SentCnt;
	ElsIf PreparedCnt > 0 Then
		StatusText = NStr("en = ' ready for sending: (%2)'");
		Quantity = PreparedCnt;
	EndIf;
	
	If SentCnt > 0 Or PreparedCnt > 0 Then
		
		HeaderText = NStr("en = 'Electronic document exchange'");
		DigitallySignedTotalQty = CountOfDigitallySigned;
		StatusText = StringFunctionsClientServer.PlaceParametersIntoString(StatusText, DigitallySignedTotalQty, Quantity);
		
		ShowUserNotification(HeaderText, , StatusText);
		Notify("RefreshStateED");
		
	EndIf;
	
	//NotifyAboutResults(CountOfDigitallySigned, PreparedCnt, SentCnt);


EndProcedure

&AtClient
Procedure SignAndSend(CommandParameter)
	
	RefArray = ElectronicDocumentsServiceClient.GetParametersArray(CommandParameter);
	
	If ValueIsFilled(RefArray) Then
		ElectronicDocumentsClient.GenerateSignSendED(Undefined, RefArray);
		RefreshDataTreeAtClient();
	EndIf;
	
EndProcedure

&AtServer
Procedure SendInvitationsServer(PostedInvitations, EDFSettingsProfilesMatchToMarkers)
	
	// Prepare table with counterparty details
	InvitationsTable = New ValueTable;
	InvitationsTable.Columns.Add("EDFProfileSettings");
	InvitationsTable.Columns.Add("EDFSetting");
	InvitationsTable.Columns.Add("Recipient");
	InvitationsTable.Columns.Add("Description");
	InvitationsTable.Columns.Add("DescriptionForUserMessage");
	InvitationsTable.Columns.Add("TIN");
	InvitationsTable.Columns.Add("KPP");
	InvitationsTable.Columns.Add("EMail_Address");
	InvitationsTable.Columns.Add("InvitationText");
	InvitationsTable.Columns.Add("ExternalCode");
	
	AttributeNameCounterpartyTIN = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyTIN");
	AttributeNameCounterpartyKPP = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyCRR");
	AttributeNameCounterpartyName = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyDescription");
	AttributeNameExternalCounterpartyCode = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("ExternalCounterpartyCode");
	AttributeNameCounterpartyNameForMessageToUser = ElectronicDocumentsReUse.NameAttributeObjectExistanceInAppliedSolution("CounterpartyNameForMessageToUser");
	
	For Each EDFSetup IN Items.InvitationRequired.SelectedRows Do
		
		EDFSettingsParametersStructure = CommonUse.ObjectAttributesValues(EDFSetup,
			"EmailForInvitation, Counterparty, InvitationText, EDFProfileSettings");
		
		If Not ValueIsFilled(EDFSettingsParametersStructure.EmailForInvitation) Then
			MessagePattern = NStr("en = 'To send recipient invitations for ED
										|exchange %1, you need to fill email.'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
				EDFSettingsParametersStructure.Counterparty);
			CommonUseClientServer.MessageToUser(MessageText);
			
			Continue;
		EndIf;
		
		CounterpartyParametersStructure = CommonUse.ObjectAttributeValues(EDFSettingsParametersStructure.Counterparty,
			AttributeNameCounterpartyTIN + ", " + AttributeNameCounterpartyKPP + ", " + AttributeNameCounterpartyName + ", "
			+ AttributeNameExternalCounterpartyCode + ", " + AttributeNameCounterpartyNameForMessageToUser);
	
		If Not ValueIsFilled(CounterpartyParametersStructure[AttributeNameCounterpartyTIN]) Then
			MessagePattern = NStr("en = 'To send recipient invitations for ED
										|exchange %1, you need to fill TIN.'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern,
				EDFSettingsParametersStructure.Counterparty);
			CommonUseClientServer.MessageToUser(MessageText);
			
			Continue;
		EndIf;
		
		NewRow = InvitationsTable.Add();
		NewRow.EDFProfileSettings = EDFSettingsParametersStructure.EDFProfileSettings;
		NewRow.EDFSetup       = EDFSetup;
		NewRow.Recipient         = EDFSettingsParametersStructure.Counterparty;
		NewRow.InvitationText   = EDFSettingsParametersStructure.InvitationText;
		NewRow.EMail_Address            = EDFSettingsParametersStructure.EmailForInvitation;
		
		NewRow.Description       = CounterpartyParametersStructure[AttributeNameCounterpartyName];
		NewRow.DescriptionForUserMessage = CounterpartyParametersStructure[AttributeNameCounterpartyNameForMessageToUser];
		NewRow.TIN                = CounterpartyParametersStructure[AttributeNameCounterpartyTIN];
		NewRow.KPP                = CounterpartyParametersStructure[AttributeNameCounterpartyKPP];
		NewRow.ExternalCode         = CounterpartyParametersStructure[AttributeNameExternalCounterpartyCode];
		
	EndDo;
	
	If Not ValueIsFilled(InvitationsTable) Then
		Return;
	EndIf;
	
	For Each KeyAndValue IN EDFSettingsProfilesMatchToMarkers Do
		EDFProfileSettings = KeyAndValue.Key;
		CertificateStructure = KeyAndValue.Value;
		
		Marker = "";
		If TypeOf(CertificateStructure) = Type("Structure") Then
			CertificateStructure.Property("MarkerTranscribed", Marker);
		EndIf;
		If Not ValueIsFilled(Marker) Then
			Continue;
		EndIf;
		
		InvitationsFilter = New Structure;
		InvitationsFilter.Insert("EDFProfileSettings", EDFProfileSettings);
		
		TableForSendingInvitations = InvitationsTable.Copy(InvitationsFilter);
		
		AdditParameters = New Structure;
		FileName = ElectronicDocumentsInternal.OutgoingEDFOperatorInvitationRequest(TableForSendingInvitations, AdditParameters);
		If Not ValueIsFilled(FileName) Then
			Return;
		EndIf;
		
		PathForInvitations = ElectronicDocumentsService.WorkingDirectory("Invite");
		InvitationFileName = PathForInvitations + "SendContacts.xml";
		FileCopy(FileName, InvitationFileName);
		SendingResult = ElectronicDocumentsInternal.SendThroughEDFOperator(
			Marker,
			PathForInvitations,
			"SendContacts",
			EDFProfileSettings);
		DeleteFiles(PathForInvitations);
		
		If SendingResult <> 0 Then
			
			For Each TableRow IN InvitationsTable Do
				SearchEDFSetup = EDFSetup.GetObject();
				SearchEDFSetup.ConnectionStatus = Enums.EDExchangeMemberStatuses.AgreementExpectation;
				SearchEDFSetup.AgreementState = Enums.EDAgreementStates.CoordinationExpected;
				SearchEDFSetup.ErrorDescription = "";
				SearchEDFSetup.Write();
			EndDo;
			PostedInvitations = InvitationsTable.Count();
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure AcceptRejectContactViaOperatorEDOAtServer(AcceptedInvitationsQuantity, EDFSettingsProfilesMatchToMarkers, InvitationAccepted)
	
	For Each EDFSetup IN Items.ApprovalRequired.SelectedRows Do
		
		CertificateStructure = EDFSettingsProfilesMatchToMarkers.Get(EDFSetup.EDFProfileSettings);
		
		Marker = "";
		If TypeOf(CertificateStructure) = Type("Structure") Then
			CertificateStructure.Property("MarkerTranscribed", Marker);
		EndIf;
		If Not ValueIsFilled(Marker) Then
			Continue;
		EndIf;
		
		Result = False;
		
		SearchEDFSetup = EDFSetup.GetObject();
		If SearchEDFSetup.EDFSettingUnique() Then
			Result = ElectronicDocumentsInternal.AcceptRejectContactThroughEDFOperator(
				EDFSetup.CounterpartyID, InvitationAccepted, Marker);
		EndIf;
		If Result Then
			If InvitationAccepted Then
				SearchEDFSetup.ConnectionStatus = Enums.EDExchangeMemberStatuses.Connected;
				SearchEDFSetup.AgreementState = Enums.EDAgreementStates.CheckingTechnicalCompatibility;
			Else
				SearchEDFSetup.ConnectionStatus = Enums.EDExchangeMemberStatuses.Disconnected;
				SearchEDFSetup.AgreementState = Enums.EDAgreementStates.Closed;
			EndIf;
			SearchEDFSetup.Write();
			
			AcceptedInvitationsQuantity = AcceptedInvitationsQuantity + 1;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function EDFProfileSettings(Val SettingArrayEDF)
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	EDUsageAgreements.EDFProfileSettings
	|FROM
	|	Catalog.EDUsageAgreements AS EDUsageAgreements
	|WHERE
	|	EDUsageAgreements.Ref IN(&SettingArrayEDF)";
	
	Query.SetParameter("SettingArrayEDF", SettingArrayEDF);
	Table = Query.Execute().Unload();
	
	Return Table.UnloadColumn("EDFProfileSettings");
	
EndFunction

#EndRegion

#Region AsynchronousDialogsHandlers

&AtClient
Procedure AfterSendingEDP(Result, AdditionalParameters) Export
	
	DigitallySignedCnt = 0;
	PreparedCnt = 0;
	SentCnt = 0;
	If TypeOf(Result) = Type("Structure") Then
		If Not(Result.Property("PreparedCnt", PreparedCnt)
				AND TypeOf(PreparedCnt) = Type("Number")) Then
			
			PreparedCnt = 0;
		EndIf;
		If Not(Result.Property("SentCnt", SentCnt)
				AND TypeOf(SentCnt) = Type("Number")) Then
			
			SentCnt = 0;
		EndIf;
	EndIf;
	If TypeOf(AdditionalParameters) = Type("Number") Then
		DigitallySignedCnt = AdditionalParameters;
	EndIf;
	
	NotifyAboutResults(DigitallySignedCnt, PreparedCnt, SentCnt);
	
EndProcedure

&AtClient
Procedure RejectInvitationsAlert(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	ProfilesAndCertificatesParametersMatch = "";
	
	If Result.Property("ProfilesAndCertificatesParametersMatch", ProfilesAndCertificatesParametersMatch)
		AND ValueIsFilled(ProfilesAndCertificatesParametersMatch) Then
		
		HeaderText = NStr("en = 'Invitations are rejected'");
		
		RejectedInvitationsQuantity = 0;
		AcceptRejectContactViaOperatorEDOAtServer(RejectedInvitationsQuantity, ProfilesAndCertificatesParametersMatch, False);
		
		MessagePattern = NStr("en = 'Invitations rejected: %1'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, RejectedInvitationsQuantity);
		
		ShowUserNotification(HeaderText, , MessageText);
		
		RefreshDataTreeAtClient();
		UpdateDynamicLists();
	Else
		ErrorText = NStr("en = 'When declining the invitations, errors occurred.
			|Necessary to check EDF settings with specified counterparties.'");
		CommonUseClientServer.MessageToUser(ErrorText);
	EndIf;
	
EndProcedure

&AtClient
Procedure AcceptInvitationsAlert(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	ProfilesAndCertificatesParametersMatch = "";
	
	If Result.Property("ProfilesAndCertificatesParametersMatch", ProfilesAndCertificatesParametersMatch)
		AND ValueIsFilled(ProfilesAndCertificatesParametersMatch) Then
		
		HeaderText = NStr("en = 'Invitations are received'");
		
		AcceptedInvitationsQuantity = 0;
		AcceptRejectContactViaOperatorEDOAtServer(AcceptedInvitationsQuantity, ProfilesAndCertificatesParametersMatch, True);
		
		MessagePattern = NStr("en = 'Invitations received: %1'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, AcceptedInvitationsQuantity);
		
		ShowUserNotification(HeaderText, , MessageText);
		
		RefreshDataTreeAtClient();
		UpdateDynamicLists();
	Else
		ErrorText = NStr("en = 'The errors occurred while getting invitations.
			|Necessary to check EDF settings with specified counterparties.'");
		CommonUseClientServer.MessageToUser(ErrorText);
	EndIf;
	
EndProcedure

&AtClient
Procedure SendInvitationNotification(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	ProfilesAndCertificatesParametersMatch = "";
	
	If Result.Property("ProfilesAndCertificatesParametersMatch", ProfilesAndCertificatesParametersMatch)
		AND ValueIsFilled(ProfilesAndCertificatesParametersMatch) Then
		
		HeaderText = NStr("en = 'Send invitations to recipients'");
		
		PostedInvitations = 0;
		SendInvitationsServer(PostedInvitations, ProfilesAndCertificatesParametersMatch);
		
		MessagePattern = NStr("en = 'Invitations sent: %1'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessagePattern, PostedInvitations);
		
		ShowUserNotification(HeaderText, , MessageText);
		
		RefreshDataTreeAtClient();
		UpdateDynamicLists();
	Else
		ErrorText = NStr("en = 'The errors occurred while sending the invitations.
			|Necessary to check EDF settings with specified counterparties.'");
		CommonUseClientServer.MessageToUser(ErrorText);
	EndIf;
	
EndProcedure

&AtClient
Procedure SendPackagesAlert(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	ProfilesAndCertificatesParametersMatch = Result.ProfilesAndCertificatesParametersMatch;
	
	EDKindsArray = AdditionalParameters.EDKindsArray;
	
	CountSent = ElectronicDocumentsServiceCallServer.EDPackagesSending(
													EDKindsArray,
													ProfilesAndCertificatesParametersMatch);

	NotificationTemplate = NStr("en = 'Packages sent: (%1).'");
	NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(NotificationTemplate, CountSent);
	
	Notify("RefreshStateED");
		
	NotificationTitle = NStr("en = 'Electronic documents sending'");
	ShowUserNotification(NotificationTitle, , NotificationText);
	
EndProcedure

&AtClient
Procedure SetResponsibleAlert(Val Result, Val AdditionalParameters) Export
	
	If Result = True Then
		UpdateDynamicLists();
	EndIf;
	
EndProcedure

#EndRegion
