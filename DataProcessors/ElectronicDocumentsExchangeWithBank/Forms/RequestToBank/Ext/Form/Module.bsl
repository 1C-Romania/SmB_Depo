
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not ValueIsFilled(Parameters.EDAgreement) AND Not ValueIsFilled(Parameters.ElectronicDocument) Then
		Cancel = True;
		Return;
	EndIf;
	
	AgreementAttributes = CommonUse.ObjectAttributesValues(
		Parameters.EDAgreement, "Company, Counterparty, BankApplication, CompanyID");
	
	BankApplication = AgreementAttributes.BankApplication;

	If BankApplication = Enums.BankApplications.ExchangeThroughTheAdditionalInformationProcessor
			OR BankApplication = Enums.BankApplications.iBank2 Then
	
		BankAccountsArray = New Array;
		If ValueIsFilled(Parameters.AccountNo) Then
			BankAccountsArray.Add(Parameters.AccountNo);
		Else
			ElectronicDocumentsOverridable.GetBankAccountNumbers(
				AgreementAttributes.Company, AgreementAttributes.Counterparty, BankAccountsArray);
		EndIf;
		
		BIN = CommonUse.ObjectAttributeValue(AgreementAttributes.Counterparty, "Code");
		AccountsStorage = PutToTempStorage(BankAccountsArray, UUID);
	EndIf;
		
	If ValueIsFilled(Parameters.ElectronicDocument) Then
		Title = NStr("en='ED query status';ru='Запрос состояния ЭД'");
	EndIf;
		
	PerformCryptoOperationsAtServer = ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer();

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
		
	Var QueryPosted, BankStatement;
	
	If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
		GetStatementThroughAdditionalDataProcessor();
		Return;
	ElsIf BankApplication = PredefinedValue("Enum.BankApplications.iBank2") Then
		GetBankStatementiBank2();
		Return;
	EndIf;
	
	If Not ValueIsFilled(Parameters.ElectronicDocument) Then
		
		StartSendingStatementRequestToBank();
		
	Else
		
		StartSendingEDStatusQuery();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If ErrorOccurred Then
		Cancel = True;
		ErrorOccurred = False;
		Items.Pages.CurrentPage = Items.Error;
		Items.FormCancel.Title = "Close";
	EndIf

EndProcedure

&AtClient
Procedure OnClose()
	
	OnCloseAtServer(JobID);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions


&AtClient
Procedure StartSendingStatementRequestToBank()
	
	QueryParameters = New Structure;
	QueryParameters.Insert("BankSessionID", Parameters.BankSessionID);
	QueryParameters.Insert("EDAgreement", Parameters.EDAgreement);
	QueryParameters.Insert("User", Parameters.User);
	QueryParameters.Insert("Password", Parameters.Password);
	QueryParameters.Insert("EDKindsArray", Parameters.EDKindsArray);
	
	OperationExecuted = SendStatementQueryOnServer(
		QueryParameters, StorageAddress, UUID, JobID, ErrorOccurred);
	
	If OperationExecuted Then
		ProcessStatementQueryResult();
		Return;
	EndIf;
	
	// Operation is not completed yet, it is executed with the use of a background job (asynchronously).
	IdleHandlerParameters = New Structure(
		"MinimumInterval, MaximumInterval, CurrentInterval, IntervalIncreaseCoefficient", 1, 15, 1, 1.4);
	AttachIdleHandler("Attachable_CheckJobExecutionStatementQuery", 1, True);

EndProcedure

&AtClient
Procedure StartSendingEDStatusQuery()
	
	QueryParameters = New Structure;
	QueryParameters.Insert("BankSessionID", Parameters.BankSessionID);
	QueryParameters.Insert("ElectronicDocument", Parameters.ElectronicDocument);
	QueryParameters.Insert("EDAgreement", Parameters.EDAgreement);
	
	OperationExecuted = SendEDStateQueryOnServer(
		QueryParameters, StorageAddress, UUID, JobID, ErrorOccurred);
	
	If OperationExecuted Then
		ProcessEDStateQueryResult();
		Return;
	EndIf;
	
	// Operation is not completed yet, it is executed with the use of a background job (asynchronously).
	IdleHandlerParameters = New Structure(
		"MinimumInterval, MaximumInterval, CurrentInterval, IntervalIncreaseCoefficient", 1, 15, 1, 1.4);
	AttachIdleHandler("Attachable_CheckJobExecutionEDStateQuery", 1, True);

EndProcedure

&AtServerNoContext
Function SendStatementQueryOnServer(Val QueryParameters, StorageAddress, UUID, JobID, IsError)
	
	StorageAddress = PutToTempStorage(Undefined, UUID);
	
	JobCompleted = False;
		
	JobDescription = NStr("en='Sending statement query to the bank';ru='Отправка запроса выписки в банк'");
	ExecuteParameters = New Array;
	ExecuteParameters.Add(QueryParameters);
	ExecuteParameters.Add(StorageAddress);
		
	If GetClientConnectionSpeed() = ClientConnectionSpeed.Low Then
		Timeout = 4;
	Else
		Timeout = 2;
	EndIf;
	
	Task = BackgroundJobs.Execute(
		"ElectronicDocumentsService.SendStatementRequestToBank", ExecuteParameters, , JobDescription);
	Try
		Task.WaitForCompletion(Timeout);
	Except
		// Special handling is not required. Hypothetically exception was thrown due to timeout.
	EndTry;

	JobID = Task.UUID;
	// If the operation is already finished, then immediately process the result.
	If LongActions.JobCompleted(Task.UUID) Then
		JobCompleted = True;
	EndIf;
	Return JobCompleted;
	
EndFunction

&AtServerNoContext
Function SendEDStateQueryOnServer(Val QueryParameters, StorageAddress, UUID, JobID, IsError)
	
	StorageAddress = PutToTempStorage(Undefined, UUID);
	
	JobCompleted = False;
		
	JobDescription = NStr("en='Sending ED state query to the bank';ru='Отправка запроса состояния ЭД в банк'");
	ExecuteParameters = New Array;
	ExecuteParameters.Add(QueryParameters);
	ExecuteParameters.Add(StorageAddress);
		
	If GetClientConnectionSpeed() = ClientConnectionSpeed.Low Then
		Timeout = 4;
	Else
		Timeout = 2;
	EndIf;
	
	Task = BackgroundJobs.Execute(
		"ElectronicDocumentsService.SendEDStateRequestToBank", ExecuteParameters, , JobDescription);
	Try
		Task.WaitForCompletion(Timeout);
	Except
		// Special handling is not required. Hypothetically exception was thrown due to timeout.
	EndTry;

	JobID = Task.UUID;
	// If the operation is already finished, then immediately process the result.
	If LongActions.JobCompleted(Task.UUID) Then
		JobCompleted = True;
	EndIf;
	Return JobCompleted;
	
EndFunction

&AtServerNoContext
Procedure OnCloseAtServer(Val JobID)
	
	LongActions.CancelJobExecution(JobID);
	
EndProcedure

&AtClient
Procedure Attachable_CheckJobExecutionEDStateQuery()

	Try
		If JobCompleted(JobID) Then
			ProcessEDStateQueryResult();
			Return;
		EndIf;
	Except
		Raise;
	EndTry;

	IdleHandlerParameters.CurrentInterval = IdleHandlerParameters.CurrentInterval
													* IdleHandlerParameters.IntervalIncreaseCoefficient;
	If IdleHandlerParameters.CurrentInterval > IdleHandlerParameters.MaxInterval Then
		IdleHandlerParameters.CurrentInterval = IdleHandlerParameters.MaxInterval;
	EndIf;
	AttachIdleHandler(
		"Attachable_CheckJobExecutionEDStateQuery", IdleHandlerParameters.CurrentInterval, True);
		
EndProcedure

&AtClient
Procedure Attachable_CheckJobExecutionStatementQuery()

	Try
		If JobCompleted(JobID) Then
			ProcessStatementQueryResult();
			Return;
		EndIf;
	Except
		Raise;
	EndTry;

	IdleHandlerParameters.CurrentInterval = IdleHandlerParameters.CurrentInterval
													* IdleHandlerParameters.IntervalIncreaseCoefficient;
	If IdleHandlerParameters.CurrentInterval > IdleHandlerParameters.MaxInterval Then
		IdleHandlerParameters.CurrentInterval = IdleHandlerParameters.MaxInterval;
	EndIf;
	AttachIdleHandler(
		"Attachable_CheckJobExecutionStatementQuery", IdleHandlerParameters.CurrentInterval, True);
		
