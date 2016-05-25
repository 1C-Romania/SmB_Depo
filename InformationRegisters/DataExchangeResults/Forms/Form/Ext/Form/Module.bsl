
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	InUseGroupUpdate = False;
	DataExchangeServer.OnDefineOfGroupObjectsChangesUsing(InUseGroupUpdate);
	
	If Not InUseGroupUpdate Then
		
		Items.NonPostedDocumentsContextMenu.ChildItems.UnpostedDocumentsContextMenuChangeSelectedDocument.Visible = False;
		Items.UnpostedDocumentsChangeSelectedDocument.Visible = False;
		Items.BlankAttributesContextMenu.ChildItems.BlankAttributesContextMenuChangeSelectedObject.Visible = False;
		Items.BlankAttributesChangeSelectedObjects.Visible = False;
		
	EndIf;
	
	UsedChangeProhibitionDates = False;
	DataExchangeServer.OnDefenitionOfUsageOfProhibitionDatesChange(UsedChangeProhibitionDates);
	
	UseVersioning = DataExchangeReUse.UseVersioning(, True);
	
	If Not UseVersioning Then
		
		Collisions.QueryText = "";
		UnacceptedByDate.QueryText = "";
		Items.CollisionsPage.Visible = False;
		Items.PageUnacceptedByProhibitionDate.Visible = False;
		
	ElsIf Not UsedChangeProhibitionDates Then
		
		UnacceptedByDate.QueryText = "";
		Items.PageUnacceptedByProhibitionDate.Visible = False;
		
	EndIf;
	
	// Set dynamic list filters and save them in the attribute to manage them.
	CustomizeSelectionsForDynamicLists(DynamicListsFilterSettings);
	
	If CommonUseReUse.DataSeparationEnabled() AND UseVersioning Then
		
		Items.CollisionsOtherVersionAuthor.Title = NStr("en = 'Version is obtained from application'");
		
	EndIf;
	
	FillNodeList();
	
	RefreshSelectionsAndIgnored();
	
EndProcedure

&AtClient
Procedure OnClose()
	
	Notify("ClosedFormDataExchangeResults");
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	UpdateAtServer();
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	RefreshSelectionsAndIgnored();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure SearchStringOnChange(Item)
	
	RefreshReasonFilter();
	
EndProcedure

&AtClient
Procedure PeriodOnChange(Item)
	
	RefreshPeriodFilter();
	
EndProcedure

&AtClient
Procedure DatabaseNodClear(Item, StandardProcessing)
	
	InfobaseNode = Undefined;
	RefreshNodFilter();
	
EndProcedure

&AtClient
Procedure InfobaseNodeOnChange(Item)
	
	RefreshNodFilter();
	
EndProcedure

&AtClient
Procedure InfobaseNodeStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not Items.InfobaseNode.ListChoiceMode Then
		
		StandardProcessing = False;
		
		Handler = New NotifyDescription("InfobaseNodeStartChoiceEnd", ThisObject);
		Mode = FormWindowOpeningMode.LockOwnerWindow;
		OpenForm("CommonForm.ExchangePlanNodesSelection",,,,,, Handler, Mode);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InfobaseNodeStartChoiceEnd(ClosingResult, AdditionalParameters) Export
	
	InfobaseNode = ClosingResult;
	
	RefreshNodFilter();
	
EndProcedure

&AtClient
Procedure InfobaseNodeChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	InfobaseNode = ValueSelected;
	
EndProcedure

&AtClient
Procedure DataExchangeResultsOnCurrentPageChange(Item, CurrentPage)
	
	If Item.ChildItems.CollisionsPage = CurrentPage Then
		Items.SearchString.Enabled = False;
	Else
		Items.SearchString.Enabled = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersUnpostedDocuments

&AtClient
Procedure UnpostedDocumentsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenObject(Items.UnpostedDocuments);
	
EndProcedure

&AtClient
Procedure UnpostedDocumentsBeforeChangeStart(Item, Cancel)
	
	ObjectModifying();
	Cancel = True;
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersBlankAttributes

&AtClient
Procedure BlankAttributesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenObject(Items.BlankAttributes);
	
EndProcedure

&AtClient
Procedure BlankAttributesBeforeChangeStart(Item, Cancel)
	
	ObjectModifying();
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ColissionsBeforeChangeStart(Item, Cancel)
	
	ObjectModifying();
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ColissionsOnActivateRow(Item)
	
	If Item.CurrentData <> Undefined Then
		
		If Item.CurrentData.OtherVersionAccepted Then
			
			ConflictReason = NStr("en = 'Conflict was allowed automatically in favour of the application ""%1"".
				|Version in this application was changed to version from another application.'");
			ConflictReason = StringFunctionsClientServer.PlaceParametersIntoString(ConflictReason, Item.CurrentData.OtherVersionAuthor);
			
		Else
			
			ConflictReason =NStr("en = 'Conflict was allowed automatically in favour of this application.
				|Version in this application was saved, version from another application was rejected.'");
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UnacceptedByDateBeforeChangeStart(Item, Cancel)
	
	ObjectModifying();
	Cancel = True;
	
EndProcedure

&AtClient
Procedure UnacceptedByDateOnActivateRow(Item)
	
	If Item.CurrentData <> Undefined Then
		
		If Item.CurrentData.NewObject Then
			
			Items.UnacceptedByDateAcceptVersion.Enabled = False;
			
		Else
			
			Items.UnacceptedByDateAcceptVersion.Enabled = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Change(Command)
	
	ObjectModifying();
	
EndProcedure

&AtClient
Procedure IgnoreDocument(Command)
	
	Ignore(Items.UnpostedDocuments.SelectedRows, True, "UnpostedDocuments");
	
EndProcedure

&AtClient
Procedure NotIgnoreDocument(Command)
	
	Ignore(Items.UnpostedDocuments.SelectedRows, False, "UnpostedDocuments");
	
EndProcedure

&AtClient
Procedure NotIgnoreObject(Command)
	
	Ignore(Items.BlankAttributes.SelectedRows, False, "BlankAttributes");
	
EndProcedure

&AtClient
Procedure IgnoreObject(Command)
	
	Ignore(Items.BlankAttributes.SelectedRows, True, "BlankAttributes");
	
EndProcedure

&AtClient
Procedure ChangeSelectedDocuments(Command)
	
	DataExchangeClient.OnSelectedObjectsChange(Items.UnpostedDocuments);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	UpdateAtServer();
	
EndProcedure

&AtClient
Procedure PostDocument(Command)
	
	ClearMessages();
	PostDocuments(Items.UnpostedDocuments.SelectedRows);
	UpdateAtServer("UnpostedDocuments");
	
EndProcedure

&AtClient
Procedure ChangeSelectedObjects(Command)
	
	DataExchangeClient.OnSelectedObjectsChange(Items.BlankAttributes);
	
EndProcedure

&AtClient
Procedure ShowUnacceptedDifferences(Command)
	
	ShowDifference(Items.UnacceptedByDate);
	
EndProcedure

&AtClient
Procedure OpenUnnaceptedVersion(Command)
	
	If Items.UnacceptedByDate.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ComparedVersions = New Array;
	ComparedVersions.Add(Items.UnacceptedByDate.CurrentData.OtherVersionNumber);
	DataExchangeClient.OnReportFormByVersionOpen(Items.UnacceptedByDate.CurrentData.Ref, ComparedVersions);
	
EndProcedure

&AtClient
Procedure OpenVersionUnacceptedAtThisApplication(Command)
	
	If Items.UnacceptedByDate.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ComparedVersions = New Array;
	ComparedVersions.Add(Items.UnacceptedByDate.CurrentData.ThisVersionNumber);
	DataExchangeClient.OnReportFormByVersionOpen(Items.UnacceptedByDate.CurrentData.Ref, ComparedVersions);

EndProcedure

&AtClient
Procedure ShowCollisionDifferences(Command)
	
	ShowDifference(Items.Collisions);
	
EndProcedure

&AtClient
Procedure IgnoreConflict(Command)
	
	IgnoreVersion(Items.Collisions.SelectedRows, True, "Collisions");
	
EndProcedure

&AtClient
Procedure IgnoreUnaccepted(Command)
	
	IgnoreVersion(Items.UnacceptedByDate.SelectedRows, True, "UnacceptedByDate");
	
EndProcedure

&AtClient
Procedure NotIgnoreConflict(Command)
	
	IgnoreVersion(Items.Collisions.SelectedRows, False, "Collisions");
	
EndProcedure

&AtClient
Procedure NotIgnoreUnaccepted(Command)
	
	IgnoreVersion(Items.UnacceptedByDate.SelectedRows, False, "UnacceptedByDate");
	
EndProcedure

&AtClient
Procedure AcceptVersionUnaccepted(Command)
	
	NotifyDescription = New NotifyDescription("AcceptVersionUnacceptedEnd", ThisObject);
	ShowQueryBox(NOTifyDescription, NStr("en = 'Do you want to accept version despite the import prohibition?'"), QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure AcceptVersionUnacceptedEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		AcceptRejectVersionAtServer(Items.UnacceptedByDate.SelectedRows, "UnacceptedByDate");
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenVersionBeforeConflict(Command)
	
	CurrentData = Items.Collisions.CurrentData;
	OpenVersionClient(Items.Collisions.CurrentData, CurrentData.ThisVersionNumber);
	
EndProcedure

&AtClient
Procedure ConflictVersionOpen(Command)
	
	CurrentData = Items.Collisions.CurrentData;
	OpenVersionClient(Items.Collisions.CurrentData, CurrentData.OtherVersionNumber);
	
EndProcedure

&AtClient
Procedure ShowIgnoredConflicts(Command)
	
	ShowIgnoredConflicts = Not ShowIgnoredConflicts;
	ShowIgnoredConflictsAtServer();
	
EndProcedure

&AtClient
Procedure ShowIgnoredlank(Command)
	
	ShowIgnoredlank = Not ShowIgnoredlank;
	ShowIgnoredBlankAtServer();
	
EndProcedure

&AtClient
Procedure ShowIgnoredUnaccepted(Command)
	
	ShowIgnoredUnaccepted = Not ShowIgnoredUnaccepted;
	ShowIgnoredUnacceptedAtServer();
	
EndProcedure

&AtClient
Procedure ShowIgnoredNotPosted(Command)
	
	ShowIgnoredNotPosted = Not ShowIgnoredNotPosted;
	ShowIgnoredNotPostedAtServer();
	
EndProcedure

&AtClient
Procedure ConflictResultChange(Command)
	
	If Items.Collisions.CurrentData <> Undefined Then
		
		If Items.Collisions.CurrentData.OtherVersionAccepted Then
			
			QuestionText = NStr("en = 'Do you want to replace the version obtained out of another application to the version out of this application?'");
			
		Else
			
			QuestionText = NStr("en = 'Do you want to replace the current version of the application by the version received out of another application?'");
			
		EndIf;
		
		NotifyDescription = New NotifyDescription("ChangeConflictResultEnd", ThisObject);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeConflictResultEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		AcceptRejectVersionAtServer(Items.Collisions.SelectedRows, "Collisions");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure Ignore(Val SelectedRows, Skip, ItemName)
	
	For Each SelectedRow IN SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicalListGroupRow") Then
			Continue;
		EndIf;
	
		InformationRegisters.DataExchangeResults.Ignore(SelectedRow.ProblematicObject, SelectedRow.ProblemType, Skip);
	
	EndDo;
	
	UpdateAtServer(ItemName);
	
EndProcedure


&AtServer
Procedure ShowIgnoredConflictsAtServer(Update = True)
	
	Items.ColissionsShowIgnoredConflicts.Check = ShowIgnoredConflicts;
	
	Filter = Collisions.SettingsComposer.Settings.Filter;
	FilterItem = Filter.GetObjectByID( DynamicListsFilterSettings.Collisions.VersionIgnored );
	FilterItem.RightValue = ShowIgnoredConflicts;
	FilterItem.Use  = Not ShowIgnoredConflicts;
	
	If Update Then
		UpdateAtServer("Collisions");
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowIgnoredBlankAtServer(Update = True)
	
	Items.BlankAttributesShowIgnoredBlank.Check = ShowIgnoredlank;
	
	Filter = BlankAttributes.SettingsComposer.Settings.Filter;
	FilterItem = Filter.GetObjectByID( DynamicListsFilterSettings.BlankAttributes.skipped );
	FilterItem.RightValue = ShowIgnoredlank;
	FilterItem.Use  = Not ShowIgnoredlank;
	
	If Update Then
		UpdateAtServer("BlankAttributes");
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowIgnoredUnacceptedAtServer(Update = True)
	
	Items.UnacceptedByDateShowIgnoredUnaccepted.Check = ShowIgnoredUnaccepted;
	
	Filter = UnacceptedByDate.SettingsComposer.Settings.Filter;
	FilterItem = Filter.GetObjectByID( DynamicListsFilterSettings.UnacceptedByDate.VersionIgnored );
	FilterItem.RightValue = ShowIgnoredUnaccepted;
	FilterItem.Use  = Not ShowIgnoredUnaccepted;
	
	If Update Then
		UpdateAtServer("UnacceptedByDate");
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowIgnoredNotPostedAtServer(Update = True)
	
	Items.UnpostedDocumentsShowIgnoredNotPosted.Check = ShowIgnoredNotPosted;
	
	Filter = UnpostedDocuments.SettingsComposer.Settings.Filter;
	FilterItem = Filter.GetObjectByID( DynamicListsFilterSettings.UnpostedDocuments.skipped );
	FilterItem.RightValue = ShowIgnoredNotPosted;
	FilterItem.Use  = Not ShowIgnoredNotPosted;
	
	If Update Then
		UpdateAtServer("UnpostedDocuments");
	EndIf;
	
EndProcedure


&AtServer
Procedure PostDocuments(Val SelectedRows)
	
	For Each SelectedRow IN SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicalListGroupRow") Then
			Continue;
		EndIf;
		
		DocumentObject = SelectedRow.ProblematicObject.GetObject();
		
		If DocumentObject.CheckFilling() Then
			
			DocumentObject.Write(DocumentWriteMode.Posting);
			
		EndIf;
	
	EndDo;
	
EndProcedure

&AtServer
Procedure FillNodeList()
	
	ExchangeByRulesAbsent = True;
	ContextOpen = ValueIsFilled(Parameters.ExchangeNodes);
	
	ExchangeNodes = ?(ContextOpen, Parameters.ExchangeNodes, NodeArrayOnNonContextOpening());
	Items.InfobaseNode.ChoiceList.LoadValues(ExchangeNodes);
	
	For Each ExchangeNode IN ExchangeNodes Do
		
		If DataExchangeReUse.IsUniversalDataExchangeNode(ExchangeNode) Then
			
			ExchangeByRulesAbsent = False;
			
		EndIf;
		
	EndDo;
	
	If ContextOpen Then
		
		SetNodFilter(ExchangeNodes);
		ListOfNodes = New ValueList;
		ListOfNodes.LoadValues(ExchangeNodes);
		
	EndIf;
	
	If ContextOpen AND ExchangeNodes.Count() = 1 Then
		
		InfobaseNode = Undefined;
		Items.InfobaseNode.Visible = False;
		Items.UnpostedDocumentsInfobaseNode.Visible = False;
		Items.BlankAttributesInfobaseNode.Visible = False;
		
		If UseVersioning Then
			Items.CollisionsOtherVersionAuthor.Visible = False;
			Items.UnacceptedByDateOtherVersionAuthor.Visible = False;
		EndIf;
		
	ElsIf ExchangeNodes.Count() >= 7 Then
		
		Items.InfobaseNode.ListChoiceMode = False;
		
	EndIf;
	
	If ContextOpen AND ExchangeByRulesAbsent Then
		Title = NStr("en = 'Conflicts when synchronizing the data'");
		Items.SearchString.Visible = False;
		Items.DataExchangeResults.CurrentPage = Items.DataExchangeResults.ChildItems.CollisionsPage;
		Items.DataExchangeResults.PagesRepresentation = FormPagesRepresentation.None;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetNodFilter(ExchangeNodes)
	
	NodFilertDocument = FilterDynamicListItem(UnpostedDocuments,
		DynamicListsFilterSettings.UnpostedDocuments.NodeInList);
	NodFilertDocument.Use = True;
	NodFilertDocument.RightValue = ExchangeNodes;
	
	SelectionByNodesObject = FilterDynamicListItem(BlankAttributes,
		DynamicListsFilterSettings.BlankAttributes.NodeInList);
	SelectionByNodesObject.Use = True;
	SelectionByNodesObject.RightValue = ExchangeNodes;
	
	If UseVersioning Then
		
		NodFilterColissions = FilterDynamicListItem(Collisions,
			DynamicListsFilterSettings.Collisions.AuthorInList);
		NodFilterColissions.Use = True;
		NodFilterColissions.RightValue = ExchangeNodes;
		
		NodesFilterUnaccepted = FilterDynamicListItem(UnacceptedByDate,
			DynamicListsFilterSettings.UnacceptedByDate.AuthorInList);
		NodesFilterUnaccepted.Use = True;
		NodesFilterUnaccepted.RightValue = ExchangeNodes;
		
	EndIf;
	
EndProcedure

&AtServer
Function NodeArrayOnNonContextOpening()
	
	ExchangeNodes = New Array;
	
	ExchangePlanList = DataExchangeReUse.SSLExchangePlans();
	
	For Each ExchangePlanName IN ExchangePlanList Do
		
		If Not AccessRight("Read", ExchangePlans[ExchangePlanName].EmptyRef().Metadata()) Then
			Continue;
		EndIf;	
		Query = New Query;
		Query.SetParameter("ThisNode", ExchangePlans[ExchangePlanName].ThisNode());
		Query.Text =
		"SELECT ALLOWED
		|	ExchangePlanTable.Ref AS ExchangeNode
		|FROM
		|	&ExchangePlanTable AS ExchangePlanTable
		|WHERE
		|	ExchangePlanTable.Ref <> &ThisNode
		|	AND ExchangePlanTable.Ref.DeletionMark = FALSE
		|
		|ORDER BY
		|	Presentation";
		Query.Text = StrReplace(Query.Text, "&ExchangePlanTable", "ExchangePlan." + ExchangePlanName);
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			ExchangeNodes.Add(Selection.ExchangeNode);
			
		EndDo;
		
	EndDo;
	
	Return ExchangeNodes;
	
EndFunction

&AtServer
Procedure RefreshNodFilter(Update = True)
	
	Use = ValueIsFilled(InfobaseNode);
	
	NodFilterDocument = FilterDynamicListItem(UnpostedDocuments,
		DynamicListsFilterSettings.UnpostedDocuments.NodeEqual);
	NodFilterDocument.Use = Use;
	NodFilterDocument.RightValue = InfobaseNode;
	
	SelectionByNodeObject = FilterDynamicListItem(BlankAttributes,
		DynamicListsFilterSettings.BlankAttributes.NodeEqual);
	SelectionByNodeObject.Use = Use;
	SelectionByNodeObject.RightValue = InfobaseNode;
	
	If UseVersioning Then
		
		NodFilterColision = FilterDynamicListItem(Collisions,
			DynamicListsFilterSettings.Collisions.AuthorEqual);
		NodFilterColision.Use = Use;
		NodFilterColision.RightValue = InfobaseNode;
		
		NodFilterUnaccepted = FilterDynamicListItem(UnacceptedByDate,
			DynamicListsFilterSettings.UnacceptedByDate.AuthorEqual);
		NodFilterUnaccepted.Use = Use;
		NodFilterUnaccepted.RightValue = InfobaseNode;
		
	EndIf;
	
	If Update Then
		UpdateAtServer();
	EndIf;
EndProcedure

&AtServer
Function NumberOfUnaccepted()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, ListOfNodes);
	
	Return DataExchangeServer.VersioningProblemsCount(ExchangeNodes, False,
		ShowIgnoredConflicts, Period, SearchString);
	
EndFunction

&AtServer
Function NumberOfColission()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, ListOfNodes);
	
	Return DataExchangeServer.VersioningProblemsCount(ExchangeNodes, True,
		ShowIgnoredConflicts, Period, SearchString);
	
EndFunction

&AtServer
Function CountBlankAttributes()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, ListOfNodes);
	
	Return InformationRegisters.DataExchangeResults.CountProblems(ExchangeNodes, Enums.DataExchangeProblemTypes.BlankAttributes,
		ShowIgnoredlank, Period, SearchString);
	
EndFunction

&AtServer
Function UnpostedDocumentsCount()
	
	ExchangeNodes = ?(ValueIsFilled(InfobaseNode), InfobaseNode, ListOfNodes);
	
	Return InformationRegisters.DataExchangeResults.CountProblems(ExchangeNodes, Enums.DataExchangeProblemTypes.UnpostedDocument,
		ShowIgnoredNotPosted, Period, SearchString);
	
EndFunction

&AtServer
Procedure SetPageHeader(Page, Title, Quantity)
	
	AdditionalString = ?(Quantity > 0, " (" + Quantity + ")", "");
	Title = Title + AdditionalString;
	Page.Title = Title;
	
EndProcedure

&AtClient
Procedure OpenObject(Item)
	
	If Item.CurrentRow = Undefined Or TypeOf(Item.CurrentRow) = Type("DynamicalListGroupRow") Then
		ShowMessageBox(, NStr("en = 'The command can not be run for the specified object.'"));
		Return;
	Else
		ShowValue(, Item.CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure ObjectModifying()
	
	ResultsPage = Items.DataExchangeResults;
	
	If ResultsPage.CurrentPage = ResultsPage.ChildItems.UnpostedDocumentsPage Then
		
		OpenObject(Items.UnpostedDocuments); 
		
	ElsIf ResultsPage.CurrentPage = ResultsPage.ChildItems.BlankAttributesPage Then
		
		OpenObject(Items.BlankAttributes);
		
	ElsIf ResultsPage.CurrentPage = ResultsPage.ChildItems.CollisionsPage Then
		
		OpenObject(Items.Collisions);
		
	ElsIf ResultsPage.CurrentPage = ResultsPage.ChildItems.PageUnacceptedByProhibitionDate Then
		
		OpenObject(Items.UnacceptedByDate);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowDifference(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	ComparedVersions = New Array;
	
	If Item.CurrentData.ThisVersionNumber <> 0 Then
		ComparedVersions.Add(Item.CurrentData.ThisVersionNumber);
	EndIf;
	
	If Item.CurrentData.OtherVersionNumber <> 0 Then
		ComparedVersions.Add(Item.CurrentData.OtherVersionNumber);
	EndIf;
	
	If ComparedVersions.Count() <> 2 Then
		
		CommonUseClientServer.MessageToUser(NStr("en = 'There is no version for comparison.'"));
		Return;
		
	EndIf;
	
	DataExchangeClient.OnReportFormByVersionOpen(Item.CurrentData.Ref, ComparedVersions);
	
EndProcedure

&AtServer
Procedure RefreshReasonFilter(Update = True)
	
	SearchSringSet = ValueIsFilled(SearchString);
	
	CommonUseClientServer.SetFilterDynamicListItem(
		UnpostedDocuments, "Cause", SearchString,,, SearchSringSet);
	
	CommonUseClientServer.SetFilterDynamicListItem(
		BlankAttributes, "Cause", SearchString,,, SearchSringSet);
		
	If UseVersioning Then
	
		CommonUseClientServer.SetFilterDynamicListItem(
			UnacceptedByDate, "CauseBan", SearchString,,, SearchSringSet);
		
	EndIf;
	
	If Update Then
		
		UpdateAtServer();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshPeriodFilter(Update = True)
	
	Use = ValueIsFilled(Period);
	
	// Unposted documents
	PeriodFilterDocumentForm = FilterDynamicListItem(UnpostedDocuments,
		DynamicListsFilterSettings.UnpostedDocuments.StartDate);
	PeriodFilterDocumentTo = FilterDynamicListItem(UnpostedDocuments,
		DynamicListsFilterSettings.UnpostedDocuments.EndDate);
		
	PeriodFilterDocumentForm.Use  = Use;
	PeriodFilterDocumentTo.Use = Use;
	
	PeriodFilterDocumentForm.RightValue  = Period.StartDate;
	PeriodFilterDocumentTo.RightValue = Period.EndDate;
	
	// Blank attributes
	PeriodFilterObjectFrom = FilterDynamicListItem(BlankAttributes,
		DynamicListsFilterSettings.BlankAttributes.StartDate);
	PeriodFilterObjectBy = FilterDynamicListItem(BlankAttributes,
		DynamicListsFilterSettings.BlankAttributes.EndDate);
		
	PeriodFilterObjectFrom.Use  = Use;
	PeriodFilterObjectBy.Use = Use;
	
	PeriodFilterObjectFrom.RightValue  = Period.StartDate;
	PeriodFilterObjectBy.RightValue = Period.EndDate;
	
	If UseVersioning Then
		
		PeriodFilterCollisionsFrom = FilterDynamicListItem(Collisions,
			DynamicListsFilterSettings.Collisions.StartDate);
		PeriodFilterColissionsTo = FilterDynamicListItem(Collisions,
			DynamicListsFilterSettings.Collisions.EndDate);
		
		PeriodFilterCollisionsFrom.Use  = Use;
		PeriodFilterColissionsTo.Use = Use;
		
		PeriodFilterCollisionsFrom.RightValue  = Period.StartDate;
		PeriodFilterColissionsTo.RightValue = Period.EndDate;
		
		PeriodFilterDeclinedFrom = FilterDynamicListItem(UnacceptedByDate,
			DynamicListsFilterSettings.UnacceptedByDate.StartDate);
		PeriodFilterUnacceptedTo = FilterDynamicListItem(UnacceptedByDate,
			DynamicListsFilterSettings.UnacceptedByDate.EndDate);
		
		PeriodFilterDeclinedFrom.Use  = Use;
		PeriodFilterUnacceptedTo.Use = Use;
		
		PeriodFilterDeclinedFrom.RightValue  = Period.StartDate;
		PeriodFilterUnacceptedTo.RightValue = Period.EndDate;
		
	EndIf;
	
	If Update Then
		UpdateAtServer();
	EndIf;
EndProcedure

&AtServer
Procedure IgnoreVersion(Val SelectedRows, Ignore, ItemName)
	
	For Each SelectedRow IN SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicalListGroupRow") Then
			Continue;
		EndIf;
		
		DataExchangeServer.OnObjectVersioningIgnoring(SelectedRow.Object, SelectedRow.VersionNumber, Ignore);
		
	EndDo;
	
	UpdateAtServer(ItemName);
	
EndProcedure

&AtServer
Procedure UpdateAtServer(UpdatingElement = "")
	
	FormListsRefresh(UpdatingElement);
	PageHeaderRefresh();
	
EndProcedure

&AtServer
Procedure FormListsRefresh(UpdatingElement)
	
	If ValueIsFilled(UpdatingElement) Then
		
		Items[UpdatingElement].Refresh();
		
	Else
		
		Items.UnpostedDocuments.Refresh();
		Items.BlankAttributes.Refresh();
		If UseVersioning Then
			Items.Collisions.Refresh();
			Items.UnacceptedByDate.Refresh();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure PageHeaderRefresh()
	
	SetPageHeader(Items.UnpostedDocumentsPage, NStr("en= 'Unposted documents'"), UnpostedDocumentsCount());
	SetPageHeader(Items.BlankAttributesPage, NStr("en= 'Blank attributes'"), CountBlankAttributes());
	
	If UseVersioning Then
		SetPageHeader(Items.CollisionsPage, NStr("en= 'Conflicts'"), NumberOfColission());
		SetPageHeader(Items.PageUnacceptedByProhibitionDate, NStr("en= 'Unaccepted by prohibition date'"), NumberOfUnaccepted());
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenVersionClient(CurrentData, Version)
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ComparedVersions = New Array;
	ComparedVersions.Add(Version);
	DataExchangeClient.OnReportFormByVersionOpen(CurrentData.Ref, ComparedVersions);
	
EndProcedure

&AtServer
Procedure AcceptRejectVersionAtServer(Val SelectedRows, ItemName)
	
	For Each SelectedRow IN SelectedRows Do
		
		If TypeOf(SelectedRow) = Type("DynamicalListGroupRow") Then
			Continue;
		EndIf;
		
		DataExchangeServer.OnTransitionToObjectVersioning(SelectedRow.Object, SelectedRow.VersionNumber);
		
	EndDo;
	
	UpdateAtServer(ItemName);
	
EndProcedure

&AtServer
Procedure CustomizeSelectionsForDynamicLists(Result)
	
	Result = New Structure;
	
	// Unposted documents
	Filter = UnpostedDocuments.SettingsComposer.Settings.Filter;
	Result.Insert("UnpostedDocuments", New Structure);
	Setting = Result.UnpostedDocuments;
	
	Setting.Insert("skipped", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "skipped", DataCompositionComparisonType.Equal, False, ,True)));
	Setting.Insert("StartDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "AppearanceDate", DataCompositionComparisonType.GreaterOrEqual, '00010101', , True)));
	Setting.Insert("EndDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "AppearanceDate", DataCompositionComparisonType.LessOrEqual, '00010101', , True)));
	Setting.Insert("NodeEqual", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "InfobaseNode", DataCompositionComparisonType.Equal, Undefined, , False)));
	Setting.Insert("Cause", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "Cause", DataCompositionComparisonType.Contains, Undefined, , False)));
	Setting.Insert("NodeInList", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "InfobaseNode", DataCompositionComparisonType.InList, Undefined, , False)));
		
	// Blank attributes
	Filter = BlankAttributes.SettingsComposer.Settings.Filter;
	Result.Insert("BlankAttributes", New Structure);
	Setting = Result.BlankAttributes;
	
	Setting.Insert("skipped", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "skipped", DataCompositionComparisonType.Equal, False, ,True)));
	Setting.Insert("StartDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "AppearanceDate", DataCompositionComparisonType.GreaterOrEqual, '00010101', , True)));
	Setting.Insert("EndDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "AppearanceDate", DataCompositionComparisonType.LessOrEqual, '00010101', , True)));
	Setting.Insert("NodeEqual", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "InfobaseNode", DataCompositionComparisonType.Equal, Undefined, , False)));
	Setting.Insert("Cause", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "Cause", DataCompositionComparisonType.Contains, Undefined, , False)));
	Setting.Insert("NodeInList", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "InfobaseNode", DataCompositionComparisonType.InList, Undefined, , False)));
		
	If UseVersioning Then
		
		// Conflicts
		Filter = Collisions.SettingsComposer.Settings.Filter;
		Result.Insert("Collisions", New Structure);
		Setting = Result.Collisions;
		
		Setting.Insert("AuthorEqual", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "OtherVersionAuthor", DataCompositionComparisonType.Equal, Undefined, ,False)));
		Setting.Insert("StartDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "Date", DataCompositionComparisonType.GreaterOrEqual, '00010101', , True)));
		Setting.Insert("EndDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "Date", DataCompositionComparisonType.LessOrEqual, '00010101', , True)));
		Setting.Insert("VersionIgnored", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "VersionIgnored", DataCompositionComparisonType.Equal, False, , True)));
		Setting.Insert("AuthorInList", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "OtherVersionAuthor", DataCompositionComparisonType.InList, Undefined, ,False)));
		
		// Unaccepted by prohibition date
		Filter = UnacceptedByDate.SettingsComposer.Settings.Filter;
		Result.Insert("UnacceptedByDate", New Structure);
		Setting = Result.UnacceptedByDate;
		
		Setting.Insert("AuthorEqual", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "OtherVersionAuthor", DataCompositionComparisonType.Equal, Undefined, ,False)));
		Setting.Insert("StartDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "Date", DataCompositionComparisonType.GreaterOrEqual, '00010101', , True)));
		Setting.Insert("EndDate", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "Date", DataCompositionComparisonType.LessOrEqual, '00010101', , True)));
		Setting.Insert("CauseBan", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "CauseBan", DataCompositionComparisonType.Equal, Undefined, , False)));
		Setting.Insert("VersionIgnored", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "VersionIgnored", DataCompositionComparisonType.Equal, False, , True)));
		Setting.Insert("AuthorInList", Filter.GetIDByObject(
		CommonUseClientServer.AddCompositionItem(Filter, "OtherVersionAuthor", DataCompositionComparisonType.InList, Undefined, ,False)));
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function FilterDynamicListItem(Val DynamicList, Val ID)
	Return DynamicList.SettingsComposer.Settings.Filter.GetObjectByID(ID);
EndFunction

&AtServer
Procedure RefreshSelectionsAndIgnored()
	
	RefreshPeriodFilter(False);
	RefreshNodFilter(False);
	RefreshReasonFilter(False);
	
	ShowIgnoredNotPostedAtServer(False);
	ShowIgnoredBlankAtServer(False);
	
	If UseVersioning Then
		
		ShowIgnoredConflictsAtServer(False);
		ShowIgnoredUnacceptedAtServer(False);
		
	EndIf;
	
	UpdateAtServer();
	
	If Not Items.DataExchangeResults.CurrentPage = Items.DataExchangeResults.ChildItems.CollisionsPage Then
		
		For Each Page IN Items.DataExchangeResults.ChildItems Do
			
			If Find(Page.Title, "(") Then
				Items.DataExchangeResults.CurrentPage = Page;
				Break;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
