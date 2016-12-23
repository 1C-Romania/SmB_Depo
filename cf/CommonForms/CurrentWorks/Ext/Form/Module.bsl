
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Generates measures.
//
&AtServer
Procedure GenerateMetrics()
	
	IndicatorsGroupsArray = GetArrayOfGroupsOfIndicators();
	
	FinalQueryText = "";
	For Each IndicatorsGroup in IndicatorsGroupsArray Do
		QueryText = GetTextOfQueryToCalculateIndicators(IndicatorsGroup);
		If QueryText <> "" Then
			FinalQueryText = FinalQueryText + QueryText + ";";
		EndIf;
	EndDo;
	
	If FinalQueryText = "" Then
		Return;
	EndIf;
	
	Query = New Query();
	Query.Text = FinalQueryText;
	
	Query.SetParameter("User", User);
	Query.SetParameter("EmployeesList", EmployeesList);
	Query.SetParameter("CurrentDateTimeSession", CurrentSessionDate());
	Query.SetParameter("CurrentTimeOfSession", Date(1,1,1,Hour(CurrentSessionDate()), Minute(CurrentSessionDate()), Second(CurrentSessionDate())));
	Query.SetParameter("EndOfDayIfCurrentDateTimeSession", EndOfDay(CurrentSessionDate()));
	Query.SetParameter("StartOfDayIfCurrentDateTimeSession", BegOfDay(CurrentSessionDate()));
	Query.SetParameter("EndOfLastSessionOfMonth", BegOfMonth(CurrentSessionDate()) - 1);
	
	QueryResultArray = Query.ExecuteBatch();
	
	SetDisplayOfElements(True);
	
	IndexOf = 0;
	NullData.Clear();
	For Each QueryResultRow IN QueryResultArray Do
		
		QueryResult = QueryResultArray[IndexOf];
		
		Selection = QueryResult.Select();
		If Selection.Next() Then
			For Each IndicatorName IN QueryResult.Columns Do
				
				ThisForm[IndicatorName.Name] = Items[IndicatorName.Name].Title + " ("+ Selection[IndicatorName.Name] + ")";
				
				If Selection[IndicatorName.Name] = 0 Then
					NullData.Add(IndicatorName.Name);
				EndIf;
				
			EndDo;
		EndIf;
		
		IndexOf = IndexOf + 1;
		
	EndDo;
	
	SetDisplayOfElements();
	
EndProcedure // GenerateMeasures()

// Procedure sets items display.
//
&AtServer
Procedure SetDisplayOfElements(ItemsVisible = False)
	
	For Each IndicatorName IN NullData Do
		If ItemsVisible Then
			Items[IndicatorName.Value].Visible = ItemsVisible;
		Else
			Items[IndicatorName.Value].Visible = Not NotRepresentNullData;
		EndIf;
	EndDo;
	
EndProcedure // SetItemsDisplay()

// Generates list of user employees.
//
&AtServer
Function GetListOfUsersStaff()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	UserEmployees.Employee AS Employee,
	|	UserEmployees.Employee.Description AS Description,
	|	IndividualsDescriptionFullSliceLast.Surname AS Surname,
	|	IndividualsDescriptionFullSliceLast.Name AS Name,
	|	IndividualsDescriptionFullSliceLast.Patronymic AS Patronymic
	|FROM
	|	InformationRegister.UserEmployees AS UserEmployees
	|		LEFT JOIN InformationRegister.IndividualsDescriptionFull.SliceLast(&ToDate, ) AS IndividualsDescriptionFullSliceLast
	|		ON UserEmployees.Employee.Ind = IndividualsDescriptionFullSliceLast.Ind
	|WHERE
	|	UserEmployees.User = &User";
	
	Query.SetParameter("User", User);
	Query.SetParameter("ToDate", CurrentSessionDate());
	
	EmployeesPresentation = "";
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		EmployeesList.Add(Selection.Employee);
		PresentationResponsible = SmallBusinessServer.GetSurnameNamePatronymic(Selection.Surname, Selection.Name, Selection.Patronymic);
		EmployeesPresentation = EmployeesPresentation + ?(EmployeesPresentation = "", "", ", ") + ?(ValueIsFilled(PresentationResponsible), PresentationResponsible, Selection.Description);
	EndDo;
	
