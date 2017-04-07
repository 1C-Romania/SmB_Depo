
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	UsesExchangeEDWithBanks = ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue(
																				"UseEDExchangeWithBanks");
	If Not UsesExchangeEDWithBanks Then
		MessageText = ElectronicDocumentsServiceCallServer.MessageTextAboutSystemSettingRequirement(
																				"WorkWithBanks");
		CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
	EndIf;
	
	Items.PagesKindsOfBankingSystems.PagesRepresentation = FormPagesRepresentation.None;
	
	If Not IsBlankString(Parameters.OpenPage) Then
		Items.PagesSendGet.CurrentPage = Items[Parameters.OpenPage];
	EndIf;
	
	Items.Error.Visible = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FillParameters();
	FillTabularSection();
	PageSelector();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshStateED" Then
		If Items.PagesKindsOfBankingSystems.CurrentPage = Items.TypicalPage Then
			Items.Statements.Refresh();
		ElsIf Items.PagesKindsOfBankingSystems.CurrentPage = Items.PageAsynchronousExchange Then
			Items.BankStatementsAsynchronousExchange.Refresh();
		ElsIf Items.PagesKindsOfBankingSystems.CurrentPage = Items.SberBankPage Then
			Items.BankStatementSberbank.Refresh();
			Items.PaymentOrdersInProcessing.Refresh();
			ElectronicDocumentsToSendRefresh();
		EndIf;
	ElsIf EventName = "StatementsReceived" Then
		Items.BankStatementSberbank.Refresh();
		LatestED = LatestED(Object.EDAgreement);
		If ValueIsFilled(LatestED) THEN
			Items.BankStatementSberbank.CurrentRow = LatestED;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure EDAgreementOnChange(Item)
	
	FillParameters();
	Modified = False;
	PageSelector();
	FillTabularSection();
	
EndProcedure

&AtClient
Procedure PeriodOnChange(Item)
	
	Modified = False;
	
EndProcedure

#EndRegion


#Region FormCommandsHandlers


&AtClient
Procedure RequestStatement(Command)
	
	If Not ValueIsFilled(Period) Then
		MessageText = NStr("en='You should select period of the query';ru='Необходимо выбрать период запроса'");
		CommonUseClientServer.MessageToUser(MessageText, , "Period");
		Return;
	EndIf;
	
	If BankApplication = PredefinedValue("Enum.BankApplications.AsynchronousExchange") Then
		ElectronicDocumentsClient.GetBankStatement(
			Object.EDAgreement, Period.StartDate, Period.EndDate, Items.BankStatementsAsynchronousExchange);
	Else
		ElectronicDocumentsClient.GetBankStatement(
			Object.EDAgreement, Period.StartDate, Period.EndDate, Items.Statements);
	EndIf;
	
EndProcedure

&AtClient
Procedure ConnectionTest(Command)
	
	ElectronicDocumentsServiceClient.ValidateExistenceOfLinksWithBank(Object.EDAgreement, UUID);
	
EndProcedure

&AtClient
Procedure CancelSelected(Command)
		
	RowArray = Items.PaymentOrdersToSend.SelectedRows;
	For Each LineNumber IN RowArray Do
		TableRow = PaymentOrdersToSend.FindByID(LineNumber);
		If TableRow <> Undefined Then
			TableRow.DoDump = True;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure UncheckSelectionFromAllRows(Command)
	
	For Each CurDocument IN PaymentOrdersToSend Do
		If CurDocument.DoDump Then
			CurDocument.DoDump = False;
		EndIf;
	EndDo;

EndProcedure

&AtClient
Procedure SendMarked(Command)

	ArraySend = New Array();
	For Each string IN PaymentOrdersToSend Do
		If String.DoDump Then
			ArraySend.Add(String.ElectronicDocument);
		EndIf;
	EndDo;
	
	SendingParameters = New Structure;
	SendingParameters.Insert("SentCnt", 0);
	SendingParameters.Insert("ArraySend",  ArraySend);
	
	SentCnt = 0;
	If ArraySend.Count() > 0 Then
		ElectronicDocumentsServiceClient.SendPaymentOrdersSberbank(Object.EDAgreement, SendingParameters);
		Return;
	EndIf;
	
	ElectronicDocumentsServiceClient.DocumentsSendingDataProcessorSberbank(Object.EDAgreement, SendingParameters);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	ElectronicDocumentsToSendRefresh();
	
EndProcedure

&AtClient
Procedure GetStatement(Command)
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("GetStatementsQueryDataProcessorsResults");
	ExecuteParameters.Insert("GetBankStatementsDataProcessorsResults");
	ExecuteParameters.Insert("GetNightStatementsQueryDataProcessorsResults");
	ExecuteParameters.Insert("SendQueryToGetReadyAccountStatementsSberbank");
	
	ElectronicDocumentsServiceClient.SendQueryOnNightAccountStatementsSberbank(Object.EDAgreement, ExecuteParameters);
	
EndProcedure

&AtClient
Procedure GetStatuses(Command)
	
	GetPaymentOrdersStates(Object.EDAgreement);

EndProcedure

&AtClient
Procedure QueryExtractSberbank(Command)
	
	If Not ValueIsFilled(Period) Then
		MessageText = NStr("en='You should select period of the query';ru='Необходимо выбрать период запроса'");
		CommonUseClientServer.MessageToUser(MessageText, , "Period");
		Return;
	EndIf;
		
	If Period.StartDate > Period.EndDate Then
		MessageText = NStr("en='Date of period start shall be earlier than date of period end';ru='Дата начала периода должна быть меньше даты окончания'");
		CommonUseClientServer.MessageToUser(MessageText, , "Period");
		Return;
	EndIf;
	
	ED = Undefined;
	
	ElectronicDocumentsServiceClient.QueryExtractSberbank(
		Object.EDAgreement, Object.Company, Period.StartDate, Period.EndDate, , ED);
	
	Items.BankStatementSberbank.Refresh();
	
	If ValueIsFilled(ED) THEN
		Items.BankStatementSberbank.CurrentRow = ED;
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectPeriod(Command)
	
	StandardPeriodSelection(FilterPeriod);
		
EndProcedure

#EndRegion


#Region StatementFormTableItemsEventsHandlers

&AtClient
Procedure StatementsChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If ValueIsFilled(ValueSelected) Then
		Items.Statements.CurrentRow = ValueSelected;
	EndIf;
	
EndProcedure

#EndRegion


#Region BankStatementsFormTableItemsEventsHandlersAsynchronousExchange

&AtClient
Procedure BankStatementsAsynchronousExchangeChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If ValueIsFilled(ValueSelected) Then
		Items.BankStatementsAsynchronousExchange.CurrentRow = ValueSelected;
	EndIf;
	
EndProcedure

#EndRegion


#Region ServiceProceduresAndFunctions

&AtClient
Procedure GetPaymentOrdersStates(EDAgreement, Parameters = Undefined) Export
	
	If Not ValueIsFilled(EDAgreement) Then
		Return;
	EndIf;
	
	ND = New NotifyDescription("GetPaymentOrdersStates", ThisObject);
	ChannelSet = False;
	
	ElectronicDocumentsServiceClient.SetVirtualChannelWithSberbank(Object.EDAgreement, ChannelSet, ND);
	If Not ChannelSet Then
		Return;
	EndIf;
	
	PaymentOrder = PredefinedValue("Enum.EDKinds.PaymentOrder");
	ElectronicDocumentsServiceClient.GetSberbankQueriesDataProcessorsResults(EDAgreement, PaymentOrder);
	GetSberbankElectronicDocumentsStates(EDAgreement, PaymentOrder);
	
EndProcedure

