
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

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
// Procedure updates data in the list table.
//
Procedure UpdateListTaskByPeriod()
	
	List.Parameters.SetParameterValue("PeriodOfBegin", Date(1,1,1));
	List.Parameters.SetParameterValue("PeriodOfEnd", Date(1,1,1));
	
EndProcedure // UpdateListTaskByPeriod()

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
		FormHeaderText = "Work orders: overdue";
		List.Parameters.SetParameterValue("PeriodOfEnd", CurrentSessionDate());
		SmallBusinessClientServer.SetListFilterItem(List, "Overdue", True);
	EndIf;
	
	If Parameters.Property("ForToday") Then
		FormHeaderText = "Work orders: for today";
		List.Parameters.SetParameterValue("PeriodOfBegin", EndOfDay(CurrentSessionDate()));
		List.Parameters.SetParameterValue("PeriodOfEnd", CurrentSessionDate());
		SmallBusinessClientServer.SetListFilterItem(List, "ForToday", True);
	EndIf;
	
	If Parameters.Property("Planned") Then
		FormHeaderText = "Work orders: planned";
	EndIf;
	
	If Parameters.Property("OnControl") Then
		FormHeaderText = "Work orders: on control";
	EndIf;
	
	If Parameters.Property("Responsible") Then
		SmallBusinessClientServer.SetListFilterItem(List, "Employee", Parameters.Responsible.List, True, DataCompositionComparisonType.InList);
		FormHeaderText = FormHeaderText + ", responsible " + Parameters.Responsible.Initials;
	EndIf;
	
	If Parameters.Property("Performer") Then
		SmallBusinessClientServer.SetListFilterItem(List, "Employee", Parameters.Performer, True, DataCompositionComparisonType.NotInList);
	EndIf;
	
	If Parameters.Property("Author") Then
		SmallBusinessClientServer.SetListFilterItem(List, "Author", Parameters.Author.User);
		FormHeaderText = FormHeaderText + ", author " + Parameters.Author.Initials;
	EndIf;
	
	If Not IsBlankString(FormHeaderText) Then
		AutoTitle = False;
		Title = FormHeaderText;
	EndIf;
	
EndProcedure // SetFilterCurrentWorks()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PaintList();
	UpdateListTaskByPeriod();
	
	SetFilterCurrentWorks();
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

// Procedure - handler of form notification.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_EventStates" Then
		PaintList();
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion













