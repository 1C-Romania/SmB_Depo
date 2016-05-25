
// Procedure colors list.
//
&AtServer
Procedure PaintList()
	
	// List coloring orders for production.
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem IN ListCustomerOrders.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset"
			OR ConditionalAppearanceItem.Presentation = "Order is closed" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item IN ListOfItemsForDeletion Do
		ListCustomerOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	PaintByState = GetFunctionalOption("UseCustomerOrderStates");
	
	If Not PaintByState Then
		InProcessStatus = SmallBusinessReUse.GetStatusInProcessOfCustomerOrders();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = SmallBusinessReUse.GetStatusCompletedCustomerOrders();
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
		
		ConditionalAppearanceItem = ListCustomerOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
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
		
		ConditionalAppearanceItem = ListCustomerOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
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
		
		ConditionalAppearanceItem = ListCustomerOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
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
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

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
	
	Items.List.Refresh();
	
	Return SalesDodumentsArray;
	
EndFunction // FormSaleDocumentsAndWrite()

&AtServerNoContext
// Procedure saves the form settings.
//
Procedure SaveFormSettings(SettingsStructure)
	
	FormDataSettingsStorage.Save("CustomerInvoiceDocumentsListForm", "SettingsStructure", SettingsStructure);
	
EndProcedure // SaveFormSettings()

&AtServer
// Procedure imports the form settings.
//
Procedure ImportFormSettings()
	
	SettingsStructure = FormDataSettingsStorage.Load("CustomerInvoiceDocumentsListForm", "SettingsStructure");
		
	If TypeOf(SettingsStructure) = Type("Structure") Then
				
		// Period.
		If SettingsStructure.Property("Period") Then
			FilterPeriod = SettingsStructure.Period;
		EndIf;
		
	EndIf;
	
EndProcedure // ImportFormSettings()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - Form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences);
	
	If Parameters.Property("Return", OnlyReturns) Then
		
		ValueList = New ValueList;
		ValueList.Add(Enums.OperationKindsCustomerInvoice.ReturnFromProcessing);
		ValueList.Add(Enums.OperationKindsCustomerInvoice.ReturnToPrincipal);
		ValueList.Add(Enums.OperationKindsCustomerInvoice.ReturnToVendor);
		ValueList.Add(Enums.OperationKindsCustomerInvoice.ReturnFromSafeCustody);
		
		SmallBusinessClientServer.SetListFilterItem(List,"OperationKind",ValueList,,DataCompositionComparisonType.InList);
		
		Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
		Items.ListGroup.ShowTitle = True;
		Items.ListGroup.Representation = UsualGroupRepresentation.WeakSeparation;
		Items.PageCustomerOrders.Visible = False;
		
		ThisForm.AutoTitle = False;
		ThisForm.Title = "Returns to the counterparties";
		
		Items.PageCustomerOrders.Visible = False;
		
	Else
		
		// Use customer order status.
		If GetFunctionalOption("UseCustomerOrderStates") Then
			Items.ListCustomerOrdersOrderStatus.Visible = False;
		Else
			Items.ListCustomerOrdersOrderState.Visible = False;
		EndIf;
		
		PaintList();
		ImportFormSettings();
		
		If Parameters.Property("FunctionsMenuOrderingStage") Then
			
			// Call from the functions panel.
			If Parameters.Property("Responsible") Then
				FilterResponsible = Parameters.Responsible;
			EndIf;
			
			Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
			Items.ListGroup.ShowTitle = True;
			Items.ListGroup.Representation = UsualGroupRepresentation.WeakSeparation;
			Items.PageCustomerOrders.Visible = False;
			
		EndIf;
		
		// Set the format for the current date: DF=H:mm
		SmallBusinessServer.SetDesignDateColumn(ListCustomerOrders);
	
	EndIf;
	
	SmallBusinessServer.SetDesignDateColumn(List);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.GroupImportantCommandsReceipts);
	// End StandardSubsystems.Printing
	
EndProcedure

&AtServer
// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterCompany = Settings.Get("FilterCompany");
	FilterCounterparty = Settings.Get("FilterCounterparty");
	FilterWarehouse = Settings.Get("FilterWarehouse");
	
	// Call is excluded from function panel.
	If Not Parameters.Property("Responsible") Then
		FilterResponsible = Settings.Get("FilterResponsible");
	EndIf;
	Settings.Delete("FilterResponsible");
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	SmallBusinessClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	SmallBusinessClientServer.SetListFilterItem(List, "StructuralUnit", FilterWarehouse, ValueIsFilled(FilterWarehouse));
	SmallBusinessClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
	SmallBusinessClientServer.SetListFilterItem(ListCustomerOrders, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	SmallBusinessClientServer.SetListFilterItem(ListCustomerOrders, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	SmallBusinessClientServer.SetListFilterItem(ListCustomerOrders, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure // OnLoadDataFromSettingsAtServer()

&AtClient
// Procedure - handler of form event OnClose.
//
Procedure OnClose()
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("Period", FilterPeriod);
	SaveFormSettings(SettingsStructure);
	
EndProcedure // OnClose()

&AtClient
// Procedure - event handler of the form NotificationProcessing.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_CustomerInvoice" Then
		Items.ListCustomerOrders.Refresh();
	EndIf;
	
	If EventName = "Record_CustomerOrderStates" Then
		PaintList();
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

&AtClient
// Procedure - handler of the CreateCustomerInvoice button clicking.
//
Procedure CreateCustomerInvoice(Command)
	
	If Items.ListCustomerOrders.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command can not be executed for the specified object'");
		ShowMessageBox(Undefined,WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = Items.ListCustomerOrders.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.CustomerInvoice.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = CheckKeyAttributesOfOrders(OrdersArray);
		If DataStructure.GenerateFewOrders Then
			
			MessageText = NStr("en = 'The orders differ by data (%DataPresentation%) of the documents header! Generate several customer invoices?'");
			MessageText = StrReplace(MessageText, "%DataPresentation%", DataStructure.DataPresentation);
			Response = Undefined;

			ShowQueryBox(New NotifyDescription("CreateCustomerInvoiceEnd", ThisObject, New Structure("OrdersArray", OrdersArray)), MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			FillStructure = New Structure();
			FillStructure.Insert("ArrayOfCustomerOrders", OrdersArray);
			OpenForm("Document.CustomerInvoice.ObjectForm", New Structure("Basis", FillStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateCustomerInvoiceEnd(Result, AdditionalParameters) Export
    
    OrdersArray = AdditionalParameters.OrdersArray;
    
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        
        SalesDodumentsArray = GenerateSalesDocumentsAndWrite(OrdersArray);
        Text = NStr("en='Creating:'");
        For Each RowDocumentSales IN SalesDodumentsArray Do
            
            ShowUserNotification(Text, GetURL(RowDocumentSales), RowDocumentSales, PictureLib.Information32);
            
        EndDo;
        
    EndIf;

EndProcedure // CreateCustomerInvoice()

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
	SmallBusinessClientServer.SetListFilterItem(ListCustomerOrders, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterCounterparty.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterCounterpartyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	SmallBusinessClientServer.SetListFilterItem(ListCustomerOrders, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterWarehouse.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterWarehouseOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "StructuralUnit", FilterWarehouse, ValueIsFilled(FilterWarehouse));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterResponsible.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterResponsibleOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	SmallBusinessClientServer.SetListFilterItem(ListCustomerOrders, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group, Parameter)
	
	KeyOperation = "CreateFormCustomerInvoice";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
	If Not OnlyReturns Then
		Return;
	EndIf;
	
	Cancel = True;
	
	FormParameters = New Structure;
	FormParameters.Insert("OperationKindReturn", OnlyReturns);
	OpenForm("Document.CustomerInvoice.ObjectForm", FormParameters, Item);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningCustomerInvoice";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
	If Item.CurrentRow = Undefined
		OR Not OnlyReturns Then
		Return;
	EndIf;
	
	Cancel = True;
	
	FormParameters = New Structure;
	FormParameters.Insert("OperationKindReturn", OnlyReturns);
	FormParameters.Insert("Key", Item.CurrentRow);
	OpenForm("Document.CustomerInvoice.ObjectForm", FormParameters, Item);
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

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
