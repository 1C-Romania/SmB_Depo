
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Object.Owner) AND 
		NOT Object.Owner.UseSerialNumbers Then
	
		Message = New UserMessage();
		Message.Text = NStr("ru = 'Для номенклатуры не ведется учет по серийным номерам!
							|Установите флаг ""Использовать серийные номера"" в карточке номенклатуры'; en = 'No account by serial numbers for this products!
							|Select the ""Use serial numbers"" check box in products and services card'");
		Message.Message();
		Cancel = True;
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesPage");
	// End StandardSubsystems.Properties
	
	If ValueIsFilled(Object.Ref) Then
		Items.GroupFill.Visible = False;
	Else
		Items.GroupFill.Visible = True;
	EndIf;
	
	If Object.Sold Then
		GuaranteeData = Catalogs.SerialNumbers.GuaranteePeriod(Object.Ref, CurrentDate());
		If GuaranteeData.Count()>0 Then
			SaleInfo = ?(GuaranteeData.Guarantee, 
				String(GuaranteeData.DocumentSales)+", guarantee before"+GuaranteeData.GuaranteePeriod,
				String(GuaranteeData.DocumentSales));
			DocumentSales = GuaranteeData.DocumentSales;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure // FillCheckProcessingAtServer()

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If TrimAll(Object.Description)="" Then
	    Cancel = True;
		
		Message = New UserMessage();
		Message.Text = NStr("ru = 'Серийный номер не заполнен!'; en = 'Serial number is not filled!'");
		Message.Message();
	EndIf; 
	
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
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisObject, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure // Attachable_EditPropertyContent()

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisObject);
	
EndProcedure

// End StandardSubsystems.Properties

&AtServer
Procedure AddSerialNumberAtServer()
	
	//MaximumNumberFromCatalog = Catalogs.SerialNumbers.CalculateMaximumSerialNumber(Object.Owner, TemplateSerialNumber);
	Object.Description = WorkWithSerialNumbers.AddSerialNumber(Object.Owner, TemplateSerialNumber).NewNumber;
	
EndProcedure

&AtClient
Procedure AddSerialNumber(Command)
	
	AddSerialNumberAtServer();
	
EndProcedure

&AtClient
Procedure SaleInfoClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If ValueIsFilled(DocumentSales) Then
		OpenDocumentFormByType(DocumentSales);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenDocumentFormByType(DocumentRef)
	
	FormNameString = GetDocumentNameByType(TypeOf(DocumentRef));
	OpenForm("Document."+FormNameString+".ObjectForm", New Structure("Key", DocumentRef), ThisObject);
	
EndProcedure

// Gets the document name by type at client without server call.
&AtClient
Function GetDocumentNameByType(DocumentType) Export
	
	TypesStructure = New Map;
	
	TypesStructure.Insert(Type("DocumentRef.AcceptanceCertificate"), "AcceptanceCertificate");
	TypesStructure.Insert(Type("DocumentRef.AdditionalCosts"), "AdditionalCosts");
	TypesStructure.Insert(Type("DocumentRef.AgentReport"), "AgentReport");
	TypesStructure.Insert(Type("DocumentRef.Budget"), "Budget");
	TypesStructure.Insert(Type("DocumentRef.BulkMail"), "BulkMail");
	TypesStructure.Insert(Type("DocumentRef.CashOutflowPlan"), "CashOutflowPlan");
	TypesStructure.Insert(Type("DocumentRef.CashPayment"), "CashPayment");
	TypesStructure.Insert(Type("DocumentRef.CashReceipt"), "CashReceipt");
	TypesStructure.Insert(Type("DocumentRef.CashTransfer"), "CashTransfer");
	TypesStructure.Insert(Type("DocumentRef.CashTransferPlan"), "CashTransferPlan");
	TypesStructure.Insert(Type("DocumentRef.CostAllocation"), "CostAllocation");
	TypesStructure.Insert(Type("DocumentRef.CustomerInvoice"), "CustomerInvoice");
	TypesStructure.Insert(Type("DocumentRef.CustomerOrder"), "CustomerOrder");
	TypesStructure.Insert(Type("DocumentRef.Dismissal"), "Dismissal");
	TypesStructure.Insert(Type("DocumentRef.EDPackage"), "EDPackage");
	TypesStructure.Insert(Type("DocumentRef.EmployeeOccupationChange"), "EmployeeOccupationChange");
	TypesStructure.Insert(Type("DocumentRef.EmploymentContract"), "EmploymentContract");
	TypesStructure.Insert(Type("DocumentRef.EnterOpeningBalance"), "EnterOpeningBalance");
	TypesStructure.Insert(Type("DocumentRef.Event"), "Event");
	TypesStructure.Insert(Type("DocumentRef.ExpenseReport"), "ExpenseReport");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetsDepreciation"), "FixedAssetsDepreciation");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetsEnter"), "FixedAssetsEnter");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetsModernization"), "FixedAssetsModernization");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetsOutput"), "FixedAssetsOutput");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetsTransfer"), "FixedAssetsTransfer");
	TypesStructure.Insert(Type("DocumentRef.FixedAssetsWriteOff"), "FixedAssetsWriteOff");
	TypesStructure.Insert(Type("DocumentRef.GoodsExpense"), "GoodsExpense");
	TypesStructure.Insert(Type("DocumentRef.GoodsReceipt"), "GoodsReceipt");
	TypesStructure.Insert(Type("DocumentRef.InventoryAssembly"), "InventoryAssembly");
	TypesStructure.Insert(Type("DocumentRef.InventoryReceipt"), "InventoryReceipt");
	TypesStructure.Insert(Type("DocumentRef.InventoryReconciliation"), "InventoryReconciliation");
	TypesStructure.Insert(Type("DocumentRef.InventoryReservation"), "InventoryReservation");
	TypesStructure.Insert(Type("DocumentRef.InventoryTransfer"), "InventoryTransfer");
	TypesStructure.Insert(Type("DocumentRef.InventoryWriteOff"), "InventoryWriteOff");
	TypesStructure.Insert(Type("DocumentRef.InvoiceForPayment"), "InvoiceForPayment");
	TypesStructure.Insert(Type("DocumentRef.JobSheet"), "JobSheet");
	TypesStructure.Insert(Type("DocumentRef.MonthEnd"), "MonthEnd");
	TypesStructure.Insert(Type("DocumentRef.Netting"), "Netting");
	TypesStructure.Insert(Type("DocumentRef.Operation"), "Operation");
	TypesStructure.Insert(Type("DocumentRef.OtherExpenses"), "OtherExpenses");
	TypesStructure.Insert(Type("DocumentRef.PaymentExpense"), "PaymentExpense");
	TypesStructure.Insert(Type("DocumentRef.PaymentOrder"), "PaymentOrder");
	TypesStructure.Insert(Type("DocumentRef.PaymentReceipt"), "PaymentReceipt");
	TypesStructure.Insert(Type("DocumentRef.PaymentReceiptPlan"), "PaymentReceiptPlan");
	TypesStructure.Insert(Type("DocumentRef.Payroll"), "Payroll");
	TypesStructure.Insert(Type("DocumentRef.PayrollSheet"), "PayrollSheet");
	TypesStructure.Insert(Type("DocumentRef.PowerOfAttorney"), "PowerOfAttorney");
	TypesStructure.Insert(Type("DocumentRef.ProcessingReport"), "ProcessingReport");
	TypesStructure.Insert(Type("DocumentRef.ProductionOrder"), "ProductionOrder");
	TypesStructure.Insert(Type("DocumentRef.PurchaseOrder"), "PurchaseOrder");
	TypesStructure.Insert(Type("DocumentRef.RandomED"), "RandomED");
	TypesStructure.Insert(Type("DocumentRef.ReceiptCR"), "ReceiptCR");
	TypesStructure.Insert(Type("DocumentRef.ReceiptCRReturn"), "ReceiptCRReturn");
	TypesStructure.Insert(Type("DocumentRef.RegistersCorrection"), "RegistersCorrection");
	TypesStructure.Insert(Type("DocumentRef.ReportToPrincipal"), "ReportToPrincipal");
	TypesStructure.Insert(Type("DocumentRef.RetailReport"), "RetailReport");
	TypesStructure.Insert(Type("DocumentRef.RetailRevaluation"), "RetailRevaluation");
	TypesStructure.Insert(Type("DocumentRef.SalesTarget"), "SalesTarget");
	TypesStructure.Insert(Type("DocumentRef.SettlementsReconciliation"), "SettlementsReconciliation");
	TypesStructure.Insert(Type("DocumentRef.SubcontractorReport"), "SubcontractorReport");
	TypesStructure.Insert(Type("DocumentRef.SupplierInvoice"), "SupplierInvoice");
	TypesStructure.Insert(Type("DocumentRef.SupplierInvoiceForPayment"), "SupplierInvoiceForPayment");
	TypesStructure.Insert(Type("DocumentRef.TaxAccrual"), "TaxAccrual");
	TypesStructure.Insert(Type("DocumentRef.Timesheet"), "Timesheet");
	TypesStructure.Insert(Type("DocumentRef.TimeTracking"), "TimeTracking");
	TypesStructure.Insert(Type("DocumentRef.TransferBetweenCells"), "TransferBetweenCells");
	TypesStructure.Insert(Type("DocumentRef.WorkOrder"), "WorkOrder");
	
	Return TypesStructure.Get(DocumentType);

EndFunction

#EndRegion