EndFunction // GetUserEmployeesList()

// Generates measures list according to FO and rights.
//
&AtServer
Function GetArrayOfGroupsOfIndicators()
	
	IndicatorsGroupsArray = New Array;
	
	// Events
	GroupName = "Events";
	Items[GroupName].Visible = AccessRight("Edit", Metadata.Documents.Event);
	If Items[GroupName].Visible Then
		IndicatorsGroupsArray.Add(GroupName);
	EndIf;
	
	// Work orders
	GroupName = "WorkOrders";
	Items[GroupName].Visible = AccessRight("Edit", Metadata.Documents.WorkOrder);
	If Items[GroupName].Visible Then
		IndicatorsGroupsArray.Add(GroupName);
	EndIf;
	
	// Customer orders
	GroupName = "CustomerOrders";
	Items[GroupName].Visible = AccessRight("Edit", Metadata.Documents.CustomerOrder)
									AND AccessRight("Posting", Metadata.Documents.CustomerOrder);
	If Items[GroupName].Visible Then
		IndicatorsGroupsArray.Add(GroupName);
	EndIf;
	
	// Job orders
	GroupName = "JobOrders";
	Items[GroupName].Visible = GetFunctionalOption("UseWorkSubsystem")
									AND AccessRight("Edit", Metadata.Documents.CustomerOrder)
									AND AccessRight("Posting", Metadata.Documents.CustomerOrder);
	If Items[GroupName].Visible Then
		IndicatorsGroupsArray.Add(GroupName);
	EndIf;
	
	// Purchase orders
	GroupName = "PurchaseOrders";
	Items[GroupName].Visible = AccessRight("Edit", Metadata.Documents.PurchaseOrder);
	If Items[GroupName].Visible Then
		IndicatorsGroupsArray.Add(GroupName);
	EndIf;
	
	// Production orders
	GroupName = "ProductionOrders";
	Items[GroupName].Visible = GetFunctionalOption("UseSubsystemProduction")
									AND AccessRight("Edit", Metadata.Documents.ProductionOrder);
	If Items[GroupName].Visible Then
		IndicatorsGroupsArray.Add(GroupName);
	EndIf;
	
	// Month closing
	GroupName = "MonthEnd";
	Items[GroupName].Visible = AccessRight("Edit", Metadata.Documents.MonthEnd);
	If Items[GroupName].Visible Then
		IndicatorsGroupsArray.Add(GroupName);
	EndIf;
	
	// My reminders
	GroupName = "MyReminders";
	Items[GroupName].Visible = GetFunctionalOption("UseUserReminders")
									AND AccessRight("Edit", Metadata.InformationRegisters.UserReminders);
	If Items[GroupName].Visible Then
		IndicatorsGroupsArray.Add(GroupName);
	EndIf;
	
	Return IndicatorsGroupsArray;
	
EndFunction // GetMeasuresGroupsArray()

// Receives query text for measures calculation.
//
&AtServer
Function GetTextOfQueryToCalculateIndicators(IndicatorsGroup)
	
	If IndicatorsGroup = "Events" Then
		
		Return GetTextOfQueryToIndexEvent();
		
	ElsIf IndicatorsGroup = "WorkOrders" Then
		
		Return GetTextOfRequestForIndexWorkOrders();
		
	ElsIf IndicatorsGroup = "CustomerOrders" Then
		
		Return GetQueryTextForTargetCustomerOrders();
		
	ElsIf IndicatorsGroup = "JobOrders" Then
		
		Return GetQueryTextForIndicatorJobOrders();
		
	ElsIf IndicatorsGroup = "PurchaseOrders" Then
		
		Return GetQueryTextForFigureOrdersToSuppliers();
		
	ElsIf IndicatorsGroup = "ProductionOrders" Then
		
		Return GetTextOfQueryForRecordOrdersForProduction();
		
	ElsIf IndicatorsGroup = "MonthEnd" Then
		
		Return GetTextOfQueryForRecordMonthEnd();
		
	ElsIf IndicatorsGroup = "MyReminders" Then
		
		Return GetTextOfRequestForMyReminders();
		
	EndIf;
	
	Return "";
	
EndFunction // ReceiveQueryTextForMeasuresCalculation()

// Receives query text for the Events group measures.:
// Overdue, For today, Planned.
//
&AtServer
Function GetTextOfQueryToIndexEvent()
	
	QueryText =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN Events.EventEnding < &CurrentDateTimeSession
	|					AND Events.EventBegin <> DATETIME(1, 1, 1)
	|				THEN Events.Ref
	|		END) AS EventsExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN Events.EventBegin <= &EndOfDayIfCurrentDateTimeSession
	|					AND Events.EventEnding >= &CurrentDateTimeSession
	|				THEN Events.Ref
	|		END) AS EventsForToday,
	|	COUNT(DISTINCT Events.Ref) AS PlannedEvents
	|FROM
	|	Document.Event AS Events
	|WHERE
	|	Events.State <> VALUE(Catalog.EventStates.Completed)
	|	AND Events.State <> VALUE(Catalog.EventStates.Canceled)
	|	AND Events.Responsible IN(&EmployeesList)
	|	AND Not Events.DeletionMark"
	;
	
	Return QueryText;
	
EndFunction // ReceiveQueryTextForMeasureEvent()

// Receives query text for the WorkOrders group measures.:
// Overdue, For today, Planned, Controled.
//
&AtServer
Function GetTextOfRequestForIndexWorkOrders()
	
	QueryText =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN (WorkOrders.Day < &StartOfDayIfCurrentDateTimeSession
	|					OR WorkOrders.Day = &StartOfDayIfCurrentDateTimeSession
	|						AND WorkOrders.EndTime < &CurrentTimeOfSession)
	|					AND WorkOrders.EndTime <> DATETIME(1, 1, 1)
	|					AND WorkOrders.Day <> DATETIME(1, 1, 1)
	|					AND WorkOrders.Ref.Employee IN (&EmployeesList)
	|				THEN WorkOrders.Ref
	|		END) AS WorkOrdersExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN WorkOrders.Day = &StartOfDayIfCurrentDateTimeSession
	|					AND WorkOrders.BeginTime <= &CurrentTimeOfSession
	|					AND WorkOrders.EndTime >= &CurrentTimeOfSession
	|					AND WorkOrders.Ref.Employee IN (&EmployeesList)
	|				THEN WorkOrders.Ref
	|		END) AS WorkOrdersOnToday,
	|	COUNT(DISTINCT CASE
	|			WHEN WorkOrders.Ref.Employee IN (&EmployeesList)
	|				THEN WorkOrders.Ref
	|		END) AS WorkOrdersPlanned,
	|	COUNT(DISTINCT CASE
	|			WHEN WorkOrders.Ref.Author = &User
	|					AND Not WorkOrders.Ref.Employee IN (&EmployeesList)
	|				THEN WorkOrders.Ref
	|		END) AS WorkOrdersOnControl
	|FROM
	|	Document.WorkOrder.Works AS WorkOrders
	|WHERE
	|	WorkOrders.Ref.Posted
	|	AND WorkOrders.Ref.State <> VALUE(Catalog.EventStates.Completed)
	|	AND WorkOrders.Ref.State <> VALUE(Catalog.EventStates.Canceled)"
	;
	
	Return QueryText;
	
EndFunction // ReceiveQueryTextForMeasureWorkOrders()

