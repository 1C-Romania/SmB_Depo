
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
		
		ConditionalAppearanceItem = ListCustomerOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
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
		
		NewSalesDocument = Documents.AcceptanceCertificate.CreateDocument();
		
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
	
	FormDataSettingsStorage.Save("AcceptanceCertificateDocumentsListForm", "SettingsStructure", SettingsStructure);
	
EndProcedure // SaveFormSettings()

&AtServer
// Procedure imports the form settings.
//
Procedure ImportFormSettings()
	
	SettingsStructure = FormDataSettingsStorage.Load("AcceptanceCertificateDocumentsListForm", "SettingsStructure");
		
	If TypeOf(SettingsStructure) = Type("Structure") Then
				
		// Period.
		If SettingsStructure.Property("Period") Then
			FilterPeriod = SettingsStructure.Period;
		EndIf;
		
	EndIf;
	
EndProcedure // ImportFormSettings()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - Form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Use customer order status.
	If Constants.UseCustomerOrderStates.Get() Then
		Items.ListCustomerOrdersOrderStatus.Visible = False;
	Else
		Items.ListCustomerOrdersOrderState.Visible = False;
	EndIf;
	
	PaintList();
	ImportFormSettings();
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	SmallBusinessServer.SetDesignDateColumn(ListCustomerOrders);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterCompany 		= Settings.Get("FilterCompany");
	FilterCounterparty 		= Settings.Get("FilterCounterparty");
	FilterDepartment 		= Settings.Get("FilterDepartment");
	FilterResponsible 		= Settings.Get("FilterResponsible");
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	SmallBusinessClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	SmallBusinessClientServer.SetListFilterItem(List, "Department", FilterDepartment, ValueIsFilled(FilterDepartment));
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
	
	If EventName = "Write_AcceptanceCertificate" Then
		Items.ListCustomerOrders.Refresh();
	EndIf;
	
	If EventName = "Record_CustomerOrderStates" Then
		PaintList();
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

&AtClient
// Procedure - handler of clicking the CreateAcceptanceCertificate button.
//
Procedure CreateAcceptanceCertificate(Command)
	
	If Items.ListCustomerOrders.CurrentData = Undefined Then
		
		WarningText = NStr("en='Command cannot be executed for the specified object.';ru='Команда не может быть выполнена для указанного объекта!'");
		ShowMessageBox(Undefined,WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = Items.ListCustomerOrders.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.AcceptanceCertificate.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = CheckKeyAttributesOfOrders(OrdersArray);
		If DataStructure.GenerateFewOrders Then
			
			MessageText = NStr("en='The orders have different data (%DataPresentation%) in document headers. Create multiple acceptance certificates?';ru='Заказы отличаются данными (%ПредставлениеДанных%) шапки документов! Сформировать несколько актов выполненных работ?'");
			MessageText = StrReplace(MessageText, "%DataPresentation%", DataStructure.DataPresentation);
			Response = Undefined;

			ShowQueryBox(New NotifyDescription("CreateAcceptanceCertificateEnd", ThisObject, New Structure("OrdersArray", OrdersArray)), MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			FillStructure = New Structure();
			FillStructure.Insert("ArrayOfCustomerOrders", OrdersArray);
			OpenForm("Document.AcceptanceCertificate.ObjectForm", New Structure("Basis", FillStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateAcceptanceCertificateEnd(Result, AdditionalParameters) Export
    
    OrdersArray = AdditionalParameters.OrdersArray;
    
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        
        SalesDodumentsArray = GenerateSalesDocumentsAndWrite(OrdersArray);
        Text = NStr("en='Created:';ru='Создание:'");
        For Each RowDocumentSales IN SalesDodumentsArray Do
            
            ShowUserNotification(Text, GetURL(RowDocumentSales), RowDocumentSales, PictureLib.Information32);
            
        EndDo;
        
    EndIf;

EndProcedure // CreateAcceptanceCertificate()

///////////////////////////////////////////////////////////////////////////////
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
// Procedure - event handler OnChange input field FilterDepartment.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterDepartmentOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Department", FilterDepartment, ValueIsFilled(FilterDepartment));
	
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

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "CreatingAcceptanceCertificateForm";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "OpeningAcceptanceCertificateForm";
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