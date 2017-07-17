
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Processes a row activation event of the document list.
//
&AtClient
Procedure HandleIncreasedRowsList()
	
	InfPanelParameters = New Structure("CIAttribute, Counterparty, ContactPerson", "Counterparty");
	SmallBusinessClient.InfoPanelProcessListRowActivation(ThisForm, InfPanelParameters);
	
	If Items.List.CurrentRow <> Undefined Then
		UpdateListOfShipmentDocuments();
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
	|	VALUETYPE(Dependencies.Ref) = Type(Document.CustomerInvoice)";
	
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

// Procedure updates the list of shipping documents.
//
&AtClient
Procedure UpdateListOfShipmentDocuments()
	
	DocumentCustomerOrder = Items.List.CurrentRow;
	If DocumentCustomerOrder <> Undefined Then
		ListOfShipmentDocuments = GetListOfLinkedDocuments(DocumentCustomerOrder);
		SmallBusinessClientServer.SetListFilterItem(ShipmentDocuments, "Ref", ListOfShipmentDocuments, True, DataCompositionComparisonType.InList);
	EndIf;
	
EndProcedure // UpdateShipmentDocumentsList()

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

&AtServer
// Function checks the difference between key attributes.
//
Function CheckKeyAttributesOfOrders(OrdersArray)
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(DISTINCT CustomerOrderHeader.Company) AS CountCompany,
	|	COUNT(DISTINCT CustomerOrderHeader.Counterparty) AS CountCounterparty,
	|	COUNT(DISTINCT CustomerOrderHeader.Contract) AS CountContract,
	|	COUNT(DISTINCT CustomerOrderHeader.PriceKind) AS CountPriceKind,
	|	COUNT(DISTINCT CustomerOrderHeader.DiscountMarkupKind) AS CountDiscountMarkupKind,
	|	COUNT(DISTINCT CustomerOrderHeader.DocumentCurrency) AS CountDocumentCurrency,
	|	COUNT(DISTINCT CustomerOrderHeader.AmountIncludesVAT) AS CountAmountVATIn,
	|	COUNT(DISTINCT CustomerOrderHeader.IncludeVATInPrice) AS CountIncludeVATInPrice,
	|	COUNT(DISTINCT CustomerOrderHeader.VATTaxation) AS CountVATTaxation
	|FROM
	|	Document.CustomerOrder AS CustomerOrderHeader
	|WHERE
	|	CustomerOrderHeader.Ref IN(&OrdersArray)
	|
	|HAVING
	|	(COUNT(DISTINCT CustomerOrderHeader.Company) > 1
	|		OR COUNT(DISTINCT CustomerOrderHeader.Counterparty) > 1
	|		OR COUNT(DISTINCT CustomerOrderHeader.Contract) > 1
	|		OR COUNT(DISTINCT CustomerOrderHeader.PriceKind) > 1
	|		OR COUNT(DISTINCT CustomerOrderHeader.DiscountMarkupKind) > 1
	|		OR COUNT(DISTINCT CustomerOrderHeader.DocumentCurrency) > 1
	|		OR COUNT(DISTINCT CustomerOrderHeader.AmountIncludesVAT) > 1
	|		OR COUNT(DISTINCT CustomerOrderHeader.IncludeVATInPrice) > 1
	|		OR COUNT(DISTINCT CustomerOrderHeader.VATTaxation) > 1)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Result = Query.Execute();
	If Result.IsEmpty() Then
		DataStructure.Insert("GenerateFewOrders", False);
		DataStructure.Insert("DataPresentation", "");
	Else
		DataStructure.Insert("GenerateFewOrders", True);
		DataPresentation = "";
		Selection = Result.Select();
		While Selection.Next() Do
			
			If Selection.CountCompany > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "Company", ", Company");
			EndIf;
			
			If Selection.CountCounterparty > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "Counterparty", ", Counterparty");
			EndIf;
			
			If Selection.CountContract > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "Contract", ", Contract");
			EndIf;
			
			If Selection.CountPriceKind > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "Price kind", ", Prices kind");
			EndIf;
			
			If Selection.CountDiscountMarkupKind > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "Discount kind", ", Discount kind");
			EndIf;
			
			If Selection.CountDocumentCurrency > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "Currency", ", Currency");
			EndIf;
			
			If Selection.CountAmountVATIn > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "Amount inc. VAT", ", Amount inc. VAT");
			EndIf;
			
			If Selection.CountIncludeVATInPrice > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "VAT inc. in cost", ", VAT inc. in cost");
			EndIf;
			
			If Selection.CountVATTaxation > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "Taxation", ", Taxation");
			EndIf;
			
		EndDo;
		
		DataStructure.Insert("DataPresentation", DataPresentation);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction // CheckOrdersKeyAttributes()

&AtServer
// Function calls document filling data processor on basis.
//
Function GenerateSalesDocumentsAndWrite(OrdersArray)
	
	SalesDodumentsArray = New Array();
	For Each RowFTS IN OrdersArray Do
		
		NewSalesDocument = Documents.CustomerInvoice.CreateDocument();
		
		NewSalesDocument.Date = CurrentDate();
		NewSalesDocument.Fill(RowFTS);
		SmallBusinessServer.FillDocumentHeader(NewSalesDocument,,,, True, );
		
		NewSalesDocument.Write();
		SalesDodumentsArray.Add(NewSalesDocument.Ref);
		
	EndDo;
	
	Return SalesDodumentsArray;
	
EndFunction // FormSaleDocumentsAndWrite()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - Form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Update the list of orders.
	OrdersArray = New Array;
	List.Parameters.SetParameterValue("OrdersList", OrdersArray);
	
	// Updating the list of shipping documents.
	ListOfShipmentDocuments = New ValueList;
	SmallBusinessClientServer.SetListFilterItem(ShipmentDocuments, "Ref", ListOfShipmentDocuments, True, DataCompositionComparisonType.InList);
	
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
	
	PrintObjects = New Array;
	PrintObjects.Add(Metadata.Documents.CustomerInvoice);
	PrintManagement.OnCreateAtServer(ThisForm, Items.PrintCommands, PrintObjects);
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
	
	If EventName = "Record_CustomerInvoice" Then
		UpdateListOfShipmentDocuments();
	EndIf;
	
	If EventName = "Record_CustomerOrderStates" Then
		PaintList();
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - handler of clicking the CreateShipment button.
//
&AtClient
Procedure CreateShipment(Command)
	
	If Items.List.CurrentData = Undefined Then
		
		WarningText = NStr("en='Command cannot be executed for the specified object.';ru='Команда не может быть выполнена для указанного объекта!'");
		ShowMessageBox(Undefined,WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = Items.List.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.CustomerInvoice.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = CheckKeyAttributesOfOrders(OrdersArray);
		If DataStructure.GenerateFewOrders Then
			
			MessageText = NStr("en='The orders have different data (%DataPresentation%) in document headers. Create multiple invoices?';ru='Заказы отличаются данными (%ПредставлениеДанных%) шапки документов! Сформировать несколько расходных накладных?'");
			MessageText = StrReplace(MessageText, "%DataPresentation%", DataStructure.DataPresentation);
			Response = Undefined;

			ShowQueryBox(New NotifyDescription("CreateShipmentEnd", ThisObject, New Structure("OrdersArray", OrdersArray)), MessageText, QuestionDialogMode.YesNo, 0);
            Return;
			
		Else
			
			FillStructure = New Structure();
			FillStructure.Insert("ArrayOfCustomerOrders", OrdersArray);
			OpenForm("Document.CustomerInvoice.ObjectForm", New Structure("Basis", FillStructure));
			
		EndIf;
		
	EndIf;
	
	CreateShipmentFragment(OrdersArray);
EndProcedure

&AtClient
Procedure CreateShipmentEnd(Result, AdditionalParameters) Export
    
    OrdersArray = AdditionalParameters.OrdersArray;
    
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        
        SalesDodumentsArray = GenerateSalesDocumentsAndWrite(OrdersArray);
        Text = NStr("en='Created:';ru='Создание:'");
        For Each RowDocumentSales IN SalesDodumentsArray Do
            
            ShowUserNotification(Text, GetURL(RowDocumentSales), RowDocumentSales, PictureLib.Information32);
            
        EndDo;
        
    EndIf;
    
    
    CreateShipmentFragment(OrdersArray);

EndProcedure

&AtClient
Procedure CreateShipmentFragment(Val OrdersArray)
    
    Var OrderRow;
    
    For Each OrderRow IN OrdersArray Do
        OrdersList.Add(OrderRow);
    EndDo;

EndProcedure // CreateShipment()

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
	
	If CurrentItem = Items.List Then
		
		PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
		
	Else
		
		PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.ImplementationDocumentsList);
		
	EndIf;
	
EndProcedure
// End StandardSubsystems.Printing

#EndRegion