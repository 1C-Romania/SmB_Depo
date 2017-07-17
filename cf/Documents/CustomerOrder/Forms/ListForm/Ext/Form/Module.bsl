
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Processes a row activation event of the document list.
//
&AtClient
Procedure HandleIncreasedRowsList()
	
	InfPanelParameters = New Structure("CIAttribute, Counterparty, ContactPerson", "Counterparty");
	SmallBusinessClient.InfoPanelProcessListRowActivation(ThisForm, InfPanelParameters);
	
EndProcedure // HandleListStringActivation()

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
	
	PaintByState = Constants.UseCustomerOrderStates.Get();
	
	If Not PaintByState Then
		InProcessStatus = Constants.CustomerOrdersInProgressStatus.Get();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = Constants.CustomerOrdersCompletedStatus.Get();
		BackColorCompleted = CompletedStatus.Color.Get();
	EndIf;
	
	SelectionOrderStatuses = Catalogs.CustomerOrderStates.Select();
	While SelectionOrderStatuses.Next() Do
		
		If PaintByState Then
			BackColor = SelectionOrderStatuses.Color.Get();
			If TypeOf(BackColor) <> Type("Color") Then
				Continue;
			EndIf;
		Else
			If SelectionOrderStatuses.OrderStatus = PredefinedValue("Enum.OrderStatuses.InProcess") Then
				If TypeOf(BackColorInProcess) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorInProcess;
			ElsIf SelectionOrderStatuses.OrderStatus = PredefinedValue("Enum.OrderStatuses.Completed") Then
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
			If SelectionOrderStatuses.OrderStatus = PredefinedValue("Enum.OrderStatuses.InProcess") Then
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
		FormHeaderText = NStr("en = 'Customer orders: fulfillment is expired'");
		SmallBusinessClientServer.SetListFilterItem(List, "PastPerformance", True);
	EndIf;
	
	If Parameters.Property("OverduePayment") Then
		FormHeaderText = NStr("en = 'Customer orders: Payment is overdue'");
		SmallBusinessClientServer.SetListFilterItem(List, "OverduePayment", True);
	EndIf;
	
	If Parameters.Property("ForToday") Then
		FormHeaderText = NStr("en = 'Customer orders: as of today'");
		SmallBusinessClientServer.SetListFilterItem(List, "ForToday",True);
	EndIf;
	
	If Parameters.Property("AreNew") Then
		UseStatuses = Constants.UseCustomerOrderStates.Get();
		FormHeaderText = "Customer orders: new";
		If UseStatuses Then
			SmallBusinessClientServer.SetListFilterItem(List, "OrderStateState", PredefinedValue("Enum.OrderStatuses.Open"));
		Else
			SmallBusinessClientServer.SetListFilterItem(List, "OrderStatus", "In process");
			SmallBusinessClientServer.SetListFilterItem(List, "Posted", False);
		EndIf;
		SmallBusinessClientServer.SetListFilterItem(List, "Closed", False);
		SmallBusinessClientServer.SetListFilterItem(List, "DeletionMark", False);
	EndIf;
	
	If Parameters.Property("InProcess") Then
		FormHeaderText = NStr("en = 'Customer orders: in progress'");
		SmallBusinessClientServer.SetListFilterItem(List, "OrderInProcess", True);
	EndIf;
	
	If Parameters.Property("Responsible") Then
		If Parameters.Responsible.List.Count() = 1 Then
			SmallBusinessClientServer.SetListFilterItem(List, "Responsible", Parameters.Responsible.List[0].Value);
		Else
			SmallBusinessClientServer.SetListFilterItem(List, "Responsible", Parameters.Responsible.List,,DataCompositionComparisonType.InList);
		EndIf;
		FormHeaderText = FormHeaderText + NStr("en = ', responsible person '") + Parameters.Responsible.Initials;
	EndIf;
	
	If Not IsBlankString(FormHeaderText) Then
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
	
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences);
	
	Items.FilterActuality.ChoiceList.Add("All", "All");
	Items.FilterActuality.ChoiceList.Add("Except closed", "Except closed");
	Items.FilterActuality.ChoiceList.Add("closed", "closed");
	
	Items.FilterStatus.ChoiceList.Add("In process", "In process");
	Items.FilterStatus.ChoiceList.Add("Completed", "Completed");
	Items.FilterStatus.ChoiceList.Add("Canceled", "Canceled");
	
	ValueList = New ValueList;
	ValueList.Add(PredefinedValue("Enum.OperationKindsCustomerOrder.OrderForProcessing"));
	ValueList.Add(PredefinedValue("Enum.OperationKindsCustomerOrder.OrderForSale"));
	
	SmallBusinessClientServer.SetListFilterItem(List,"OperationKind",ValueList,True,DataCompositionComparisonType.InList);
	
	UseStatuses = Constants.UseCustomerOrderStates.Get();
	
	List.Parameters.SetParameterValue("CurrentDateSession", BegOfDay(CurrentSessionDate()));
	
	// Function menu - Marketnig and product sales.
	If Parameters.Property("FunctionsMenuOrderingStage") Then
		
		SmallBusinessClientServer.SetListFilterItem(List,"OperationKind", PredefinedValue("Enum.OperationKindsCustomerOrder.OrderForSale"));
		
		If Parameters.Property("Responsible") Then
			FilterResponsible = Parameters.Responsible;
		EndIf;
		
		If Parameters.FunctionsMenuOrderingStage = "New" Then
			ThisForm.Title = ThisForm.Title + " (AreNew)";
			If UseStatuses Then
				SmallBusinessClientServer.SetListFilterItem(List, "OrderStateState", PredefinedValue("Enum.OrderStatuses.Open"), True, DataCompositionComparisonType.Equal);
				SmallBusinessClientServer.SetListFilterItem(List, "Closed", False);
			Else
				SmallBusinessClientServer.SetListFilterItem(List, "OrderStatus", "In process");
				SmallBusinessClientServer.SetListFilterItem(List, "Posted", False);
			EndIf;
			SmallBusinessClientServer.SetListFilterItem(List, "DeletionMark", False);
			Items.ShipmentPictureNumber.Visible = False;
			Items.PaymentPictureNumber.Visible = False;
		ElsIf Parameters.FunctionsMenuOrderingStage = "NotShipped" Then
			ThisForm.Title = ThisForm.Title + " (for shipment)";
			SmallBusinessClientServer.SetListFilterItem(List, "ForShipment", 0, True, DataCompositionComparisonType.Greater);
			If UseStatuses Then
				SmallBusinessClientServer.SetListFilterItem(List, "Closed", False);
			Else
				SmallBusinessClientServer.SetListFilterItem(List, "OrderStatus", "In process");
			EndIf;
		ElsIf Parameters.FunctionsMenuOrderingStage = "Unpaid" Then
			ThisForm.Title = ThisForm.Title + " (for payment)";
			SmallBusinessClientServer.SetListFilterItem(List, "ForPayment", 0, True, DataCompositionComparisonType.Greater);
			If UseStatuses Then
				SmallBusinessClientServer.SetListFilterItem(List, "Closed", False);
			Else
				SmallBusinessClientServer.SetListFilterItem(List, "OrderStatus", "In process");
			EndIf;
		EndIf;
		
		Items.FilterActuality.Visible = False;
		Items.Closed.Visible = False;
		
		Items.OrderStatus.Visible = False;
		Items.FilterStatus.Visible = False;
		
		If Not UseStatuses Then
			Items.FilterState.Visible = False;
			Items.OrderState.Visible = False;
		EndIf;
		
	// Use customer order status.
	ElsIf UseStatuses Then
		
		Items.OrderStatus.Visible = False;
		Items.FilterStatus.Visible = False;
		
	Else
		
		Items.FilterState.Visible = False;
		Items.FilterActuality.Visible = False;
		Items.OrderState.Visible = False;
		Items.Closed.Visible = False;
		
	EndIf;
	
	PaintList();
	
	SetFilterCurrentWorks();
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.GroupImportantCommandsCustomerOrder);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Parameters.Property("CurrentWorks") Then
		
		Settings.Delete("FilterCompany");
		Settings.Delete("FilterState");
		Settings.Delete("FilterStatus");
		Settings.Delete("FilterCounterparty");
		Settings.Delete("FilterActuality");
		Settings.Delete("FilterResponsible");
		
	Else
		
		FilterCompany = Settings.Get("FilterCompany");
		FilterState = Settings.Get("FilterState");
		FilterStatus = Settings.Get("FilterStatus");
		FilterCounterparty = Settings.Get("FilterCounterparty");
		FilterActuality = Settings.Get("FilterActuality");
		
		If Not ValueIsFilled(FilterActuality) Then
			FilterActuality = "All";
		EndIf;
		
		// Call is excluded from function panel.
		If Not Parameters.Property("Responsible") Then
			FilterResponsible = Settings.Get("FilterResponsible");
		EndIf;
		Settings.Delete("FilterResponsible");
		
		UseStatuses = Constants.UseCustomerOrderStates.Get();
		
		// Log.
		If Not Parameters.Property("FunctionsMenuOrderingStage") Then
			If FilterActuality = "Except closed" Then
				SmallBusinessClientServer.SetListFilterItem(List, "Closed", False);
			ElsIf FilterActuality = "closed" Then
				SmallBusinessClientServer.SetListFilterItem(List, "Closed", True);
			EndIf;
			If UseStatuses Then
				FilterStatus = "";
				SmallBusinessClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
			Else
				SmallBusinessClientServer.SetListFilterItem(List, "OrderStatus", FilterStatus, ValueIsFilled(FilterStatus));
			EndIf;
		EndIf;
		
		SmallBusinessClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
		SmallBusinessClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
		SmallBusinessClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
		
	EndIf;
	
EndProcedure // OnLoadDataFromSettingsAtServer()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_SupplierInvoiceReturn"
	 OR EventName = "Record_CustomerInvoice"
	 OR EventName = "Write_AcceptanceCertificate"
	 OR EventName = "NotificationAboutOrderPayment" 
	 OR EventName = "NotificationAboutChangingDebt" Then
		Items.List.Refresh();
	EndIf;
	
	If EventName = "Record_CustomerOrderStates" Then
		PaintList();
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - handler of clicking the SendEmailToCounterparty button.
//
&AtClient
Procedure SendEmailToCounterparty(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ListCurrentData = Items.List.CurrentData;
	If ListCurrentData = Undefined Then
		Return;
	EndIf;
	
	Recipients = New Array;
	If ValueIsFilled(CounterpartyInformationES) Then
		StructureRecipient = New Structure;
		StructureRecipient.Insert("Presentation", ListCurrentData.Counterparty);
		StructureRecipient.Insert("Address", CounterpartyInformationES);
		Recipients.Add(StructureRecipient);
	EndIf;
	
	SendingParameters = New Structure;
	SendingParameters.Insert("Recipient", Recipients);
	
	EmailOperationsClient.CreateNewEmail(SendingParameters);
	
EndProcedure // SendEmailToCounterparty()

// Procedure - handler of clicking the SendEmailToContactPerson button.
//
&AtClient
Procedure SendEmailToContactPerson(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ListCurrentData = Items.List.CurrentData;
	If ListCurrentData = Undefined Then
		Return;
	EndIf;
	
	Recipients = New Array;
	If ValueIsFilled(ContactPersonESInformation) Then
		StructureRecipient = New Structure;
		StructureRecipient.Insert("Presentation", ListCurrentData.ContactPerson);
		StructureRecipient.Insert("Address", ContactPersonESInformation);
		Recipients.Add(StructureRecipient);
	EndIf;
	
	SendingParameters = New Structure;
	SendingParameters.Insert("Recipient", Recipients);
	
	EmailOperationsClient.CreateNewEmail(SendingParameters);
	
EndProcedure // SendEmailToContactPerson()

&AtClient
// Procedure - command handler CreateCustomerOrder
//
Procedure CreateCustomerOrder(Command)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("FillingValues",
		SmallBusinessClient.ReadValuesOfFilterDynamicList(List));
	
	OpenForm("Document.CustomerOrder.ObjectForm", OpenParameters, Items.List);
	
EndProcedure //CreateCustomerOrder()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ATTRIBUTE EVENT HANDLERS

// Procedure - event handler OnChange input field FilterCompany.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterCompanyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

// Procedure - event handler OnChange input field FilterResponsible.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterResponsibleOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentsListCustomerOrderFilterResponsible");
	// End StandardSubsystems.PerformanceEstimation
	
	SmallBusinessClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

// Procedure - event handler OnChange input field FilterState.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterStateOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
	
EndProcedure

// Procedure - event handler OnChange input field FilterStatus.
//
&AtClient
Procedure FilterStatusOnChange(Item)
	SmallBusinessClientServer.SetListFilterItem(List, "OrderStatus", FilterStatus, ValueIsFilled(FilterStatus));
EndProcedure // FilterStatusOnChange()

// Procedure - event handler OnChange input field FilterCounterparty.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterCounterpartyOnChange(Item)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentsListCustomerOrderFilterCounterparty");
	// End StandardSubsystems.PerformanceEstimation
	
	SmallBusinessClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
EndProcedure

// Procedure - event handler OnChange input field FilterActuality.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterActualityOnChange(Item)
	
	If FilterActuality = "Except closed" Then
		SmallBusinessClientServer.SetListFilterItem(List, "Closed", False, True);
	ElsIf FilterActuality = "closed" Then
		SmallBusinessClientServer.SetListFilterItem(List, "Closed", True, True);
	ElsIf FilterActuality = "All" Then
		SmallBusinessClientServer.SetListFilterItem(List, "Closed", True, False);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - DYNAMIC LIST EVENT HANDLERS

// Procedure - event handler OnActivateRow of dynamic list List.
//
&AtClient
Procedure ListOnActivateRow(Item)
	
	AttachIdleHandler("HandleIncreasedRowsList", 0.2, True);
	
EndProcedure // ListOnActivateRow()

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingCustomerOrder";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningCustomerOrder";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// ServiceTechnology.InformationCenter
&AtClient
Procedure Attachable_ClickOnInformationLink(Item)
	
	InformationCenterClient.ClickOnInformationLink(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ReferenceClickAllInformationLinks(Item)
	
	InformationCenterClient.ReferenceClickAllInformationLinks(ThisForm.FormName);
	
EndProcedure
// End ServiceTechnology.InformationCenter

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion