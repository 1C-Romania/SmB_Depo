
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure updates the quantity at the stages of documents.
//
&AtServer
Procedure UpdateOrderStages()
	
	CountOfNewOnes = 0;
	CountOfExported = 0;
	CountOfUnpaid = 0;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SUM(NestedSelect.NewOnesTotal) AS NewOnesTotal,
	|	SUM(NestedSelect.NotShippedTotal) AS NotShippedTotal,
	|	SUM(NestedSelect.UnpaidTotal) AS UnpaidTotal
	|FROM
	|	(SELECT
	|		COUNT(DISTINCT DocumentCustomerOrder.Ref) AS NewOnesTotal,
	|		0 AS NotShippedTotal,
	|		0 AS UnpaidTotal
	|	FROM
	|		Document.CustomerOrder AS DocumentCustomerOrder
	|	WHERE
	|		CASE
	|				WHEN &UseStatuses
	|					THEN DocumentCustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|				ELSE DocumentCustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|						AND Not DocumentCustomerOrder.Posted
	|			END
	|		AND Not DocumentCustomerOrder.Closed
	|		AND Not DocumentCustomerOrder.DeletionMark
	|		AND DocumentCustomerOrder.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.OrderForSale)
	|		AND (&Responsible = VALUE(Catalog.Employees.EmptyRef)
	|				OR DocumentCustomerOrder.Responsible = &Responsible)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		0,
	|		COUNT(DISTINCT CustomerOrdersBalances.CustomerOrder),
	|		0
	|	FROM
	|		AccumulationRegister.CustomerOrders.Balance(
	|				,
	|				CustomerOrder.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.OrderForSale)
	|					AND Not CustomerOrder.Closed
	|					AND (&Responsible = VALUE(Catalog.Employees.EmptyRef)
	|						OR CustomerOrder.Responsible = &Responsible)) AS CustomerOrdersBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		0,
	|		0,
	|		COUNT(DISTINCT InvoicesAndOrdersPaymentTurnovers.InvoiceForPayment)
	|	FROM
	|		AccumulationRegister.InvoicesAndOrdersPayment.Turnovers(
	|				,
	|				,
	|				,
	|				VALUETYPE(InvoiceForPayment) = Type(Document.CustomerOrder)
	|					AND InvoiceForPayment.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.OrderForSale)
	|					AND Not InvoiceForPayment.Closed
	|					AND (&Responsible = VALUE(Catalog.Employees.EmptyRef)
	|						OR InvoiceForPayment.Responsible = &Responsible)) AS InvoicesAndOrdersPaymentTurnovers
	|	WHERE
	|		InvoicesAndOrdersPaymentTurnovers.AmountTurnover - InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover - InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover > 0) AS NestedSelect";
	
	Query.SetParameter("UseStatuses", Constants.UseCustomerOrderStates.Get());
	Query.SetParameter("Responsible", ?(ValueIsFilled(Responsible), Responsible, Catalogs.Employees.EmptyRef()));
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		CountOfNewOnes = Selection.NewOnesTotal;
		CountOfExported = Selection.NotShippedTotal;
		CountOfUnpaid = Selection.UnpaidTotal;
		
	EndIf;
	
	// AreNew
	Items.NewLineCount.Title = CountOfNewOnes;
	If CountOfNewOnes = 0 Then
		Items.PictureNew.Picture = PictureLib.NewOrders0;
	ElsIf CountOfNewOnes < 11 Then
		Items.PictureNew.Picture = PictureLib.NewOrdersFrom1To10;
	ElsIf CountOfNewOnes < 31 Then
		Items.PictureNew.Picture = PictureLib.NewOrdersFrom11To30;
	Else
		Items.PictureNew.Picture = PictureLib.NewOrdersFrom30;
	EndIf;
	
	// For shipment
	Items.NotShippedLineCount.Title = CountOfExported;
	If CountOfExported = 0 Then
		Items.PictureNumbertShipped.Picture = PictureLib.OrdersForShipment0;
	ElsIf CountOfExported < 11 Then
		Items.PictureNumbertShipped.Picture = PictureLib.OrdersForShipmentFrom1To10;
	ElsIf CountOfExported < 31 Then
		Items.PictureNumbertShipped.Picture = PictureLib.OrdersForShipmentFrom11To30;
	Else
		Items.PictureNumbertShipped.Picture = PictureLib.OrdersForShipmentFrom30;
	EndIf;
	
	// For payment
	Items.UnpaidLineCount.Title = CountOfUnpaid;
	If CountOfUnpaid = 0 Then
		Items.PictureUnpaid.Picture = PictureLib.OrdersForPayment0;
	ElsIf CountOfUnpaid < 11 Then
		Items.PictureUnpaid.Picture = PictureLib.OrdersForPaymentFrom1To10;
	ElsIf CountOfUnpaid < 31 Then
		Items.PictureUnpaid.Picture = PictureLib.OrdersForPaymentFrom11To30;
	Else
		Items.PictureUnpaid.Picture = PictureLib.OrdersForPaymentFrom30;
	EndIf;
	
EndProcedure // UpdateOrderStages()

// Procedure sets the filter by responsible.
//
&AtServer
Procedure SetFilterByResponsible()
	
	StringResponsible = ?(ValueIsFilled(Responsible), TrimAll(Responsible.Description), "");
	
	Items.ResponsiblePresentation.Title = NStr("en = 'Responsible person: '") + StringResponsible;
	
	UpdateOrderStages();
	
EndProcedure // SetFilterByResponsible()

// Procedure clears the filter by responsible.
//
&AtServer
Procedure ClearFilterByResponsible()
	
	Items.ResponsiblePresentation.Title = NStr("en = 'Responsible person: <for all>'");
	Responsible = Undefined;
	
	UpdateOrderStages();
	
EndProcedure // ClearFilterByResponsible()

// Determines the possibility of editing products and services prices.
//
&AtServerNoContext
Function AllowedEditPrices()
	
	Return SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	
EndFunction // AllowedEditPrices()

////////////////////////////////////////////////////////////////////////////////
// Form settings

// Procedure saves the form settings.
//
&AtServerNoContext
Procedure SaveFormSettings(FunctionsMenuResponsible)
	
	FormDataSettingsStorage.Save("FunctionsMenuMarketingAndSales", "Responsible", FunctionsMenuResponsible);
	
EndProcedure // SaveFormSettings()

// Procedure imports the form settings.
//
&AtServer
Procedure ImportFormSettings()
	
	Responsible = FormDataSettingsStorage.Load("FunctionsMenuMarketingAndSales", "Responsible");
	If ValueIsFilled(Responsible) Then
		SetFilterByResponsible();
	Else
		ClearFilterByResponsible();
	EndIf;
	
EndProcedure // ImportFormSettings()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer form event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonUse.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then
		
		Return;
		
	EndIf;
	
	ImportFormSettings();
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler of the OnClose form.
//
&AtClient
Procedure OnClose()
	
	FunctionsMenuResponsible = Responsible;
	SaveFormSettings(FunctionsMenuResponsible);
	
EndProcedure // OnClose()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_CustomerInvoice"
	 OR EventName = "Write_AcceptanceCertificate"
	 OR EventName = "NotificationAboutOrderPayment" 
	 OR EventName = "NotificationAboutChangingDebt"
	 OR EventName = "ChangedCustomerOrder" Then
		UpdateOrderStages();
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - COMMAND HANDLERS

// Procedure - event handler Click of the Responsible item.
//
&AtClient
Procedure ResponsiblePresentationClick(Item)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Responsible", Responsible);
	
	Notification = New NotifyDescription("ResponsiblePresentationClickCompletion",ThisForm);
	OpenForm("Catalog.Employees.ChoiceForm", ParametersStructure,,,,,Notification);
	
	
EndProcedure // ResponsiblePresentationClick()

&AtClient
Procedure ResponsiblePresentationClickCompletion(ChoiceValue,Parameters) Export
	
	If TypeOf(ChoiceValue) = Type("CatalogRef.Employees")
		AND ValueIsFilled(ChoiceValue) Then
		
		Responsible = ChoiceValue;
		SetFilterByResponsible();
		
	EndIf;
	
EndProcedure

// Procedure - event handler Click of the Clear item.
//
&AtClient
Procedure ResponsibleClearClick(Item)
	
	If ValueIsFilled(Responsible) Then
		ClearFilterByResponsible();
	EndIf;
	
EndProcedure // ResponsibleClearClick()

&AtClient
Procedure Refresh(Command)
	
	UpdateOrderStages();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// NEW ORDERS

// Procedure - command handler Open the list of new orders.
//
&AtClient
Procedure LabelOpenListOfNewOrdersClick(Item)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("FunctionsMenuOrderingStage", "New");
	OpenParameters.Insert("Responsible", Responsible);
	
	OpenForm("Document.CustomerOrder.ListForm", OpenParameters, , "CustomerOrderDocumentListFormStageNew");
	
EndProcedure // LabelOpenListOfNewOrdersClick

// Opening procedure of the selection form with the possibility to create new "Customer order"
// 
//
&AtClient
Procedure LabelSelectProductsClick(Item)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CreateNewDocument", 		True);
	OpenParameters.Insert("KindOfNewDocument", 		"CustomerOrder");
	OpenParameters.Insert("IsPriceKind", 				True);
	OpenParameters.Insert("IsTaxation", 		True);
	OpenParameters.Insert("ReservationUsed",True);
	OpenParameters.Insert("FillReserve", 			True);
	OpenParameters.Insert("VATTaxation",		PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT"));
	OpenParameters.Insert("AmountIncludesVAT", 			True);
	OpenParameters.Insert("AvailablePriceChanging",		AllowedEditPrices());
	
	ArrayProductsAndServicesTypes = New Array;
	ArrayProductsAndServicesTypes.Add("InventoryItem");
	ArrayProductsAndServicesTypes.Add("Service");
	ArrayProductsAndServicesTypes.Add("Work");
	OpenParameters.Insert("ArrayProductsAndServicesTypes", ArrayProductsAndServicesTypes);
	
	OpenForm("CommonForm.PickForm", OpenParameters);
	
EndProcedure // LabelSelectProductsClick()

////////////////////////////////////////////////////////////////////////////////
// NOT SHIPPED ORDERS

// Procedure - command handler the Ship products.
//
&AtClient
Procedure LabelShipProductsClick(Item)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Responsible", Responsible);
	
	OpenForm("Document.CustomerOrder.Form.ShipmentDocumentsListForm", OpenParameters);
	
EndProcedure // LabelShipProductsClick()

// Procedure - command handler Open the list of not shipped orders.
//
&AtClient
Procedure LabelOpenListOfNotShippedGoodsClick(Item)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("FunctionsMenuOrderingStage", "NotShipped");
	OpenParameters.Insert("Responsible", Responsible);
	
	OpenForm("Document.CustomerOrder.ListForm", OpenParameters, , "CustomerOrderDocumentsListFormStageNotShipped");
	
EndProcedure // LabelOpenListOfNotShippedGoodsClick()

////////////////////////////////////////////////////////////////////////////////
// UNPAID ORDERS

// Procedure - command processor Picture - open list for payment orders.
//
&AtClient
Procedure PictureUnpaidClick(Item)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Responsible", Responsible);
	
	If Items.Find("LabelPayByOrders") = Undefined Then
		OpenParameters.Insert("FunctionsMenuOrderingStage", "Unpaid");
		OpenForm("Document.CustomerOrder.ListForm", OpenParameters, , "CustomerOrderDocumentsListFormStageUnpaid");
	Else
		OpenForm("Document.CustomerOrder.Form.PaymentDocumentsListForm", OpenParameters);
	EndIf;
	
EndProcedure // PictureUnpaidClick()

// Procedure - command processor Picture - open list for payment orders.
//
&AtClient
Procedure PayOrders(Command)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Responsible", Responsible);
	
	OpenForm("Document.CustomerOrder.Form.PaymentDocumentsListForm", OpenParameters);
	
EndProcedure // PayOrders()

// Procedure - command handler Open the list of unpaid orders.
//
&AtClient
Procedure LabelOpenListOfUnpaidOrdersClick(Item)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("FunctionsMenuOrderingStage", "Unpaid");
	OpenParameters.Insert("Responsible", Responsible);
	
	OpenForm("Document.CustomerOrder.ListForm", OpenParameters, , "CustomerOrderDocumentsListFormStageUnpaid");
	
EndProcedure // LabelOpenListOfUnpaidOrdersClick()
// 



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