EndProcedure

&AtClient
Procedure ProcessStatementQueryResult()

	SentCnt = 0;
	ReceivedNumber = 0;
	
	ReturnStructure = GetFromTempStorage(StorageAddress);
		
	ErrorOccurred = ReturnStructure.IsError;
	If ErrorOccurred AND ValueIsFilled(ReturnStructure.MessageText) Then
		CommonUseClientServer.MessageToUser(ReturnStructure.MessageText);
		OnCloseAtServer(JobID);
		Close();
		Return;
	EndIf;
	
	If ReturnStructure.Property("QueryPosted") AND ReturnStructure.QueryPosted Then
		SentCnt = 1;
	EndIf;
	
	If ValueIsFilled(ReturnStructure.BankStatement) Then
		ReceivedNumber = 1;
		
		If Not PerformCryptoOperationsAtServer AND ReturnStructure.Signatures.Count() > 0 Then
			
			AddSignaturesInElectronicDocument(ReturnStructure.BankStatement, ReturnStructure.Signatures);
			
		EndIf;
		
	EndIf;
	
	NotificationTitle = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
	NotificationText = NStr("en='The sent packages are not present';ru='Отправленных пакетов нет'");
	
	If SentCnt > 0 Then
		NotificationText = NStr("en='Documents sent: (%1)';ru='Отправлено документов: (%1)'");
		NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(NotificationText, SentCnt);
	EndIf;
	
	If ReceivedNumber > 0 Then
		NotificationText = NotificationText
		+ StringFunctionsClientServer.PlaceParametersIntoString(NStr("en=', received documents: (%1)';ru=', получено документов: (%1)'"), ReceivedNumber);
	EndIf;
	
	Notify("RefreshStateED");
	
	ShowUserNotification(NotificationTitle, , NotificationText);
	
	If Not BankApplication = PredefinedValue("Enum.BankApplications.AsynchronousExchange") Then
		NotifyChoice(ReturnStructure.BankStatement);
	ElsIf Not ErrorOccurred Then
		OperationExecuted = GetStatementAsynchronouslyOnServer(
			QueryParameters, StorageAddress, UUID, JobID, ErrorOccurred);
	
		If OperationExecuted Then
			HandleStatementReceiptResult();
			Return;
		EndIf;

		IdleHandlerParameters = New Structure(
			"MinimumInterval, MaximumInterval, CurrentInterval, IntervalIncreaseCoefficient", 1, 15, 1, 1.4);
		AttachIdleHandler("Attachable_CheckStatementReceivingProcess", 1, True);
	EndIf;

EndProcedure

&AtClient
Procedure ProcessEDStateQueryResult()

	SentCnt = 0;
	ReceivedNumber = 0;
	
	ReturnStructure = GetFromTempStorage(StorageAddress);
		
	ErrorOccurred = ReturnStructure.IsError;
	If ErrorOccurred Then
		CommonUseClientServer.MessageToUser(ReturnStructure.MessageText);
		OnCloseAtServer(JobID);
		Close();
		Return
	EndIf;
	
	If ReturnStructure.Property("QueryPosted") AND ReturnStructure.QueryPosted Then
		SentCnt = 1;
	EndIf;
	
	NotificationTitle = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
	NotificationText = NStr("en='The sent packages are not present';ru='Отправленных пакетов нет'");
	
	If SentCnt > 0 Then
		NotificationText = NStr("en='Documents sent: (%1)';ru='Отправлено документов: (%1)'");
		NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(NotificationText, SentCnt);
	EndIf;
	
	Notify("RefreshStateED");
	
	ShowUserNotification(NotificationTitle, , NotificationText);
	
	OperationExecuted = GetNotificationOnEDStateAsynchronouslyOnServer(
			QueryParameters, StorageAddress, UUID, JobID, ErrorOccurred);
	
	If OperationExecuted Then
		HandleNotificationsOnEDStateReceiptResult();
		Return;
	EndIf;

	IdleHandlerParameters = New Structure(
		"MinimumInterval, MaximumInterval, CurrentInterval, IntervalIncreaseCoefficient", 1, 15, 1, 1.4);
	AttachIdleHandler("Attachable_CheckNotificationOnStateReceivingProcess", 1, True);
	
