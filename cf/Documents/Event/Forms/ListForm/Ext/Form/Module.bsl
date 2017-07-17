
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PaintList();
	
	SetFilterCurrentWorks();
	SetFilterEventType();
	
	If Parameters.Property("Contact") And ValueIsFilled(Parameters.Contact) Then
		ContextContact	= Parameters.Contact;
		CommonUseClientServer.SetFilterDynamicListItem(List, "TPParticipants.Contact", Parameters.Contact);
		Items.FilterCounterparty.Visible = False;
	EndIf;
	
	If Parameters.Property("BasisDocument") And ValueIsFilled(Parameters.BasisDocument) Then
		FilterBasis = Parameters.BasisDocument;
		CommonUseClientServer.SetFilterDynamicListItem(List, "BasisDocument", FilterBasis);
	EndIf;
	
	ContextOpening = Parameters.Property("CurrentWorks") Or Parameters.Property("Contact") Or Parameters.Property("BasisDocument");
	
	If Not ContextOpening Then
		
		// SB.ListFilters
		WorkWithFilters.RestoreFilterSettings(ThisObject, List,,,,FilterEventType);
		// End SB.ListFilters
		
	EndIf;
	
	PeriodPresentation = WorkWithFiltersClientServer.RefreshPeriodPresentation(FilterPeriod);
	
	// SB.ContactInformationPanel
	ContactInformationPanelSB.OnCreateAtServer(ThisObject, "ContactInformation");
	// End SB.ContactInformationPanel
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.GroupImportantCommands);
	// End StandardSubsystems.Printing
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If Not ContextOpening Then
		//SB.ListFilter
		SaveFilterSettings();
		//End SB.ListFilter
	EndIf; 
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_EventStates" Then
		PaintList();
	EndIf;
	
	// SB.ContactInformationPanel
	If ContactInformationPanelSBClient.ProcessNotifications(ThisObject, EventName, Parameter) Then
		RefreshContactInformationPanelServer();
	EndIf;
	// End SB.ContactInformationPanel
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	If TypeOf(Item.CurrentRow) <> Type("DynamicalListGroupRow") Then
		
		AttachIdleHandler("HandleActivateListRow", 0.2, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	FillingValue = New Structure;
	If ValueIsFilled(Parameters.EventType) Then
		FillingValue.Insert("EventType", Parameters.EventType);
	EndIf;
	FormParameters = New Structure;
	
	If ValueIsFilled(FilterBasis) Then
		
		Cancel = True;
		
		FillingValue.Insert("FillingBasis", FilterBasis);
		FormParameters.Insert("FillingValues", FillingValue);
		OpenForm("Document.Event.ObjectForm", FormParameters);
		
	ElsIf ValueIsFilled(ContextContact) Then
		
		Cancel = True;
		
		FillingValue.Insert("FillingBasis", ContextContact);
		FormParameters.Insert("FillingValues", FillingValue);
		OpenForm("Document.Event.ObjectForm", FormParameters);
		
	Else
		
		FilterByCounterparty = GetFilterByCounterparty();
		
		If FilterByCounterparty <> Undefined Then
			
			Cancel = True;
			
			FillingValue.Insert("FillingBasis", FilterByCounterparty);
			FormParameters.Insert("FillingValues", FillingValue);
			OpenForm("Document.Event.ObjectForm", FormParameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PeriodPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithFiltersClient.PeriodPresentationSelectPeriod(ThisObject, , "EventBegin");
	
EndProcedure

&AtClient
Procedure FilterCounterpartyChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	CounterpartyContacts = GetCounterpartyContacts(SelectedValue);
	
	SetLabelAndListFilter("TPParticipants.Contact", Item.Parent.Name, CounterpartyContacts, String(SelectedValue));
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterResponsibleChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("Responsible", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterEventTypeChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("EventType", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterStateChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("State", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterProjectChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("Project", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure CollapseExpandFiltesPanelClick(Item)
	
	NewValueVisible = Not Items.FilterSettingsAndAddInfo.Visible;
	WorkWithFiltersClient.CollapseExpandFiltesPanel(ThisObject, NewValueVisible);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateEvent(Command)
	
	FillingValue = New Structure;
	FillingValue.Insert("EventType", PredefinedValue("Enum.EventTypes." + Mid(Command.Name, 7)));
	If ValueIsFilled(FilterBasis) Then
		FillingValue.Insert("FillingBasis", FilterBasis);
	ElsIf ValueIsFilled(ContextContact) Then
		FillingValue.Insert("FillingBasis", ContextContact);
	Else
		FillingValue.Insert("FillingBasis", New Structure);
		If ValueIsFilled(FilterResponsible) Then
			FillingValue.FillingBasis.Insert("Responsible", FilterResponsible);
		EndIf;
		If ValueIsFilled(FilterState) Then
			FillingValue.FillingBasis.Insert("State", FilterState);
		EndIf;
		FilterByCounterparty = GetFilterByCounterparty();
		If ValueIsFilled(FilterByCounterparty) Then
			FillingValue.FillingBasis.Insert("Contact", FilterByCounterparty);
		EndIf;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("FillingValues", FillingValue);
	
	OpenForm("Document.Event.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

#EndRegion

#Region CommonProceduresAndFunctions

&AtServer
Procedure PaintList()
	
	// List coloring
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem IN List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item IN ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	SelectionEventStates = Catalogs.EventStates.Select();
	While SelectionEventStates.Next() Do
		
		BackColor = SelectionEventStates.Color.Get();
		If TypeOf(BackColor) <> Type("Color") Then
			Continue;
		EndIf; 
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("State");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = SelectionEventStates.Ref;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColor);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = NStr("ru = 'По состоянию события '; en = 'By event state '") + SelectionEventStates.Description;
	
	EndDo;
	
EndProcedure

&AtServer
Procedure SetFilterCurrentWorks()
	
	If Not Parameters.Property("CurrentWorks") Then
		Return;
	EndIf;
	
	AutoTitle	= False;
	Title		= NStr("ru='События'; en = 'Events'");
	CurDate		= CurrentSessionDate();
	
	CommonUseClientServer.SetFilterDynamicListItem(
		List,
		"DeletionMark",
		False
	);
	
	StateList = New ValueList;
	StateList.Add(Catalogs.EventStates.Canceled);
	StateList.Add(Catalogs.EventStates.Completed);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	EventStates.Ref
		|FROM
		|	Catalog.EventStates AS EventStates
		|WHERE
		|	EventStates.DeletionMark = FALSE
		|	AND NOT EventStates.Ref IN (&StateList)";
	
	Query.SetParameter("StateList", StateList);
	Selection = Query.Execute().Select();
	StateList.Clear();
	
	While Selection.Next() Do
		StateList.Add(Selection.Ref);
	EndDo;
	
	WorkWithFilters.AttachFilterLabelsFromArray(ThisObject, "State", "States", StateList);
	WorkWithFilters.SetListFilter(ThisObject, List, "State");
	
	WorkWithFilters.AttachFilterLabelsFromArray(ThisObject, "Responsible", "Responsibles", SmallBusinessServer.GetUserEmployees());
	WorkWithFilters.SetListFilter(ThisObject, List, "Responsible");
	
	If Parameters.Property("PastPerformance") Then
		
		Title = Title + ": " + NStr("ru='просрочено выполнение'; en = 'expired'");
		SmallBusinessClientServer.SetListFilterItem(
			List, 
			"EventBegin", 
			Date('00010101'), 
			True, 
			DataCompositionComparisonType.NotEqual
		);
		SmallBusinessClientServer.SetListFilterItem(
			List, 
			"EventEnding", 
			CurrentSessionDate(), 
			True, 
			DataCompositionComparisonType.Less
		);
		Items.PeriodPresentation.Visible	= False;
		
	ElsIf Parameters.Property("ForToday") Then
		
		Title = Title + ": " + NStr("ru='на сегодня'; en = 'as of today'");
		SmallBusinessClientServer.SetListFilterItem(
			List, 
			"EventBegin", 
			EndOfDay(CurrentSessionDate()), 
			True, 
			DataCompositionComparisonType.LessOrEqual);
		SmallBusinessClientServer.SetListFilterItem(
			List, 
			"EventEnding", 
			CurrentSessionDate(), 
			True, 
			DataCompositionComparisonType.GreaterOrEqual);
		Items.PeriodPresentation.Visible	= False;
		
	ElsIf Parameters.Property("InProcess") Then
		
		Title = Title + ": " + NStr("ru='в работе'; en = 'in process'");
		
	EndIf;
	
	If Items.PeriodPresentation.Visible Then
		PeriodPresentation = WorkWithFiltersClientServer.RefreshPeriodPresentation(FilterPeriod);
	EndIf;
	
	WorkWithFilters.RefreshLabelItems(ThisObject);
	
EndProcedure // SetFilterCurrentWorks()

&AtServer
Procedure SetFilterEventType()
	
	If Not ValueIsFilled(Parameters.EventType) Then
		Return;
	Else
		FilterEventType = Parameters.EventType;
	EndIf;
	
	AutoTitle = False;
	Items.FilterEventType.Visible	= False;
	Items.ListGroupCreate.Visible	= False;
	Items.FormCreate.Visible		= True;
	
	CommonUseClientServer.SetFilterDynamicListItem(
		List,
		"EventType",
		Parameters.EventType
	);
	
	Items.IncomingOutgoing.Visible	= Parameters.EventType <> Enums.EventTypes.SMS;
	Items.Projects.Visible			= Not (Parameters.EventType = Enums.EventTypes.SMS
														Or Parameters.EventType = Enums.EventTypes.Email);
														
	If Parameters.EventType = Enums.EventTypes.PhoneCall Then
		Title = NStr("ru='События: телефонные звонки'; en = 'Events: phone calls'");
	ElsIf Parameters.EventType = Enums.EventTypes.Email Then
		Title = NStr("ru='События: электронные письма'; en = 'Events: emails'");
	ElsIf Parameters.EventType = Enums.EventTypes.SMS Then
		Title = NStr("ru='События: сообщения SMS'; en = 'Events: SMS'");
	ElsIf Parameters.EventType = Enums.EventTypes.PersonalMeeting Then
		Title = NStr("ru='События: личные встречи'; en = 'Events: personal meetings'");
	ElsIf Parameters.EventType = Enums.EventTypes.Other Then
		Title = NStr("ru='События: прочие'; en = 'Events: other'");
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetCounterpartyContacts(Counterparty)
	
	Contacts = New Array;
	
	If Not ValueIsFilled(Counterparty) Then
		Return Contacts;
	EndIf;
	
	Contacts.Add(Counterparty);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ContactPersons.Ref
		|FROM
		|	Catalog.ContactPersons AS ContactPersons
		|WHERE
		|	ContactPersons.Owner = &Counterparty
		|	AND ContactPersons.DeletionMark = FALSE";
	
	Query.SetParameter("Counterparty", Counterparty);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Contacts.Add(Selection.Ref);
	EndDo;
	
	Return Contacts;
	
EndFunction

&AtClient
Procedure HandleActivateListRow()
	
	RefreshContactInformationPanelServer();
	
EndProcedure

&AtClient
Function GetFilterByCounterparty()
	
	FindedRows = LabelData.FindRows(New Structure("FilterFieldName", "TPParticipants.Contact"));
	FilterByCounterparty = Undefined;
	
	For Each FindedRow In FindedRows Do
		If TypeOf(FindedRow.Label) = Type("ValueList") Then
			For Each ListItem In FindedRow.Label Do
				If TypeOf(ListItem.Value) = Type("CatalogRef.Counterparties") Then
					FilterByCounterparty = ListItem.Value;
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	Return FilterByCounterparty;
	
EndFunction

#EndRegion

#Region ContactInformationPanel

&AtServer
Procedure RefreshContactInformationPanelServer()
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	Counterparties.Ref AS Counterparty
	|FROM
	|	Document.Event.Participants AS EventParticipants
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON EventParticipants.Contact = Counterparties.Ref
	|WHERE
	|	EventParticipants.Ref = &Event";
	
	Query.SetParameter("Event", Items.List.CurrentRow);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		ContactInformationPanelSB.RefreshPanelData(ThisObject, Selection.Counterparty);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ContactInformationPanelSBClient.ContactInformationPanelDataSelection(ThisObject, Item, SelectedRow, Field, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataOnActivateRow(Item)
	
	ContactInformationPanelSBClient.ContactInformationPanelDataOnActivateRow(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataExecuteCommand(Command)
	
	ContactInformationPanelSBClient.ExecuteCommand(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region FilterLabel

&AtServer
Procedure SetLabelAndListFilter(ListFilterFieldName, GroupLabelParent, SelectedValue, ValuePresentation="")
	
	If ValuePresentation="" Then
		ValuePresentation=String(SelectedValue);
	EndIf; 
	
	WorkWithFilters.AttachFilterLabel(ThisObject, ListFilterFieldName, GroupLabelParent, SelectedValue, ValuePresentation);
	WorkWithFilters.SetListFilter(ThisObject, List, ListFilterFieldName,,True);
	
EndProcedure

&AtClient
Procedure Attachable_LabelURLProcessing(Item, URLFS, StandardProcessing)
	
	StandardProcessing = False;
	
	LabelID = Mid(Item.Name, StrLen("Label_")+1);
	DeleteFilterLabel(LabelID);
	
EndProcedure

&AtServer
Procedure DeleteFilterLabel(LabelID)
	
	WorkWithFilters.DeleteFilterLabelServer(ThisObject, List, LabelID);

EndProcedure

&AtServer
Procedure SaveFilterSettings()
	
	WorkWithFilters.SaveFilterSettings(ThisObject,,,FilterEventType);
	
EndProcedure

#EndRegion

#Region EmailSB
	
&AtClient
Procedure FilterIncomingOutgoingOnChange(Item)
	
	SetFilterIncomingOutgoing();
	
EndProcedure

&AtClient
Procedure FilterAccountChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("UserAccount", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;

EndProcedure

&AtServer
Procedure SetFilterIncomingOutgoing()
	
	If ValueIsFilled(FilterIncomingOutgoing) Then
		SmallBusinessClientServer.SetListFilterItem(List, "IncomingOutgoing", FilterIncomingOutgoing);
	Else
		SmallBusinessClientServer.DeleteListFilterItem(List, "IncomingOutgoing");
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Printing

&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion
