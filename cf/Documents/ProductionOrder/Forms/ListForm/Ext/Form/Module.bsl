// Procedure colors list.
//
&AtServer
Procedure PaintList()
	
	// List coloring
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem IN List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset"
			OR ConditionalAppearanceItem.Presentation = "Order is closed" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item IN ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	PaintByState = Constants.UseProductionOrderStates.Get();
	
	If Not PaintByState Then
		InProcessStatus = Constants.ProductionOrdersInProgressStatus.Get();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = Constants.ProductionOrdersCompletedStatus.Get();
		BackColorCompleted = CompletedStatus.Color.Get();
	EndIf;
	
	SelectionOrderStatuses = Catalogs.ProductionOrderStates.Select();
	While SelectionOrderStatuses.Next() Do
		
		If PaintByState Then
			BackColor = SelectionOrderStatuses.Color.Get();
			If TypeOf(BackColor) <> Type("Color") Then
				Continue;
			EndIf;
		Else
			If SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.InProcess Then
				If TypeOf(BackColorInProcess) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorInProcess;
			ElsIf SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.Completed Then
				If TypeOf(BackColorCompleted) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorCompleted;
			Else
				Continue;
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		If PaintByState Then
			FilterItem.LeftValue = New DataCompositionField("OrderState");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = SelectionOrderStatuses.Ref;
		Else
			FilterItem.LeftValue = New DataCompositionField("OrderStatus");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			If SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.InProcess Then
				FilterItem.RightValue = "In process";
			Else
				FilterItem.RightValue = "Completed";
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColor);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "By order state " + SelectionOrderStatuses.Description;
		
	EndDo;
	
	If PaintByState Then
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Closed");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = True;
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "Order is closed";
		
	Else
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("OrderStatus");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = "Canceled";
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		If TypeOf(BackColorCompleted) = Type("Color") Then
			ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColorCompleted);
		EndIf;
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "Order is canceled";
		
	EndIf;
	
EndProcedure // PaintList()

// Procedure sets filter in the list table for section To-do list.
//
&AtServer
Procedure SetFilterCurrentWorks()
	
	If Not Parameters.Property("CurrentWorks") Then
		Return;
	EndIf;
	
	FormHeaderText = "";
	If Parameters.Property("PastPerformance") Then
		FormHeaderText = "Production orders: performance is delayed";
		SmallBusinessClientServer.SetListFilterItem(List, "PastPerformance", True);
	EndIf;
	
	If Parameters.Property("ForToday") Then
		FormHeaderText = NStr("en = 'Production orders: as for today'");
		SmallBusinessClientServer.SetListFilterItem(List, "ForToday", True);
	EndIf;
	
	If Parameters.Property("InProcess") Then
		FormHeaderText = NStr("en = 'Production orders: in progress'");
		SmallBusinessClientServer.SetListFilterItem(List, "OrderInProcess", True);
	EndIf;
	
	If Parameters.Property("Responsible") Then
		SmallBusinessClientServer.SetListFilterItem(List, "Responsible", Parameters.Responsible.List, True, DataCompositionComparisonType.InList);
		FormHeaderText = FormHeaderText + NStr("en = ', responsible person '") + Parameters.Responsible.Initials;
	EndIf;
	
	If Not IsBlankString(FormHeaderText) Then
		AutoTitle = False;
		Title = FormHeaderText;
	EndIf;
	
	Items.FilterResponsible.Visible = False;
	Items.FilterState.Visible = False;
	Items.FilterStatus.Visible = False;
	Items.FilterActuality.Visible = False;
	
EndProcedure // SetFilterCurrentWorks()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - Form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Constants.FunctionalOptionAccountingByMultipleDepartments.Get()
		AND Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
		
		Items.FilterDepartment.ListChoiceMode = True;
		Items.FilterDepartment.ChoiceList.Add(Catalogs.StructuralUnits.MainDepartment);
		Items.FilterDepartment.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
		
	EndIf;
	
	Items.FilterActuality.ChoiceList.Add("All", "All");
	Items.FilterActuality.ChoiceList.Add("Except closed", "Except closed");
	Items.FilterActuality.ChoiceList.Add("closed", "closed");
	
	Items.FilterStatus.ChoiceList.Add("In process", "In process");
	Items.FilterStatus.ChoiceList.Add("Completed", "Completed");
	Items.FilterStatus.ChoiceList.Add("Canceled", "Canceled");
	
	PaintList();
	
	List.Parameters.SetParameterValue("CurrentDateSession", CurrentSessionDate());
	
	// Use the states of production orders.
	If Constants.UseProductionOrderStates.Get() Then
		Items.FilterStatus.Visible = False;
		Items.OrderStatus.Visible = False;
	Else
		Items.FilterState.Visible = False;
		Items.FilterActuality.Visible = False;
		Items.OrderState.Visible = False;
		Items.Closed.Visible = False;
	EndIf;
	
	SetFilterCurrentWorks();
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Parameters.Property("CurrentWorks") Then
		
		Settings.Delete("FilterCompany");
		Settings.Delete("FilterState");
		Settings.Delete("FilterStatus");
		Settings.Delete("FilterDepartment");
		Settings.Delete("FilterActuality");
		Settings.Delete("FilterResponsible");
		
	Else
		
		FilterCompany = Settings.Get("FilterCompany");
		FilterState = Settings.Get("FilterState");
		FilterStatus = Settings.Get("FilterStatus");
		FilterResponsible = Settings.Get("FilterResponsible");
		FilterDepartment = Settings.Get("FilterDepartment");
		FilterActuality = Settings.Get("FilterActuality");
		If Not ValueIsFilled(FilterActuality) Then
			FilterActuality = "All";
		EndIf;
		
		If Constants.UseProductionOrderStates.Get() Then
			FilterStatus = "";
			SmallBusinessClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
		Else
			FilterActuality = "All";
			FilterState = Catalogs.ProductionOrderStates.EmptyRef();
			SmallBusinessClientServer.SetListFilterItem(List, "OrderStatus", FilterStatus, ValueIsFilled(FilterStatus));
		EndIf;
		
		SmallBusinessClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
		SmallBusinessClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
		SmallBusinessClientServer.SetListFilterItem(List, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
		
		If FilterActuality = "Except closed" Then
			SmallBusinessClientServer.SetListFilterItem(List, "Closed", False);
		ElsIf FilterActuality = "closed" Then
			SmallBusinessClientServer.SetListFilterItem(List, "Closed", True);
		EndIf;
		
	EndIf;
	
EndProcedure // OnLoadDataFromSettingsAtServer()

// Procedure - Form event handler "NotificationProcessing".
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_ProductionOrderStates" Then
		PaintList();
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ATTRIBUTE EVENT HANDLERS

&AtClient
// Procedure - event handler OnChange input field FilterCompany.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterCompanyOnChange(Item)
	SmallBusinessClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterState.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterStateOnChange(Item)
	SmallBusinessClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
EndProcedure

// Procedure - event handler OnChange input field FilterStatus.
//
&AtClient
Procedure FilterStatusOnChange(Item)
	SmallBusinessClientServer.SetListFilterItem(List, "OrderStatus", FilterStatus, ValueIsFilled(FilterStatus));
EndProcedure // FilterStatusOnChange()

&AtClient
// Procedure - event handler OnChange input field FilterResponsible.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterResponsibleOnChange(Item)
	SmallBusinessClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterDepartment.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterDepartmentOnChange(Item)
	SmallBusinessClientServer.SetListFilterItem(List, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterActuality.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterActualityOnChange(Item)
	
	If FilterActuality = "Except closed" Then
		SmallBusinessClientServer.SetListFilterItem(List, "Closed", False, True);
	ElsIf FilterActuality = "closed" Then
	    SmallBusinessClientServer.SetListFilterItem(List, "Closed", True, True);
	ElsIf FilterActuality = "All" Then
	    SmallBusinessClientServer.SetListFilterItem(List, "Closed", True, False);
	EndIf;
	
EndProcedure

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingProductionOrder";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningProductionOrder";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
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
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion
