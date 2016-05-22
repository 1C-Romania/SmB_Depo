
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.BasisDocumentsBasisDocument.TypeRestriction = Parameters.ValidTypes;
	
	AddressBasisDocumentsInStorage = Parameters.AddressBasisDocumentsInStorage;
	
	BasisDocuments.Load(GetFromTempStorage(AddressBasisDocumentsInStorage));
	
EndProcedure

&AtClient
Procedure OK(Command)
	
	Cancel = False;
	
	CheckFillOfFormAttributes(Cancel);
	
	If Not Cancel Then
		WriteBasisDocumentsToStorage();
		Close(DialogReturnCode.OK);
	EndIf;

EndProcedure

// The procedure places pick-up results in the storage.
//
&AtServer
Procedure WriteBasisDocumentsToStorage()
	
	BasisDocumentsInStorage = BasisDocuments.Unload(, "BasisDocument");
	PutToTempStorage(BasisDocumentsInStorage, AddressBasisDocumentsInStorage);
	
EndProcedure // WritePickToStorage()

// Procedure checks the correctness of the form attributes filling.
//
&AtClient
Procedure CheckFillOfFormAttributes(Cancel)
	
	// Attributes filling check.
	LineNumber = 0;
		
	For Each RowDocumentsBases IN BasisDocuments Do
		LineNumber = LineNumber + 1;
		If Not ValueIsFilled(RowDocumentsBases.BasisDocument) Then
			Message = New UserMessage();
			Message.Text = NStr("en = 'Column ""Basis document"" is not filled in line '")
				+ String(LineNumber)
				+ NStr("en = ' of list ""Basis documents""'");
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
	EndDo;
	
EndProcedure // CheckFillFormAttributes()

&AtServer
Function BasisDocumentsBasisDocumentChoiceProcessingAtServer(ValueSelected)
	
	If BasisDocuments.Count() = 0 Then
		Return False;
	EndIf;
	
	CurrencyForFilter = Undefined;
	CounterpartyForFilter = Undefined;
	ContractForSelection = Undefined;
	
	For Each CurRow IN BasisDocuments Do
		If CurRow = BasisDocuments.FindByID(Items.BasisDocuments.CurrentRow) Then
			Continue;
		EndIf;
		If (ValueIsFilled(CurRow.BasisDocument))
			AND (TypeOf(CurRow.BasisDocument) = Type("DocumentRef.CustomerInvoice")
			OR TypeOf(CurRow.BasisDocument) = Type("DocumentRef.AgentReport")
			OR TypeOf(CurRow.BasisDocument) = Type("DocumentRef.AcceptanceCertificate")
			OR TypeOf(CurRow.BasisDocument) = Type("DocumentRef.ProcessingReport")
			OR TypeOf(CurRow.BasisDocument) = Type("DocumentRef.CustomerOrder")
			OR TypeOf(CurRow.BasisDocument) = Type("DocumentRef.InvoiceForPayment")
			OR TypeOf(CurRow.BasisDocument) = Type("DocumentRef.ReportToPrincipal"))
			AND ValueIsFilled(CurRow.BasisDocument.DocumentCurrency) Then
			CounterpartyForFilter = CurRow.BasisDocument.Counterparty;
			ContractForSelection = CurRow.BasisDocument.Contract;
			CurrencyForFilter = CurRow.BasisDocument.DocumentCurrency;
		EndIf;
		If (ValueIsFilled(CurRow.BasisDocument))
			AND (TypeOf(CurRow.BasisDocument) = Type("DocumentRef.CashReceipt")
			OR TypeOf(CurRow.BasisDocument) = Type("DocumentRef.PaymentReceipt")) Then
			CounterpartyForFilter = CurRow.BasisDocument.Counterparty;
			CurrencyForFilter = CurRow.BasisDocument.CashCurrency;
		EndIf;
	EndDo;
	
	If Not ValueIsFilled(CurrencyForFilter)
		AND Not ValueIsFilled(CounterpartyForFilter)
		AND Not ValueIsFilled(ContractForSelection) Then
		Return False;
	EndIf;
	
	If (ValueIsFilled(ValueSelected))
		AND (TypeOf(ValueSelected) = Type("DocumentRef.CustomerInvoice")
		OR TypeOf(ValueSelected) = Type("DocumentRef.AgentReport")
		OR TypeOf(ValueSelected) = Type("DocumentRef.AcceptanceCertificate")
		OR TypeOf(ValueSelected) = Type("DocumentRef.ProcessingReport")
		OR TypeOf(ValueSelected) = Type("DocumentRef.CustomerOrder")
		OR TypeOf(ValueSelected) = Type("DocumentRef.InvoiceForPayment")
		OR TypeOf(ValueSelected) = Type("DocumentRef.ReportToPrincipal")) Then
		Return CurrencyForFilter <> ValueSelected.DocumentCurrency
			OR CounterpartyForFilter <> ValueSelected.Counterparty
			OR ContractForSelection <> ValueSelected.Contract;
	EndIf;
	
	If (ValueIsFilled(ValueSelected))
		AND (TypeOf(ValueSelected) = Type("DocumentRef.CashReceipt")
		OR TypeOf(ValueSelected) = Type("DocumentRef.PaymentReceipt")) Then
		Return CurrencyForFilter <> ValueSelected.CashCurrency
			OR CounterpartyForFilter <> ValueSelected.Counterparty;
	EndIf;
	
	Return False;
	
EndFunction

&AtClient
Procedure BasisDocumentsBasisDocumentChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	Cancel = BasisDocumentsBasisDocumentChoiceProcessingAtServer(ValueSelected);
	
	If Cancel Then
		MessageText = NStr("en='Counterparty, agreement and currency of the selected document differs from the previously selected documents.'");
		ClearMessages();
		CommonUseClientServer.MessageToUser(MessageText);
		StandardProcessing = False;
	EndIf;
	
EndProcedure
