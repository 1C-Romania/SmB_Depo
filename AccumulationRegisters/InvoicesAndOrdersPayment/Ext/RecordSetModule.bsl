#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure calculates and writes payment order.
// Payment date is specified in "Period". When actual
// payment for order happens schedule closing by FIFO.
//
Procedure CalculatePaymentOfOrders()
	
	AccountsTable = AdditionalProperties.AccountsTable;
	Query = New Query;
	Query.SetParameter("AccountsPayableArray", AccountsTable.UnloadColumn("InvoiceForPayment"));
	Query.Text =
	"SELECT
	|	InvoicesAndOrdersPaymentTurnovers.InvoiceForPayment AS InvoiceForPayment,
	|	SUM(InvoicesAndOrdersPaymentTurnovers.AmountTurnover) AS Amount,
	|	SUM(InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover) AS AdvanceAmount,
	|	SUM(InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover) AS PaymentAmount
	|FROM
	|	AccumulationRegister.InvoicesAndOrdersPayment.Turnovers(, , , InvoiceForPayment IN (&AccountsPayableArray)) AS InvoicesAndOrdersPaymentTurnovers
	|
	|GROUP BY
	|	InvoicesAndOrdersPaymentTurnovers.InvoiceForPayment";
	
	RecordSet = InformationRegisters.OrdersPaymentFact.CreateRecordSet();
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		CurInvoiceForPayment = Selection.InvoiceForPayment;
		
		RecordSet.Filter.InvoiceForPayment.Set(CurInvoiceForPayment);
		
		// Delete the closed invoice for payment from the table.
		AccountsTable.Delete(AccountsTable.Find(CurInvoiceForPayment, "InvoiceForPayment"));
		
		Record = RecordSet.Add();
		Record.InvoiceForPayment = Selection.InvoiceForPayment;
		Record.Amount = Selection.Amount;
		Record.AdvanceAmount = Selection.AdvanceAmount;
		Record.PaymentAmount = Selection.PaymentAmount;
		
		RecordSet.Write(True);
		RecordSet.Clear();
		
	EndDo;
	
	// By unfinished orders need clear register records.
	If AccountsTable.Count() > 0 Then
		For Each TabRow IN AccountsTable Do
			
			RecordSet.Filter.InvoiceForPayment.Set(TabRow.InvoiceForPayment);
			RecordSet.Write(True);
			RecordSet.Clear();
			
		EndDo;
	EndIf;
	
EndProcedure // CalculatePaymentOfOrders()

// Procedure forms the accounts (orders) table  which
// were previously in the register records and which will be written now.
//
Procedure GenerateTableOfInvoicesForPayment()
	
	Query = New Query;
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.Text =
	"SELECT DISTINCT
	|	TableInvoicesAndOrdersPayment.InvoiceForPayment AS InvoiceForPayment
	|FROM
	|	AccumulationRegister.InvoicesAndOrdersPayment AS TableInvoicesAndOrdersPayment
	|WHERE
	|	TableInvoicesAndOrdersPayment.Recorder = &Recorder";
	
	AccountsTable = Query.Execute().Unload();
	TableOfNewAccounts = Unload(, "InvoiceForPayment");
	TableOfNewAccounts.GroupBy("InvoiceForPayment");
	For Each Record IN TableOfNewAccounts Do
		
		If AccountsTable.Find(Record.InvoiceForPayment, "InvoiceForPayment") = Undefined Then
			AccountsTable.Add().InvoiceForPayment = Record.InvoiceForPayment;
		EndIf;
		
	EndDo;
	
	AdditionalProperties.Insert("AccountsTable", AccountsTable);
	
EndProcedure // GenerateTableOfInvoicesForPayment()

// Procedure sets data lock for payment calculation.
//
Procedure SetLockDataForCalculationOfPayment()
	
	Block = New DataLock;
	
	// Locking the register for balance calculation according to the schedule.
	LockItem = Block.Add("AccumulationRegister.InvoicesAndOrdersPayment");
	LockItem.Mode = DataLockMode.Shared;
	LockItem.DataSource = AdditionalProperties.AccountsTable;
	LockItem.UseFromDataSource("InvoiceForPayment", "InvoiceForPayment");
	
	// Locking the record set.
	LockItem = Block.Add("InformationRegister.OrdersPaymentFact");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = AdditionalProperties.AccountsTable;
	LockItem.UseFromDataSource("InvoiceForPayment", "InvoiceForPayment");
	
	Block.Lock();
	
EndProcedure // SetLockDataForCalculationOfPayment()

#EndRegion

#Region EventsHandlers

// Procedure - event handler BeforeWrite record set.
//
Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	GenerateTableOfInvoicesForPayment();
	SetLockDataForCalculationOfPayment();
	
EndProcedure // BeforeWrite()

// Procedure - event handler OnWrite record set.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CalculatePaymentOfOrders();
	
EndProcedure // OnRecord()

#EndRegion

#EndIf