// Receives query text for the CustomerOrders group measures.:
// Overdue shipments, Overdue payment, For today, New orders, Orders in process.
//
&AtServer
Function GetQueryTextForTargetCustomerOrders()
	
	QueryText =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN DocCustomerOrder.Posted
	|					AND DocCustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not RunSchedule.Order IS NULL 
	|					AND RunSchedule.Period < &StartOfDayIfCurrentDateTimeSession
	|				THEN DocCustomerOrder.Ref
	|		END) AS BuyersOrdersExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocCustomerOrder.Posted
	|					AND DocCustomerOrder.SchedulePayment
	|					AND DocCustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not PaymentSchedule.InvoiceForPayment IS NULL 
	|					AND PaymentSchedule.Period < &StartOfDayIfCurrentDateTimeSession
	|				THEN DocCustomerOrder.Ref
	|		END) AS BuyersOrdersPaymentExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocCustomerOrder.Posted
	|					AND DocCustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not RunSchedule.Order IS NULL 
	|					AND RunSchedule.Period = &StartOfDayIfCurrentDateTimeSession
	|				THEN DocCustomerOrder.Ref
	|			WHEN DocCustomerOrder.Posted
	|					AND DocCustomerOrder.SchedulePayment
	|					AND DocCustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not PaymentSchedule.InvoiceForPayment IS NULL 
	|					AND PaymentSchedule.Period = &StartOfDayIfCurrentDateTimeSession
	|				THEN DocCustomerOrder.Ref
	|		END) AS CustomersOrdersForToday,
	|	COUNT(DISTINCT CASE
	|			WHEN UseCustomerOrderStates.Value
	|				THEN CASE
	|						WHEN DocCustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|							THEN DocCustomerOrder.Ref
	|					END
	|			ELSE CASE
	|					WHEN Not DocCustomerOrder.Posted
	|							AND DocCustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|						THEN DocCustomerOrder.Ref
	|				END
	|		END) AS BuyersNewOrders,
	|	COUNT(DISTINCT CASE
	|			WHEN DocCustomerOrder.Posted
	|					AND DocCustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				THEN DocCustomerOrder.Ref
	|		END) AS BuyersOrdersInWork
	|FROM
	|	Document.CustomerOrder AS DocCustomerOrder
	|		LEFT JOIN InformationRegister.OrderFulfillmentSchedule AS RunSchedule
	|		ON DocCustomerOrder.Ref = RunSchedule.Order
	|			AND (RunSchedule.Period <= &StartOfDayIfCurrentDateTimeSession)
	|		{LEFT JOIN InformationRegister.OrdersPaymentSchedule AS PaymentSchedule
	|		ON DocCustomerOrder.Ref = PaymentSchedule.InvoiceForPayment
	|			AND (PaymentSchedule.Period <= &StartOfDayIfCurrentDateTimeSession)},
	|	Constant.UseCustomerOrderStates AS UseCustomerOrderStates
	|WHERE
	|	DocCustomerOrder.OperationKind <> VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|	AND Not DocCustomerOrder.Closed
	|	AND DocCustomerOrder.Responsible IN(&EmployeesList)
	|	AND Not DocCustomerOrder.DeletionMark"
	;
	
	Return QueryText;
	
EndFunction // ReceiveQueryTextForMeasureCustomerOrders()

// Receives query text for the WorkOrders group measures.:
// Overdue shipments, Overdue payment, For today, Orders in process.
//
&AtServer
Function GetQueryTextForIndicatorJobOrders()
	
	QueryText =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN DocJobOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND DocJobOrder.Finish < &CurrentDateTimeSession
	|				THEN DocJobOrder.Ref
	|		END) AS JobOrdersExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocJobOrder.SchedulePayment
	|					AND DocJobOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not PaymentSchedule.InvoiceForPayment IS NULL 
	|					AND PaymentSchedule.Period < &StartOfDayIfCurrentDateTimeSession
	|				THEN DocJobOrder.Ref
	|		END) AS JobOrdersExpiredPayment,
	|	COUNT(DISTINCT CASE
	|			WHEN DocJobOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND DocJobOrder.Start <= &EndOfDayIfCurrentDateTimeSession
	|					AND DocJobOrder.Finish >= &CurrentDateTimeSession
	|				THEN DocJobOrder.Ref
	|			WHEN DocJobOrder.SchedulePayment
	|					AND DocJobOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not PaymentSchedule.InvoiceForPayment IS NULL 
	|					AND PaymentSchedule.Period = &StartOfDayIfCurrentDateTimeSession
	|				THEN DocJobOrder.Ref
	|		END) AS JobOrdersForToday,
	|	COUNT(DISTINCT CASE
	|			WHEN DocJobOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				THEN DocJobOrder.Ref
	|		END) AS JobOrdersInWork
	|FROM
	|	Document.CustomerOrder AS DocJobOrder
	|		{LEFT JOIN InformationRegister.OrdersPaymentSchedule AS PaymentSchedule
	|		ON DocJobOrder.Ref = PaymentSchedule.InvoiceForPayment
	|			AND (PaymentSchedule.Period <= &StartOfDayIfCurrentDateTimeSession)}
	|WHERE
	|	DocJobOrder.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder)
	|	AND DocJobOrder.Posted
	|	AND Not DocJobOrder.Closed
	|	AND DocJobOrder.Responsible IN(&EmployeesList)"
	;
	
	Return QueryText;
	
EndFunction // ReceiveQueryTextForMeasureJobOrders()

// Receives query text for the group PurchaseOrders measures.:
// Overdue receipts, Overdue payment, For today, Orders in process.
//
&AtServer
Function GetQueryTextForFigureOrdersToSuppliers()
	
	QueryText =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not RunSchedule.Order IS NULL 
	|					AND RunSchedule.Period < &StartOfDayIfCurrentDateTimeSession
	|				THEN DocPurchaseOrder.Ref
	|		END) AS SupplierOrdersExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocPurchaseOrder.SchedulePayment
	|					AND DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not PaymentSchedule.InvoiceForPayment IS NULL 
	|					AND PaymentSchedule.Period < &StartOfDayIfCurrentDateTimeSession
	|				THEN DocPurchaseOrder.Ref
	|		END) AS SupplierOrdersPaymentExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not RunSchedule.Order IS NULL 
	|					AND RunSchedule.Period = &StartOfDayIfCurrentDateTimeSession
	|				THEN DocPurchaseOrder.Ref
	|			WHEN DocPurchaseOrder.SchedulePayment
	|					AND DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not PaymentSchedule.InvoiceForPayment IS NULL 
	|					AND PaymentSchedule.Period = &StartOfDayIfCurrentDateTimeSession
	|				THEN DocPurchaseOrder.Ref
	|		END) AS SupplierOrdersForToday,
	|	COUNT(DISTINCT CASE
	|			WHEN DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				THEN DocPurchaseOrder.Ref
	|		END) AS SupplierOrdersInWork
	|FROM
	|	Document.PurchaseOrder AS DocPurchaseOrder
	|		LEFT JOIN InformationRegister.OrderFulfillmentSchedule AS RunSchedule
	|		ON DocPurchaseOrder.Ref = RunSchedule.Order
	|			AND (RunSchedule.Period <= &StartOfDayIfCurrentDateTimeSession)
	|		{LEFT JOIN InformationRegister.OrdersPaymentSchedule AS PaymentSchedule
	|		ON DocPurchaseOrder.Ref = PaymentSchedule.InvoiceForPayment
	|			AND (PaymentSchedule.Period <= &StartOfDayIfCurrentDateTimeSession)}
	|WHERE
	|	DocPurchaseOrder.Posted
	|	AND Not DocPurchaseOrder.Closed
	|	AND DocPurchaseOrder.Responsible IN(&EmployeesList)"
	;
	
	Return QueryText;
	
EndFunction // ReceiveQueryTextForMeasureVendorOrders()

// Receives query text for the OrdersForProduction group measures.:
// Overdue execution, For today, Orders in process.
//
&AtServer
Function GetTextOfQueryForRecordOrdersForProduction()
	
	QueryText =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN DocProductionOrder.Finish < &CurrentDateTimeSession
	|					AND ISNULL(ProductionOrdersBalances.QuantityBalance, 0) > 0
	|				THEN DocProductionOrder.Ref
	|		END) AS OrdersForProductionExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocProductionOrder.Start <= &EndOfDayIfCurrentDateTimeSession
	|					AND DocProductionOrder.Finish >= &CurrentDateTimeSession
	|					AND ISNULL(ProductionOrdersBalances.QuantityBalance, 0) > 0
	|				THEN DocProductionOrder.Ref
	|		END) AS OrdersForProductionForToday,
	|	COUNT(DISTINCT DocProductionOrder.Ref) AS OrdersForProductionInWork
	|FROM
	|	Document.ProductionOrder AS DocProductionOrder
	|		{LEFT JOIN AccumulationRegister.ProductionOrders.Balance(, ) AS ProductionOrdersBalances
	|		ON DocProductionOrder.Ref = ProductionOrdersBalances.ProductionOrder}
	|WHERE
	|	DocProductionOrder.Posted
	|	AND Not DocProductionOrder.Closed
	|	AND DocProductionOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|	AND DocProductionOrder.Responsible IN(&EmployeesList)"
	;
	
	Return QueryText;
	
EndFunction // ReceiveQueryTextForMeasureProductionOrders()

// Receives query text for the OrdersForProduction group measures.:
// Overdue execution, For today, Orders in process.
//
&AtServer
Function GetTextOfQueryForRecordMonthEnd()
	
	QueryText =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN VALUETYPE(DocMonthEnd.Ref) <> Type(Document.MonthEnd)
	|				THEN InventoryBalances.Company
	|		END) AS MonthClosureNotCalculatedTotals
	|FROM
	|	AccumulationRegister.Inventory.Balance(&EndOfLastSessionOfMonth, ) AS InventoryBalances
	|		LEFT JOIN Document.MonthEnd AS DocMonthEnd
	|		ON InventoryBalances.Company = DocMonthEnd.Company
	|			AND (DocMonthEnd.Posted)
	|			AND (BEGINOFPERIOD(&EndOfLastSessionOfMonth, MONTH) = BEGINOFPERIOD(DocMonthEnd.Date, MONTH))"
	;
	
	Return QueryText;
	
EndFunction // ReceiveQueryTextForMeasureMonthClosing()

// Receives query text for the MyNotifications group measures.:
//
&AtServer
Function GetTextOfRequestForMyReminders()
	
	QueryText =
	"SELECT ALLOWED
	|	COUNT(*) AS MyRemindersTotalReminders
	|FROM
	|	InformationRegister.UserReminders AS InformationRegisterUserReminders
	|WHERE
	|	InformationRegisterUserReminders.User = &User"
	;
	
	Return QueryText;
	
EndFunction // ReceiveQueryTextForMeasureMyNotifications()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer form event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonUse.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then
		
		Return;
		
	EndIf;
	
	NotRepresentNullData = Items.FormSetNullDataRepresentation.Check;
	
	User = Users.AuthorizedUser();
	GetListOfUsersStaff();
	
	GenerateMetrics();
	
EndProcedure // OnCreateAtServer()

// Procedure - OnLoadDataFromSettingsAtServer form event handler.
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ZerosRepresentationSetting = Settings.Get("NotRepresentNullData");
	If ZerosRepresentationSetting <> Undefined Then
		NotRepresentNullData = ZerosRepresentationSetting;
	EndIf;
	
	Items.FormSetNullDataRepresentation.Check = NotRepresentNullData;
	SetDisplayOfElements();
	
EndProcedure // OnLoadDataFromSettingsAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - COMMAND HANDLERS

// Procedure - Update command handler of the To-do lists panel.
//
&AtClient
Procedure Refresh(Command)
	
	GenerateMetrics();
	
EndProcedure // Refresh()

// Procedure - SetZeroMeasureDisplay handler command of the To-do lists panel.
//
&AtClient
Procedure SetNullDataRepresentation(Command)
	
	NotRepresentNullData = Not NotRepresentNullData;
	Items.FormSetNullDataRepresentation.Check = NotRepresentNullData;
	SetDisplayOfElements();
	
EndProcedure // SetZeroMeasuresDisplay()

////////////////////////////////////////////////////////////////////////////////
// EVENTS

// Procedure - Overdue command handler of the Events list.
//
&AtClient
Procedure EventsExpiredExecutionPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.Event.ListForm", OpenParameters);
	
EndProcedure // EventsOverdueExecutionClick()

// Procedure - ForToday command handler of the Events list.
//
&AtClient
Procedure EventsForTodayPressing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.Event.ListForm", OpenParameters);
	
EndProcedure // EventsForTodayClick()

// Procedure - Planned command handler of the Events list.
//
&AtClient
Procedure ScheduledPressEvent(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("Planned");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.Event.ListForm", OpenParameters);
	
EndProcedure // EventsPlannedClick()

////////////////////////////////////////////////////////////////////////////////
// WORK ORDERS

// Procedure - Overdue command handler of the WorkOrders list.
//
&AtClient
Procedure WorkOrdersExpiredPressing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.WorkOrder.ListForm", OpenParameters);
	
EndProcedure // WorkOrdersOverdueExecutionClick()

// Procedure - ForToday command handler of the WorkOrders list.
//
&AtClient
Procedure WorkOrdersOnTodaysPressing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.WorkOrder.ListForm", OpenParameters);
	
EndProcedure // WorkOrdersForTodayClick()

// Procedure - Planned command handler of the WorkOrders list.
//
&AtClient
Procedure WorkOrdersScheduledPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("Planned");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.WorkOrder.ListForm", OpenParameters);
	
EndProcedure // WorkOrdersPlannedClick()

// Procedure - Controled command handler of the WorkOrders list.
//
&AtClient
Procedure WorkOrdersControlClicking(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("OnControl");
	OpenParameters.Insert("Performer", EmployeesList);
	OpenParameters.Insert("Author", New Structure("User, Initials", User, EmployeesPresentation));
	
	OpenForm("Document.WorkOrder.ListForm", OpenParameters);
	
EndProcedure // WorkOrdersControledClick()

////////////////////////////////////////////////////////////////////////////////
// CUSTOMER ORDERS

// Procedure - ShipmentOverdue command handler of the CustomerOrders list.
//
&AtClient
Procedure CustomerOrdersAreOutstandingRunningPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("CustomerOrder");
	
	OpenForm("Document.CustomerOrder.ListForm", OpenParameters);
	
EndProcedure // CustomerOrdersOverdueExecutionClick()

// Procedure - PaymentOverdue command handler of the CustomerOrders list.
//
&AtClient
Procedure CustomerOrdersExpiredPaymentButton(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("OverduePayment");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("CustomerOrder");
	
	OpenForm("Document.CustomerOrder.ListForm", OpenParameters);
	
EndProcedure // CustomerOrdersOverduePaymentClick()

// Procedure - ForToday command handler of the CustomerOrders list.
//
&AtClient
Procedure CustomerOrdersOnTodayClicking(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("CustomerOrder");
	
	OpenForm("Document.CustomerOrder.ListForm", OpenParameters);
	
EndProcedure // CustomerOrdersForTodayClick()

// Procedure - InProcess command handler of the CustomerOrders list.
//
&AtClient
Procedure CustomerOrdersInPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("InProcess");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("CustomerOrder");
	
	OpenForm("Document.CustomerOrder.ListForm", OpenParameters);
	
EndProcedure // CustomerOrdersInProcessClick()

// Procedure - New command handler of the CustomerOrders list.
//
&AtClient
Procedure ClickingNewCustomerOrders(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("AreNew");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("CustomerOrder");
	
	OpenForm("Document.CustomerOrder.ListForm", OpenParameters);
	
EndProcedure // CustomerOrdersNewClick()

////////////////////////////////////////////////////////////////////////////////
// Job orders

// Procedure - ExecutionOverdue command handler of the WorkOrders list.
//
&AtClient
Procedure WorkJobOrdersPastPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("JobOrder");
	
	OpenForm("Document.CustomerOrder.ListForm", OpenParameters);
	
EndProcedure // WorkOrdersOverdueExecutionClick()

// Procedure - PaymentOverdue command handler of the WorkOrders list.
//
&AtClient
Procedure JobOrdersPaymentOverdueClicking(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("OverduePayment");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("JobOrder");
	
	OpenForm("Document.CustomerOrder.ListForm", OpenParameters);
	
EndProcedure // JobOrdersOverduePaymentClick()

// Procedure - ForToday command handler of the WorkOrders list.
//
&AtClient
Procedure JobOrdersOnTodayPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("JobOrder");
	
	OpenForm("Document.CustomerOrder.ListForm", OpenParameters);
	
EndProcedure // WorkOrdersForTodayClick()

// Procedure - InProcess command handler of the JobOrders list.
//
&AtClient
Procedure JobOrdersInWorkPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("InProcess");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("WorkOrder");
	
	OpenForm("Document.CustomerOrder.ListForm", OpenParameters);
	
EndProcedure // JobOrdersInProcessClick()

////////////////////////////////////////////////////////////////////////////////
// Purchase orders

// Procedure - ReceiptOverdue command handler of the PurchaseOrders list.
//
&AtClient
Procedure OrdersToSuppliersHasExpiredPressing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.PurchaseOrder.ListForm", OpenParameters);
	
EndProcedure // PurchaseOrdersOverdueExecutionClick()

// Procedure - PaymentOverdue command handler of the PurchaseOrders list.
//
&AtClient
Procedure OrdersToSuppliersHasExpiredPaymentButton(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("OverduePayment");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.PurchaseOrder.ListForm", OpenParameters);
	
EndProcedure // PurchaseOrdersOverduePaymentClick()

// Procedure - ForToday command handler of the PurchaseOrders list.
//
&AtClient
Procedure OrdersToSuppliersOnTodayClicking(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.PurchaseOrder.ListForm", OpenParameters);
	
EndProcedure // PurchaseOrdersForTodayClick()

// Procedure - InProcess command handler of the PurchaseOrders list.
//
&AtClient
Procedure OrdersToSuppliersInPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("InProcess");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.PurchaseOrder.ListForm", OpenParameters);
	
EndProcedure // PurchaseOrdersInProcessClick()

////////////////////////////////////////////////////////////////////////////////
// Production orders

// Procedure - ExecutionOverdue command handler of the ProductionOrders list.
//
&AtClient
Procedure ManufacturingOrdersDueFulfilmentOfPressing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.ProductionOrder.ListForm", OpenParameters);
	
EndProcedure // ProductionOrdersOverdueExecutionClick()

// Procedure - ForToday command handler of the ProductionOrders list.
//
&AtClient
Procedure ManufacturingOrdersOnTodayPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.ProductionOrder.ListForm", OpenParameters);
	
EndProcedure // ProductionOrdersForTodayClick()

// Procedure - InProcess command handler of the ProductionOrders list.
//
&AtClient
Procedure ManufacturingOrdersInWorkClicking(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("CurrentWorks");
	OpenParameters.Insert("InProcess");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.ProductionOrder.ListForm", OpenParameters);
	
EndProcedure // ProductionOrdersInProcessClick()

////////////////////////////////////////////////////////////////////////////////
// MONTH END

// Procedure - TotalsNotCalculated command handler of the MonthClosing list.
//
&AtClient
Procedure ClosingOfMonthResultsNotCalculatedPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenForm("DataProcessor.MonthEnd.Form");
	
EndProcedure // MonthClosingNotCalculatedTotalsClick()

////////////////////////////////////////////////////////////////////////////////
// My reminders

// Procedure - NotificationsTotally command handler of the MyNotifications list.
//
&AtClient
Procedure MyRemindersTotalRemindersClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenForm("InformationRegister.UserReminders.Form.MyReminders");
	
EndProcedure // MyRemindersTotalRemindersClick()