EndProcedure

&AtServerNoContext
Function GetStatementAsynchronouslyOnServer(Val QueryParameters, StorageAddress, UUID, JobID, IsError)
	
	StorageAddress = PutToTempStorage(Undefined, UUID);
	
	JobCompleted = False;
		
	JobDescription = NStr("en='Getting statement from the bank';ru='Получение выписки из банка'");
	ExecuteParameters = New Array;
	ExecuteParameters.Add(QueryParameters);
	ExecuteParameters.Add(StorageAddress);
		
	If GetClientConnectionSpeed() = ClientConnectionSpeed.Low Then
		Timeout = 4;
	Else
		Timeout = 2;
	EndIf;
	
	Task = BackgroundJobs.Execute(
		"ElectronicDocumentsService.GetBankStatementAsynchronously", ExecuteParameters, , JobDescription);
	Try
		Task.WaitForCompletion(Timeout);
	Except
		// Special handling is not required. Hypothetically exception was thrown due to timeout.
	EndTry;

	JobID = Task.UUID;
	// If the operation is already finished, then immediately process the result.
	If LongActions.JobCompleted(Task.UUID) Then
		JobCompleted = True;
	EndIf;
	Return JobCompleted;
	
EndFunction

&AtServerNoContext
Function GetNotificationOnEDStateAsynchronouslyOnServer(Val QueryParameters, StorageAddress, UUID, JobID, IsError)
	
	StorageAddress = PutToTempStorage(Undefined, UUID);
	
	JobCompleted = False;
		
	JobDescription = NStr("en='Getting notifications about ED state';ru='Получение извещения о состоянии ЭД'");
	ExecuteParameters = New Array;
	ExecuteParameters.Add(QueryParameters);
	ExecuteParameters.Add(StorageAddress);
		
	If GetClientConnectionSpeed() = ClientConnectionSpeed.Low Then
		Timeout = 4;
	Else
		Timeout = 2;
	EndIf;
	
	Task = BackgroundJobs.Execute(
		"ElectronicDocumentsService.GetNotificationOnEDStateAsynchronously", ExecuteParameters, , JobDescription);
	Try
		Task.WaitForCompletion(Timeout);
	Except
		// Special handling is not required. Hypothetically exception was thrown due to timeout.
	EndTry;

	JobID = Task.UUID;
	// If the operation is already finished, then immediately process the result.
	If LongActions.JobCompleted(Task.UUID) Then
		JobCompleted = True;
	EndIf;
	Return JobCompleted;
	
EndFunction

&AtClient
Procedure Attachable_CheckStatementReceipt()

	Try
		If JobCompleted(JobID) Then
			HandleStatementReceiptResult();
			Return; // the task is performed, log out
		EndIf;
	Except
		Raise;
	EndTry;

	IdleHandlerParameters.CurrentInterval = IdleHandlerParameters.CurrentInterval
													* IdleHandlerParameters.IntervalIncreaseCoefficient;
	If IdleHandlerParameters.CurrentInterval > IdleHandlerParameters.MaxInterval Then
		IdleHandlerParameters.CurrentInterval = IdleHandlerParameters.MaxInterval;
	EndIf;
	AttachIdleHandler(
		"Attachable_CheckStatementReceivingProcess", IdleHandlerParameters.CurrentInterval, True);
EndProcedure

&AtClient
Procedure Attachable_CheckNotificationOnStateReceivingProcess()

	Try
		If JobCompleted(JobID) Then
			HandleNotificationsOnEDStateReceiptResult();
			Return;
		EndIf;
	Except
		Raise;
	EndTry;

	IdleHandlerParameters.CurrentInterval = IdleHandlerParameters.CurrentInterval
													* IdleHandlerParameters.IntervalIncreaseCoefficient;
	If IdleHandlerParameters.CurrentInterval > IdleHandlerParameters.MaxInterval Then
		IdleHandlerParameters.CurrentInterval = IdleHandlerParameters.MaxInterval;
	EndIf;
	AttachIdleHandler("Attachable_CheckNotificationOnStateReceivingProcess",
											IdleHandlerParameters.CurrentInterval, True);

EndProcedure

&AtClient
Procedure HandleStatementReceiptResult()
	
	ReceivedNumber = 0;
	
	ReturnStructure = GetFromTempStorage(StorageAddress);
		
	ErrorOccurred = ReturnStructure.IsError;
	If ErrorOccurred Then
		If ReturnStructure.Property("ReauthenticationIsRequired") Then
			ErrorOccurred = False;
			ProcessingParameters = New Structure;
			ProcessingParameters.Insert("EDAgreement", Parameters.EDAgreement);
			ProcessingParameters.Insert("ProcedureHandler", "ContinueGettingStatementAfterObtainingBankMarker");
			AuthorizationParameters = New Structure;
			If ElectronicDocumentsServiceClient.ReceivedAuthorizationData(Parameters.EDAgreement, AuthorizationParameters) Then
				HandleAuthenticationDataReceiving(AuthorizationParameters, ProcessingParameters);
			Else
				OOOZ = New NotifyDescription("HandleAuthenticationDataReceiving", ThisObject, ProcessingParameters);
				ElectronicDocumentsServiceClient.GetAuthenticationData(Parameters.EDAgreement, OOOZ);
			EndIf;
			Return;
		Else
			CommonUseClientServer.MessageToUser(ReturnStructure.MessageText);
			OnCloseAtServer(JobID);
			Close();
			Return;
		EndIf;
	EndIf;
	
	If ReturnStructure.Property("BankStatement") AND ValueIsFilled(ReturnStructure.BankStatement) Then
		ReceivedNumber = 1;
		
		If Not PerformCryptoOperationsAtServer AND ReturnStructure.Property("Signatures")
			AND ReturnStructure.Signatures.Count() > 0 Then
			
			AddSignaturesInElectronicDocument(ReturnStructure.BankStatement, ReturnStructure.Signatures);
			
		EndIf;
		
	EndIf;
	
	NotificationTitle = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
	
	
	If ReceivedNumber > 0 Then
		NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Received documents: (%1)';ru='Получено документов: (%1)'"), ReceivedNumber);
	EndIf;
	
	Notify("RefreshStateED");
	
	ShowUserNotification(NotificationTitle, , NotificationText);
	
	NotifyChoice(ReturnStructure.BankStatement);
	
EndProcedure

&AtClient
Procedure HandleNotificationsOnEDStateReceiptResult()
	
	ReceivedNumber = 0;
	
	ReturnStructure = GetFromTempStorage(StorageAddress);
		
	ErrorOccurred = ReturnStructure.IsError;
	If ErrorOccurred Then
		If ReturnStructure.Property("ReauthenticationIsRequired") Then
			ErrorOccurred = False;
			ProcessingParameters = New Structure;
			ProcessingParameters.Insert("EDAgreement", Parameters.EDAgreement);
			ProcessingParameters.Insert("ProcedureHandler", "ContinueGettingNotificationAfterObtainingBankMarker");
			AuthorizationParameters = New Structure;
			If ElectronicDocumentsServiceClient.ReceivedAuthorizationData(Parameters.EDAgreement, AuthorizationParameters) Then
				HandleAuthenticationDataReceiving(AuthorizationParameters, ProcessingParameters);
			Else
				OOOZ = New NotifyDescription("HandleAuthenticationDataReceiving", ThisObject, ProcessingParameters);
				ElectronicDocumentsServiceClient.GetAuthenticationData(Parameters.EDAgreement, OOOZ);
			EndIf;
			Return;
		Else
			CommonUseClientServer.MessageToUser(ReturnStructure.MessageText);
			OnCloseAtServer(JobID);
			Close();
			Return;
		EndIf;
	EndIf;
	
	If ReturnStructure.Property("Notification") AND ValueIsFilled(ReturnStructure.Notification) Then
		ReceivedNumber = 1;
		
		If Not PerformCryptoOperationsAtServer AND ReturnStructure.Property("Signatures")
			AND ReturnStructure.Signatures.Count() > 0 Then
			
			AddSignaturesInElectronicDocument(ReturnStructure.BankStatement, ReturnStructure.Signatures);
			
		EndIf;
		
	EndIf;
	
	NotificationTitle = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
	
	If ReceivedNumber > 0 Then
		NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Received documents: (%1)';ru='Получено документов: (%1)'"), ReceivedNumber);
	EndIf;
	
	Notify("RefreshStateED");
	
	ShowUserNotification(NotificationTitle, , NotificationText);
	
	Close();
	
EndProcedure

&AtServerNoContext
Function JobCompleted(Val JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

&AtClient
Procedure AddSignaturesInElectronicDocument(ED, Signatures)
	
	EDandSignaturesArray = New Array;
	For Each Signature IN Signatures Do
		DataStructure = New Structure("ElectronicDocument, SignatureData", ED, Signature);
		EDandSignaturesArray.Add(DataStructure);
	EndDo;
	
	ElectronicDocumentsServiceClient.AddInformationAboutSignature(EDandSignaturesArray);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure GetStatementThroughAdditionalDataProcessor()
	
	ExternalAttachableModule = ElectronicDocumentsServiceClient.ExternalConnectedModuleThroughAdditionalDataProcessor(
																								Parameters.EDAgreement);
	CertificateData = Parameters.CertificateData;
	
	BankStatementParameters = New Structure;
	StartDateString    = Format(Parameters.StartDate,    "DLF=D");
	EndDateString = Format(Parameters.EndDate, "DLF=D");
	EDName = NStr("en='Bank statement for period from 1% to %2';ru='Выписка банка за период с %1 по %2'");
	EDName = StringFunctionsClientServer.PlaceParametersIntoString(
						EDName, StartDateString, EndDateString);
	ReceivedNumber = 0;
	
	BankAccountNumbersArray = GetFromTempStorage(AccountsStorage);
	EDForChecking = New Array;
	
	For Each AccountNo IN BankAccountNumbersArray Do
		BankStatementParameters.Insert("AccountNo",        AccountNo);
		BankStatementParameters.Insert("BIN",               BIN);
		BankStatementParameters.Insert("StartDate"   ,     Format(Parameters.StartDate,    "DF=dd.MM.yyyy"));
		BankStatementParameters.Insert("EndDate",     Format(Parameters.EndDate, "DF=dd.MM.yyyy"));
		BankStatementParameters.Insert("DataSchemeVersion", "1.07");
		StatementData = ElectronicDocumentsServiceClient.SendQueryThroughAdditionalDataProcessor(
			ExternalAttachableModule, CertificateData.CertificateBinaryData, 2, BankStatementParameters);
		If StatementData = Undefined Then
			Continue;
		EndIf;
		For Each Signature IN StatementData.Signatures Do
			
			CertificateDataSignatures = ElectronicDocumentsServiceClient.CertificateDataThroughAdditionalDataProcessor(
																		ExternalAttachableModule, Signature.Certificate);
			If CertificateDataSignatures = Undefined Then
				ErrorOccurred = True;
				Return;
			EndIf;
			Signature.Insert("CertificateData", CertificateDataSignatures);
			
		EndDo;
		
		EDStatement = SaveBankStatement(StatementData, Parameters.EDAgreement, EDName);
		EDForChecking.Add(EDStatement);
		ElectronicDocumentsServiceCallServer.DeterminePerformedPaymentOrders(EDStatement);
		ReceivedNumber = ReceivedNumber + 1;
	EndDo;
	
	CheckParameters = New Structure;
	CheckParameters.Insert("EDArrayForCheckThroughAdditionalDataProcessor", EDForChecking);
	CheckParameters.Insert("ExternalAttachableModule", ExternalAttachableModule);
	CheckParameters.Insert("CurrentSignaturesCheckIndexThroughAdditionalDataProcessor", 0);
	CheckParameters.Insert("EDAgreement", Parameters.EDAgreement);
	ElectronicDocumentsServiceClient.StartCheckingSignaturesStatusesThroughAdditionalDataProcessor(
		ExternalAttachableModule, CheckParameters);
	
	NotificationTitle = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
			
	If ReceivedNumber = 0 Then
		NotificationText = NStr("en='No received documents';ru='Полученных документов нет'");
	Else
		NotificationText = NStr("en='Received documents: (%1)';ru='Получено документов: (%1)'");
		NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(NotificationText, ReceivedNumber);
	EndIf;
		
	Notify("RefreshStateED");
		
	ShowUserNotification(NotificationTitle, , NotificationText);
	
	NotifyChoice(EDStatement);
	
EndProcedure

&AtServerNoContext
Function SaveBankStatement(Val StatementData, Val EDAgreement, Val EDName)
	
	AgreementAttributes = CommonUse.ObjectAttributesValues(EDAgreement, "Company, Counterparty");
	
	
	FileURL = PutToTempStorage(StatementData.BankStatement);
	AddedFile = AttachedFiles.AddFile(
							EDAgreement,
							EDName,
							"xml",
							CurrentSessionDate(),
							CurrentSessionDate(),
							FileURL,
							,
							,
							Catalogs.EDAttachedFiles.GetRef());
		
	Responsible = ElectronicDocumentsOverridable.GetResponsibleByED(
										AgreementAttributes.Counterparty, EDAgreement);
	
	EDStructure = New Structure;
	EDStructure.Insert("Author",                    Users.AuthorizedUser());
	EDStructure.Insert("EDDirection",            Enums.EDDirections.Incoming);
	EDStructure.Insert("EDStatus",                 Enums.EDStatuses.Received);
	EDStructure.Insert("Responsible",            Responsible);
	EDStructure.Insert("Company",              AgreementAttributes.Company);
	EDStructure.Insert("EDKind",                    Enums.EDKinds.BankStatement);
	EDStructure.Insert("EDAgreement",             EDAgreement);
	EDStructure.Insert("Counterparty",               AgreementAttributes.Counterparty);
	EDStructure.Insert("EDStatusChangeDate",   CurrentSessionDate());
	EDStructure.Insert("SenderDocumentDate", CurrentSessionDate());
	EDStructure.Insert("FileDescription",        StringFunctionsClientServer.StringInLatin(EDName));
	
	ElectronicDocumentsServiceCallServer.ChangeByRefAttachedFile(AddedFile, EDStructure, False);
	
	For Each Signature IN StatementData.Signatures Do
		SignatureData = New Structure;
		SignatureData.Insert("NewSignatureBinaryData", Signature.Signature);
		SignatureData.Insert("Imprint",                  Signature.CertificateData.Imprint);
		SignatureData.Insert("SignatureDate",                CurrentSessionDate());
		SignatureData.Insert("Comment",                "");
		SignatureData.Insert("SignatureFileName",            NStr("Signature"));
		SignatureData.Insert("CertificateIsIssuedTo",        Signature.CertificateData.OwnerInitials);
		SignatureData.Insert("CertificateBinaryData",  Signature.Certificate);
		ElectronicDocumentsServiceCallServer.AddSignature(AddedFile, SignatureData);
	EndDo;
	
	Return AddedFile;
	
EndFunction

&AtClient
Procedure GetBankStatementiBank2() Export
	
	BankStatementParameters = New Structure;
	StartDateString = Format(Parameters.StartDate, "DLF=D");
	EndDateString = Format(Parameters.EndDate, "DLF=D");
	EDName = NStr("en='Bank statement for period from 1% to %2';ru='Выписка банка за период с %1 по %2'");
	EDName = StringFunctionsClientServer.PlaceParametersIntoString(
						EDName, StartDateString, EndDateString);
	ReceivedNumber = 0;
	
	BankAccountNumbersArray = GetFromTempStorage(AccountsStorage);
	EDForChecking = New Array;
	
	For Each AccountNo IN BankAccountNumbersArray Do
		BankStatementParameters.Insert("AccountNo",        AccountNo);
		BankStatementParameters.Insert("BIN",               BIN);
		BankStatementParameters.Insert("StartDate"   ,     Format(Parameters.StartDate,    "DF=dd.MM.yyyy"));
		BankStatementParameters.Insert("EndDate",     Format(Parameters.EndDate, "DF=dd.MM.yyyy"));
		BankStatementParameters.Insert("DataSchemeVersion", "1.07");
		StatementData = ElectronicDocumentsServiceClient.SendQueryiBank2("2", BankStatementParameters);
		If StatementData = Undefined Then
			Continue;
		EndIf;
		For Each Signature IN StatementData.Signatures Do
			
			CertificateDataSignatures = ElectronicDocumentsServiceClient.iBank2CertificateData(Signature.Certificate);
			If CertificateDataSignatures = Undefined Then
				ErrorOccurred = True;
				Return;
			EndIf;
			Signature.Insert("CertificateData", CertificateDataSignatures);
			
		EndDo;
		
		EDStatement = SaveBankStatement(StatementData, Parameters.EDAgreement, EDName);
		EDForChecking.Add(EDStatement);
		ElectronicDocumentsServiceCallServer.DeterminePerformedPaymentOrders(EDStatement);
		ReceivedNumber = ReceivedNumber + 1;
	EndDo;
	
	CheckParameters = New Structure;
	CheckParameters.Insert("EDArrayForCheckiBank2", EDForChecking);
	CheckParameters.Insert("CurrentSignaturesCheckIndexiBank2", 0);
	ElectronicDocumentsServiceClient.StartCheckingSignartureStatusesiBank2(CheckParameters);
	
	NotificationTitle = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
			
	If ReceivedNumber = 0 Then
		NotificationText = NStr("en='No received documents';ru='Полученных документов нет'");
	Else
		NotificationText = NStr("en='Received documents: (%1)';ru='Получено документов: (%1)'");
		NotificationText = StringFunctionsClientServer.PlaceParametersIntoString(NotificationText, ReceivedNumber);
	EndIf;
		
	Notify("RefreshStateED");
		
	ShowUserNotification(NotificationTitle, , NotificationText);
	
	NotifyChoice(EDStatement);

EndProcedure

&AtClient
Procedure HandleAuthenticationDataReceiving(AuthorizationParameters, ProcessingParameters) Export
	
	If AuthorizationParameters = Undefined Then
		ErrorOccurred = False;
		Close();
		Return;
	EndIf;
	
	ProcessingParameters.Insert("ObjectHandler", ThisObject);
	ElectronicDocumentsServiceClient.GetBankMarker(AuthorizationParameters, ProcessingParameters);

EndProcedure

&AtClient
Procedure ContinueGettingStatementAfterObtainingBankMarker(Result, ProcessingParameters) Export
	
	If Not ValueIsFilled(ProcessingParameters.BankSessionID) Then
		ErrorOccurred = False;
		Close();
		Return;
	EndIf;
	
	QueryParameters.BankSessionID = ProcessingParameters.BankSessionID;
	OperationExecuted = GetStatementAsynchronouslyOnServer(
		QueryParameters, StorageAddress, UUID, JobID, ErrorOccurred);
	
	If OperationExecuted Then
		HandleStatementReceiptResult();
		Return;
	EndIf;

	IdleHandlerParameters = New Structure(
			"MinimumInterval, MaximumInterval, CurrentInterval, IntervalIncreaseCoefficient", 1, 15, 1, 1.4);
	AttachIdleHandler("Attachable_CheckStatementReceivingProcess", 1, True);

EndProcedure

&AtClient
Procedure ContinueGettingNotificationAfterObtainingBankMarker(Result, ProcessingParameters) Export
	
	If Not ValueIsFilled(ProcessingParameters.BankSessionID) Then
		ErrorOccurred = False;
		Close();
		Return;
	EndIf;
	
	QueryParameters.BankSessionID = ProcessingParameters.BankSessionID;
	OperationExecuted = GetNotificationOnEDStateAsynchronouslyOnServer(
		QueryParameters, StorageAddress, UUID, JobID, ErrorOccurred);
	
	If OperationExecuted Then
		HandleNotificationsOnEDStateReceiptResult();
		Return;
	EndIf;

	IdleHandlerParameters = New Structure(
		"MinimumInterval, MaximumInterval, CurrentInterval, IntervalIncreaseCoefficient", 1, 15, 1, 1.4);
	AttachIdleHandler("Attachable_CheckNotificationOnStateReceivingProcess", 1, True);
	
EndProcedure


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
