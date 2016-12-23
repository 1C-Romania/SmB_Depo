
#Region FormEventsHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PaintList();
	
	SetFilterCurrentWorks();
	SetFilterInformationPanel();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

&AtServer
// Procedure - form event handler BeforeImportDataFromSettingsAtServer.
//
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	
	If Parameters.Property("CurrentWorks") 
		OR Parameters.Property("InformationPanel") Then
		
		Settings.Delete("FilterCounterparty");
		Settings.Delete("FilterState");
		Settings.Delete("FilterEmployee");
		Settings.Delete("FilterEventType");
		
	Else
		
		FilterCounterparty = Settings.Get("FilterCounterparty");
		FilterState = Settings.Get("FilterState");
		FilterEmployee = Settings.Get("FilterEmployee");
		FilterEventType = Settings.Get("FilterEventType");
		
		CommonUseClientServer.SetDynamicListParameter(List, "Contact", FilterCounterparty, ValueIsFilled(FilterCounterparty));
		SmallBusinessClientServer.SetListFilterItem(List, "State", FilterState, ValueIsFilled(FilterState));
		SmallBusinessClientServer.SetListFilterItem(List, "Responsible", FilterEmployee, ValueIsFilled(FilterEmployee));
		SmallBusinessClientServer.SetListFilterItem(List, "EventType", FilterEventType, ValueIsFilled(FilterEventType));
		
	EndIf;
	
EndProcedure // BeforeImportDataFromSettingsAtServer()

// Procedure - handler of form notification.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_EventStates" Then
		PaintList();
	EndIf;
	
EndProcedure

#EndRegion

#Region CommandFormPanelsActionProcedures

// Procedure - event handler OnChange input field FilterCounterparty.
//
&AtClient
Procedure FilterCounterpartyOnChange(Item)
	
	Contacts = GetCounterpartyContacts(FilterCounterparty);
	CommonUseClientServer.SetDynamicListParameter(List, "Contacts", Contacts, Contacts.Count() > 0);
	
EndProcedure // CounterpartyOnChange()

// Procedure - handler of event OnChange of input field FilterEmployee.
//
&AtClient
Procedure FilterEmployeeOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Responsible", FilterEmployee, ValueIsFilled(FilterEmployee));
	
EndProcedure // FilterEmployeeOnChange()

// Procedure - handler of event OnChange of input field FilterEventType.
//
&AtClient
Procedure FilterEventTypeOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "EventType", FilterEventType, ValueIsFilled(FilterEventType));
	
EndProcedure // FilterEventTypeOnChange()

// Procedure - event handler OnChange input field FilterState.
//
&AtClient
Procedure FilterStateOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "State", FilterState, ValueIsFilled(FilterState));
	
EndProcedure // FilterStateOnChange()

// Procedure - Create [EventType] event handler.
//
&AtClient
Procedure CreateEvent(Command)
	
	FilledValue = New Structure;
	FilledValue.Insert("EventType", PredefinedValue("Enum.EventTypes." + Mid(Command.Name, 7)));
	If ValueIsFilled(FilterBasis) Then
		FilledValue.Insert("FillBasis", FilterBasis);
	ElsIf ValueIsFilled(FilterContactPerson) Then
		FilledValue.Insert("FillBasis", FilterContactPerson);
	Else
		FilledValue.Insert("FillBasis", New Structure("Counterparty, Responsible, State", FilterCounterparty, FilterEmployee, FilterState));
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("FillingValues", FilledValue);
	
	OpenForm("Document.Event.ObjectForm", FormParameters, ThisForm);
	
EndProcedure

#EndRegion

#Region DynamicListEventHandlers

// Procedure - BeforeAddingBegin event handler of List dynamic list.
//
&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If ValueIsFilled(FilterBasis) Then
		
		Cancel = True;
		
		FormParameters = New Structure;
		FormParameters.Insert("Basis", FilterBasis);
		OpenForm("Document.Event.ObjectForm", FormParameters);
		
	ElsIf ValueIsFilled(FilterContactPerson) Then
			
		Cancel = True;
		
		FormParameters = New Structure;
		FormParameters.Insert("Basis", FilterContactPerson);
		OpenForm("Document.Event.ObjectForm", FormParameters);
		
	EndIf;
	
EndProcedure // ListBeforeAddStart()

#EndRegion

#Region CommonUseProceduresAndFunctions

// Procedure colors list.
//
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
		ConditionalAppearanceItem.Presentation = "By event state " + SelectionEventStates.Description;
	
	EndDo;
	
EndProcedure // PaintList()

&AtServer
// Procedure sets filter in the list table for section To-do list.
//
Procedure SetFilterCurrentWorks()
	
	If Not Parameters.Property("CurrentWorks") Then
		Return;
	EndIf;
	
	ListOfState = New ValueList;
	ListOfState.Add(Catalogs.EventStates.Canceled);
	ListOfState.Add(Catalogs.EventStates.Completed);
	SmallBusinessClientServer.SetListFilterItem(List, "State", ListOfState, True, DataCompositionComparisonType.NotInList);
	
	FormHeaderText = "";
	If Parameters.Property("PastPerformance") Then
		FormHeaderText = "Events: overdue";
		SmallBusinessClientServer.SetListFilterItem(List, "EventBegin", Date('00010101'), True, DataCompositionComparisonType.NotEqual);
		SmallBusinessClientServer.SetListFilterItem(List, "EventEnding", CurrentSessionDate(), True, DataCompositionComparisonType.Less);
	EndIf;
	
	If Parameters.Property("ForToday") Then
		FormHeaderText = "Events: for today";
		SmallBusinessClientServer.SetListFilterItem(List, "EventBegin", EndOfDay(CurrentSessionDate()), True, DataCompositionComparisonType.LessOrEqual);
		SmallBusinessClientServer.SetListFilterItem(List, "EventEnding", CurrentSessionDate(), True, DataCompositionComparisonType.GreaterOrEqual);
	EndIf;
	
	If Parameters.Property("Planned") Then
		FormHeaderText = "Events: planned";
	EndIf;
	
	If Parameters.Property("Responsible") Then
		SmallBusinessClientServer.SetListFilterItem(List, "Responsible", Parameters.Responsible.List, True, DataCompositionComparisonType.InList);
		FormHeaderText = FormHeaderText + ", responsible " + Parameters.Responsible.Initials;
	EndIf;
	
	If Not IsBlankString(FormHeaderText) Then
		AutoTitle = False;
		Title = FormHeaderText;
	EndIf;
	
	Items.FilterEmployee.Visible = False;
	Items.FilterState.Visible = False;
	
EndProcedure // SetFilterCurrentWorks()

&AtServer
// The procedure sets the filter in the table of list for the information panel.
//
Procedure SetFilterInformationPanel()
	
	If Not Parameters.Property("InformationPanel") Then
		Return;
	EndIf;
	
	InformationPanel = Parameters.InformationPanel;
	If InformationPanel.Property("Counterparty") Then
		
		FilterCounterparty = InformationPanel.Counterparty;
		Contacts = GetCounterpartyContacts(FilterCounterparty);
		CommonUseClientServer.SetDynamicListParameter(List, "Contacts", Contacts, Contacts.Count() > 0);
		
	EndIf;
	
	If InformationPanel.Property("ContactPerson") Then
		
		FilterContactPerson = InformationPanel.ContactPerson;
		Contacts = New Array;
		Contacts.Add(FilterContactPerson);
		CommonUseClientServer.SetDynamicListParameter(List, "Contacts", Contacts, ValueIsFilled(FilterContactPerson));
		
		ThisForm.AutoTitle = False;
		ThisForm.Title = NStr("en=' Event (contact person: ';ru=' Событие (контактное лицо: '") + String(InformationPanel.ContactPerson) + ")";
		
		Items.FilterCounterparty.Visible = False;
		
		
	ElsIf InformationPanel.Property("BasisOrderAccounts") Then
		
		FilterBasis = InformationPanel.BasisOrderAccounts;
		CommonUseClientServer.SetDynamicListParameter(List, "BasisDocument", FilterBasis, ValueIsFilled(FilterBasis));
		
		ThisForm.AutoTitle = False;
		ThisForm.Title = NStr("en=' Event (basis: ';ru=' Событие (основание: '") + String(InformationPanel.BasisOrderAccounts) + ")";
		
		Items.FilterCounterparty.Visible = False;
		
	Else
		
		ThisForm.AutoTitle = True;
		Items.FilterCounterparty.Visible = True;
		
	EndIf;
	
	If Parameters.Property("OpeningMode") Then
		WindowOpeningMode = Parameters.OpeningMode;
	EndIf;
	
EndProcedure // SetFilterCurrentWorks()

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

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Printing

&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion














