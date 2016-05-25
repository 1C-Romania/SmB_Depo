
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Processes a row activation event of the document list.
//
&AtClient
Procedure HandleIncreasedRowsList()
	
	InfPanelParameters = New Structure("CIAttribute, Counterparty, ContactPerson", "Counterparty");
	SmallBusinessClient.InfoPanelProcessListRowActivation(ThisForm, InfPanelParameters);
	
	If Items.List.CurrentRow <> Undefined Then
		UpdateListOfPaymentDocuments();
	EndIf;
	
EndProcedure // HandleListStringActivation()

// Function returns the list of the customer invoices related to the current order.
//
&AtServerNoContext
Function GetListOfLinkedDocuments(DocumentCustomerOrder)
	
	ListOfShipmentDocuments = New ValueList;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Dependencies.Ref AS DocRef
	|FROM
	|	FilterCriterion.Dependencies(&DocumentCustomerOrder) AS Dependencies
	|WHERE
	|	(VALUETYPE(Dependencies.Ref) = Type(Document.CashReceipt)
	|			OR VALUETYPE(Dependencies.Ref) = Type(Document.PaymentReceipt))";
	
	Query.SetParameter("DocumentCustomerOrder", DocumentCustomerOrder);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ListOfShipmentDocuments.Add(Selection.DocRef);
	EndDo;
	
	Return ListOfShipmentDocuments;
	
EndFunction // GetLinkedDocumentsList()

// Procedure updates the list of orders.
//
&AtClient
Procedure UpdateOrdersList()
	
	OrdersArray = OrdersList.UnloadValues();
	List.Parameters.SetParameterValue("OrdersList", OrdersArray);
	
EndProcedure // UpdateOrdersList()

// Procedure updates the list of payment documents.
//
&AtClient
Procedure UpdateListOfPaymentDocuments()
	
	DocumentCustomerOrder = Items.List.CurrentRow;
	If DocumentCustomerOrder <> Undefined Then
		ListOfPaymentDocuments = GetListOfLinkedDocuments(DocumentCustomerOrder);
		SmallBusinessClientServer.SetListFilterItem(PaymentDocuments, "Ref", ListOfPaymentDocuments, True, DataCompositionComparisonType.InList);
	EndIf;
	
EndProcedure // UpdatePaymentDocumentsList()

&AtServer
// Function returns the cash assets type of a document.
//
Function GetCashAssetsType(DocumentRef)
	
	StructureCAType = New Structure;
	StructureCAType.Insert("CashAssetsType", DocumentRef.CashAssetsType);
	StructureCAType.Insert("SchedulePayment", DocumentRef.SchedulePayment);
	
	Return StructureCAType;
	
EndFunction // GetCashAssetsType()

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
	
EndProcedure // PaintList()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - Form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Update the list of orders.
	OrdersArray = New Array;
	List.Parameters.SetParameterValue("OrdersList", OrdersArray);
	
	If Parameters.Property("OperationKindJobOrder") Then
		FilterValue = Enums.OperationKindsCustomerOrder.JobOrder;
		ThisForm.AutoTitle = False;
		ThisForm.Title = "Job orders (for payment)";
	Else
		FilterValue = Enums.OperationKindsCustomerOrder.OrderForSale;
	EndIf;
	
	SmallBusinessClientServer.SetListFilterItem(List,"OperationKind",FilterValue);
	
	// Updating the list of payment documents.
	ListOfPaymentDocuments = New ValueList;
	SmallBusinessClientServer.SetListFilterItem(PaymentDocuments, "Ref", ListOfPaymentDocuments, True, DataCompositionComparisonType.InList);
	
	// Call from the functions panel.
	If Parameters.Property("Responsible") Then
		FilterResponsible = Parameters.Responsible;
	EndIf;
	
	List.Parameters.SetParameterValue("CurrentDateSession", BegOfDay(CurrentSessionDate()));
	List.Parameters.SetParameterValue("CurrentDateTimeSession", CurrentSessionDate());
	
	CommonUseClientServer.SetFormItemProperty(Items, "GroupImportantCommandsJobOrder", "Visible", False);
	
	// Email initialization.
	If Users.InfobaseUserWithFullAccess()
	OR (IsInRole("OutputToPrinterClipboardFile")
		AND EmailOperations.CheckSystemAccountAvailable())Then
		SystemEmailAccount = EmailOperations.SystemAccount();
	Else
		Items.CIEMailAddress.Hyperlink = False;
		Items.CIContactPersonEmailAddress.Hyperlink = False;
	EndIf;
	
	// Use customer order status.
	If Not Constants.UseCustomerOrderStates.Get() Then
		Items.FilterState.Visible = False;
		Items.OrderState.Visible = False;
	EndIf;
	
	PaintList();
	
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
	
	FilterCompany = Settings.Get("FilterCompany");
	FilterState = Settings.Get("FilterState");
	FilterCounterparty = Settings.Get("FilterCounterparty");
	
	// Call is excluded from function panel.
	If Not Parameters.Property("Responsible") Then
		FilterResponsible = Settings.Get("FilterResponsible");
	EndIf;
	Settings.Delete("FilterResponsible");
	
	SmallBusinessClientServer.SetListFilterItem(List, "FilterCompany", FilterCompany, ValueIsFilled(FilterCompany));
	SmallBusinessClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	SmallBusinessClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
	SmallBusinessClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
EndProcedure // OnLoadDataFromSettingsAtServer()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_CustomerInvoice"
	 OR EventName = "Write_AcceptanceCertificate"
	 OR EventName = "NotificationAboutOrderPayment" 
	 OR EventName = "NotificationAboutChangingDebt" Then
		UpdateOrdersList();
	EndIf;
	
	If EventName = "NotificationAboutOrderPayment" Then
		UpdateListOfPaymentDocuments();
	EndIf;
	
	If EventName = "Record_CustomerOrderStates" Then
		PaintList();
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - handler of button click CreatePayment.
//
&AtClient
Procedure CreatePayment(Command)
	
	CurrentRow = Items.List.CurrentRow;
	If CurrentRow = Undefined Then
		
		WarningText = NStr("en = 'Command can not be executed for the specified object'");
		ShowMessageBox(Undefined,WarningText);
		Return;
		
	EndIf;
	
	OrdersList.Add(CurrentRow);
	
	StructureCAType = GetCashAssetsType(CurrentRow);
	CashAssetsType = StructureCAType.CashAssetsType;
	SchedulePayment = StructureCAType.SchedulePayment;
	
	BasisParameters = New Structure("Basis, ConsiderBalances", CurrentRow, True);
	If SchedulePayment Then
		If CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
			OpenForm("Document.CashReceipt.ObjectForm", New Structure("Basis", BasisParameters));
		Else
			OpenForm("Document.PaymentReceipt.ObjectForm", New Structure("Basis", BasisParameters));
		EndIf;
	Else
		ListPaymentDocuments = New ValueList();
		ListPaymentDocuments.Add("CashReceipt", "Petty cash receipt");
		ListPaymentDocuments.Add("PaymentReceipt", "Payment receipt");
		SelectedOrder = Undefined;

		ListPaymentDocuments.ShowChooseItem(New NotifyDescription("CreatePaymentEnd", ThisObject, New Structure("BasisParameters", BasisParameters)), "Select payment method");
	EndIf;
	
EndProcedure

&AtClient
Procedure CreatePaymentEnd(Result, AdditionalParameters) Export
    
    BasisParameters = AdditionalParameters.BasisParameters;
    
    
    SelectedOrder = Result;
    If SelectedOrder <> Undefined Then
        If SelectedOrder.Value = "CashReceipt" Then
            OpenForm("Document.CashReceipt.ObjectForm", New Structure("Basis", BasisParameters));
        Else
            OpenForm("Document.PaymentReceipt.ObjectForm", New Structure("Basis", BasisParameters));
        EndIf;
    EndIf;

EndProcedure // CreatePayment()

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

// Procedure - event handler OnChange input field FilterCounterparty.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterCounterpartyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - LIST EVENT HANDLERS

// Procedure - handler of the OnActivateRow list events.
//
&AtClient
Procedure ListOnActivateRow(Item)
	
	AttachIdleHandler("HandleIncreasedRowsList", 0.2, True);
	
EndProcedure // ListOnActivateRow()

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

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