&AtClient
Procedure PeriodChoiceProcessing(Period, AdditionalParameters) Export
	
	If ValueIsFilled(Period) Then
		FilterPeriod = Period;
		CommonUseClientServer.DeleteItemsOfFilterGroup(BankStatementSberbank.Filter, "CreationDate");
		CommonUseClientServer.AddCompositionItem(BankStatementSberbank.Filter, "CreationDate",
			DataCompositionComparisonType.GreaterOrEqual, Period.StartDate, , ValueIsFilled(Period.StartDate));
		CommonUseClientServer.AddCompositionItem(BankStatementSberbank.Filter, "CreationDate",
			DataCompositionComparisonType.LessOrEqual, EndOfDay(Period.EndDate), ,
			ValueIsFilled(Period.EndDate));
	EndIf;

EndProcedure

&AtClient
Procedure StandardPeriodSelection(Period)

	Dialog = New StandardPeriodEditDialog();
	Dialog.Period = Period;
	op = New NotifyDescription("PeriodChoiceProcessing", ThisObject);
	Dialog.Show(op);
	
EndProcedure

&AtClient
Procedure GetSberbankElectronicDocumentsStates(EDAgreement, EDKind)

	ArrayOfQueries = ElectronicDocumentsServiceCallServer.QueriesOnDocumentsDataProcessorsStatesArray(
																					EDAgreement, EDKind);
	Try
		
		AttachableModule1C = ElectronicDocumentsServiceClient.ValueFromCache("AttachableModule1CForSberbank");
		For Each Item IN ArrayOfQueries Do
			Response = AttachableModule1C.sendRequests(Item);
			Description = NStr("en='Document status request has been sent';ru='Оправлен запрос статуса документа'");
			ElectronicDocumentsServiceCallServer.WriteEventToLogAudit(
													EDAgreement, Description, Item);
			Description = NStr("en='Document status request ID has been received';ru='Получены идентификатор запроса статуса документа'");
			ElectronicDocumentsServiceCallServer.WriteEventToLogAudit(
														EDAgreement, Description, Response);
			ArrayOfIDs = New Array;
			ArrayOfIDs.Add(Response);
			ElectronicDocumentsServiceCallServer.SaveIdentifiers(ArrayOfIDs, EDAgreement, EDKind);
		EndDo;
	Except
		OperationKind = NStr("en='Receiving information about states of electronic documents';ru='Получение информации о состоянии электронных документов'");
		MessageText = NStr("en='There is no connection with the bank server';ru='Нет связи с сервером банка'") + Chars.LF
						+ NStr("en='details in the event log';ru='Подробности в журнале регистрации'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
			OperationKind, ErrorDescription(), MessageText, 1);
		SentCnt = 0;
	EndTry;

EndProcedure

&AtClient
Procedure PageSelector()
	
	If ValueIsFilled(Object.EDAgreement) Then
		BankApplication =  BankApplication(Object.EDAgreement);
		If BankApplication = PredefinedValue("Enum.BankApplications.SberbankOnline") Then
			Items.PagesKindsOfBankingSystems.CurrentPage = Items.SberBankPage;
			#If WebClient Then
				Items.PagesSendGet.CurrentPage    = Items.Error;
				Items.Error.Visible                             = True;
				Items.PagesSendGet.PagesRepresentation = FormPagesRepresentation.None;
			#EndIf
		ElsIf BankApplication = PredefinedValue("Enum.BankApplications.AsynchronousExchange") Then
			Items.PagesKindsOfBankingSystems.CurrentPage = Items.PageAsynchronousExchange;
		Else
			Items.PagesKindsOfBankingSystems.CurrentPage = Items.TypicalPage;
		EndIf;
	Else
		Items.PagesKindsOfBankingSystems.CurrentPage = Items.TypicalPage;
	EndIf;
	
	Items.RunExchangeWithBank.Enabled = ValueIsFilled(Object.EDAgreement);
	
EndProcedure

&AtClient
Procedure FillParameters()
	
	If ValueIsFilled(Object.EDAgreement) Then
		AgreementAttributes = AgreementAttributes(Object.EDAgreement);
		Object.Bank         = AgreementAttributes.Counterparty;
		Object.Company  = AgreementAttributes.Company;
		BankApplication      = AgreementAttributes.BankApplication;
	Else
		Object.Bank        = PredefinedValue("Catalog.Companies.EmptyRef");
		Object.Company = PredefinedValue("Catalog.Companies.EmptyRef");
		BankApplication     = PredefinedValue("Enum.BankApplications.EmptyRef");
	EndIf;
	
	If ValueIsFilled(Object.EDAgreement) Then
		CommonUseClientServer.SetFilterDynamicListItem(
								BankStatements, "EDAgreement", Object.EDAgreement);
		CommonUseClientServer.SetFilterDynamicListItem(
								BankStatementsAsynchronousExchange, "EDAgreement", Object.EDAgreement);
		CommonUseClientServer.SetFilterDynamicListItem(
								PaymentOrdersInProcessing, "EDAgreement", Object.EDAgreement);
		CommonUseClientServer.SetFilterDynamicListItem(
								BankStatementSberbank, "EDAgreement", Object.EDAgreement);
	Else
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(BankStatements, "EDAgreement");
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(
										BankStatementsAsynchronousExchange, "EDAgreement");
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(
										PaymentOrdersInProcessing, "EDAgreement");
		CommonUseClientServer.DeleteGroupsSelectionDynamicListItems(BankStatementSberbank, "EDAgreement");
	EndIf;

EndProcedure

&AtServerNoContext
Function BankApplication(EDAgreement)
	
	Return CommonUse.ObjectAttributeValue(EDAgreement, "BankApplication");
	
EndFunction

&AtServerNoContext
Function AgreementAttributes(EDAgreement)
	
	Return CommonUse.ObjectAttributesValues(EDAgreement, "Company, Counterparty, BankApplication");
	
EndFunction

&AtServer
Procedure ElectronicDocumentsToSendRefresh()
	
	Query = New Query;
	Query.Text = "SELECT
	               |	EDStates.ObjectReference.Counterparty AS Recipient,
	               |	EDStates.ObjectReference.Number AS Number,
	               |	EDStates.ObjectReference.Date AS Date,
	               |	EDStates.ObjectReference.DocumentAmount AS DocumentAmount,
	               |	EDStates.ObjectReference.PaymentDestination AS PaymentDestination,
	               |	EDStates.ObjectReference.CounterpartyAccount AS RecipientAccount,
	               |	EDStates.ElectronicDocument AS ElectronicDocument,
	               |	EDStates.ObjectReference.AccountOfCompany AS AccountOfCompany
	               |FROM
	               |	InformationRegister.EDStates AS EDStates
	               |WHERE
	               |	EDStates.EDVersionState = VALUE(Enum.EDVersionsStates.SendingExpected)
	               |	AND EDStates.ElectronicDocument.EDAgreement = &EDAgreement
	               |
	               |ORDER BY
	               |	Date";
	Query.SetParameter("EDAgreement", Object.EDAgreement);
	PaymentOrdersToSend.Load(Query.Execute().Unload());
	
EndProcedure

&AtClient
Procedure FillTabularSection()
	
	ElectronicDocumentsToSendRefresh();
	SetEnabledOfItems();
		
EndProcedure

&AtClient
Procedure SetEnabledOfItems()

	Items.PagesKindsOfBankingSystems.Enabled = ValueIsFilled(Object.EDAgreement);
	
EndProcedure

&AtServerNoContext
Function LatestED(EDAgreement)
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	EDAttachedFiles.Ref AS ElectronicDocument
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|WHERE
	|	EDAttachedFiles.EDAgreement = &EDAgreement
	|	AND (EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.QueryStatement)
	|			OR EDAttachedFiles.EDKind = VALUE(Enum.EDKinds.BankStatement))
	|
	|ORDER BY
	|	CreationDate DESC";
	Query.SetParameter("EDAgreement", EDAgreement);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.ElectronicDocument;
	EndIf
	
EndFunction

#EndRegion

 

