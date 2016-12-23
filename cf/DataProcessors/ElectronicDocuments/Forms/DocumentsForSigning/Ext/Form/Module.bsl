#Region ServiceProceduresAndFunctions

&AtServer
Function InUseExchangeWithBanks()
	
	Return ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseEDExchangeWithBanks");
	
EndFunction

&AtServer
Procedure CompleteListOfCertificatesAndDocuments(CertificateTumbprintsArray)
	
	AvailableCertificatesTable = ElectronicDocumentsService.AvailableForSigningCertificatesTable(
																			CertificateTumbprintsArray);
	FillInSummaryTable(AvailableCertificatesTable);
	CompleteListOfCertificates(AvailableCertificatesTable);
	
EndProcedure

&AtServer
Procedure CompleteListOfCertificates(AvailableCertificatesTable)
	
	CertificatesTable.Clear();
	For Each CurRow IN AvailableCertificatesTable Do
		TableRow = CertificatesTable.Add();
		TableRow.Certificate = CurRow.Ref;
		TableRow.Imprint = CurRow.Imprint;
		TableRow.UserPassword = CurRow.UserPassword;
		FilterParameters = New Structure("Certificate", CurRow.Ref);
		TableRow.DocumentsCount = SummaryTable.FindRows(FilterParameters).Count();
	EndDo;
	
EndProcedure

&AtServer
Procedure FillInSummaryTable(AvailableCertificatesTable)
	
	QueryOnDocuments = New Query;
	
	AddFilterStructure = New Structure;
	If ValueIsFilled(Counterparty) Then 
		AddFilterStructure.Insert("Counterparty", Counterparty);
		QueryOnDocuments.SetParameter("Counterparty", Counterparty);
	EndIf;
	If ValueIsFilled(EDKind) Then 
		AddFilterStructure.Insert("EDKind", EDKind);
		QueryOnDocuments.SetParameter("EDKind", EDKind);
	EndIf;
	If ValueIsFilled(EDDirection) Then 
		AddFilterStructure.Insert("EDDirection", EDDirection);
		QueryOnDocuments.SetParameter("EDDirection", EDDirection);
	EndIf;
	
	QueryOnDocuments.Text = ElectronicDocuments.GetTextOfElectronicDocumentsQueryOnSigning(False, AddFilterStructure);
	QueryOnDocuments.SetParameter("CurrentUser", Users.CurrentUser());
	Table = QueryOnDocuments.Execute().Unload();
	
	ValueToFormAttribute(Table, "SummaryTable");
	
EndProcedure

&AtClient
Procedure RefillTables()
	
	Try
		If ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer() Then
			CertificateTumbprintsArray = ElectronicDocumentsServiceCallServer.CertificateTumbprintsArray();
		Else
			Notification = New NotifyDescription("AfterGettingThumbprintsRefillTables", ThisObject);
			DigitalSignatureClient.GetCertificatesThumbprints(Notification, True, False);
			Return;
		EndIf;
	Except
		CertificateTumbprintsArray = New Array;
	EndTry;
	
	CompleteListOfCertificatesAndDocuments(CertificateTumbprintsArray);
	DocumentsFillListCertificate();
	
EndProcedure

&AtClient
Procedure AfterGettingThumbprintsRefillTables(Prints, AdditionalParameters = Undefined) Export
	
	CertificateTumbprintsArray = New Array;
	For Each KeyValue IN Prints Do
		CertificateTumbprintsArray.Add(KeyValue.Key);
	EndDo;
	
	CompleteListOfCertificatesAndDocuments(CertificateTumbprintsArray);
	DocumentsFillListCertificate();
	
EndProcedure

&AtClient
Function IsDocumentsForSigning() 
	
	CheckData = ?(Items.CertificatesTable.CurrentData = Undefined,
		CertificatesTable[0], Items.CertificatesTable.CurrentData);
	
	If CheckData.DocumentsCount = 0 Then
		WarningText = NStr("en='No documents to be signed up by this certificate';ru='По данному сертификату нет документов на подпись'");
		ShowMessageBox(, WarningText);
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtClient
Procedure GoToPage(ToDrillDown)
	
	If ToDrillDown Then
		Items.APMPages.CurrentPage = Items.APMPages.ChildItems.DetalizationPage;
		Title = NStr("en='Documents for signature by certificate';ru='Документы на подпись по сертификату'")+ ": " + SignatureCertificate;
	Else
		Items.APMPages.CurrentPage = Items.APMPages.ChildItems.PageSummary;
		Title = NStr("en='Documents for signature';ru='Документы на подпись'");
	EndIf;
	
	If ThisCertificateOfSberbank(SignatureCertificate) Then
		Items.Sign.Title = NStr("en='Sign marked';ru='Подписать отмеченные'");
	Else
		Items.Sign.Title = NStr("en='Sign up and send the selected';ru='Подписать и отправить отмеченные'");
	EndIf;
	
EndProcedure

&AtServer
Procedure DocumentsFillListCertificate()
	
	DocumentsTable.Clear();
	FilterParameters = New Structure("Certificate", SignatureCertificate);
	DocumentsRows = SummaryTable.FindRows(FilterParameters);
	
	For Each RowWithDocument IN DocumentsRows Do
		TableRow = DocumentsTable.Add();
		FillPropertyValues(TableRow, RowWithDocument);
	EndDo;
		
EndProcedure

&AtServerNoContext
Function ThisCertificateOfSberbank(Certificate)
	
	Query = New Query;
	Query.Text =
	"SELECT
		|	BankApplications.DSCertificate
		|FROM
		|	InformationRegister.BankApplications AS BankApplications
		|WHERE
		|	BankApplications.DSCertificate = &DSCertificate
		|	AND BankApplications.BankApplication = &BankApplication";
	
	Query.SetParameter("BankApplication", Enums.BankApplications.SberbankOnline);
	Query.SetParameter("DSCertificate", Certificate);
	
	QueryResult = Query.Execute();
	
	Return Not (QueryResult.IsEmpty());
	
EndFunction

&AtClient
Procedure NotifyUser(DigitallySignedCnt, PreparedCnt, SentCnt)
	
	StatusText = NStr("en='Arbitrary EDs digitally signed: (%1)';ru='Подписано произвольных ЭД: (%1)'");
	Quantity = 0;
	If SentCnt > 0 Then
		StatusText = StatusText + Chars.LF + NStr("en='Sent: (%2)';ru='Отправлено: (%2)'");
		Quantity = SentCnt;
	ElsIf PreparedCnt > 0 Then
		StatusText = NStr("en='Prepared for sending: (%2)';ru='Подготовлено к отправке: (%2)'");
		Quantity = PreparedCnt;
	EndIf;
	HeaderText = NStr("en='Electronic document exchange';ru='Обмен электронными документами'");
	StatusText = StringFunctionsClientServer.PlaceParametersIntoString(StatusText, DigitallySignedCnt, Quantity);
	ShowUserNotification(HeaderText, , StatusText);
	
	Notify("RefreshStateED");
	
EndProcedure

&AtClient
Procedure ActionsOnOpen(ExecuteCOAtServer)
	
	Cancel = False;
	InUseExchangeWithBanks = InUseExchangeWithBanks();
	CertificateStructuresArray = New Array;
	If ExecuteCOAtServer Then
		IsCryptofacilitiesAtServer = ElectronicDocumentsServiceCallServer.IsCryptofacilitiesAtServer();
		If Not (IsCryptofacilitiesAtServer OR InUseExchangeWithBanks) Then
			Cancel = True;
		ElsIf IsCryptofacilitiesAtServer Then
			CertificateTumbprintsArray = ElectronicDocumentsServiceCallServer.CertificateTumbprintsArray();
		EndIf;
	Else
		If Not Cancel Then
			Notification = New NotifyDescription("AfterGettingThumbprintsExecuteActions", ThisObject);
			DigitalSignatureClient.GetCertificatesThumbprints(Notification, True, Not InUseExchangeWithBanks);
			Return;
		EndIf;
	EndIf;
	
	If Cancel Then
		Close();
		Return;
	EndIf;
	
	AfterGettingThumbprintsExecuteActions(New Map);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Office handlers for asynchronous dialogs

&AtClient
Procedure AfterGettingThumbprintsExecuteActions(Prints, AdditionalParameters = Undefined) Export
	
	CertificateTumbprintsArray = New Array;
	For Each KeyValue IN Prints Do
		CertificateTumbprintsArray.Add(KeyValue.Key);
	EndDo;

	CompleteListOfCertificatesAndDocuments(CertificateTumbprintsArray);
	
	If CertificatesTable.Count() = 0 Then
		WarningText = NStr("en='No signature certificates for
		|the user or the documents signing rules are not configured!';ru='Нет сертификатов подписи
		|для пользователя или не настроены правила подписи документов!'"); 
		ShowMessageBox(, WarningText);
		Close();
		Return;
	EndIf;
	
	If CertificatesTable.Count() > 1 Then
		GoToPage(False);
	Else
		SignatureCertificate = CertificatesTable[0].Certificate;
		DocumentsFillListCertificate();
		GoToPage(True);
		Items.ButtonsGroupBack.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterInstallExpansionForCryptographyWork(ExtensionIsSet, AdditionalParameters) Export
	
	If ExtensionIsSet = True Then
		Enabled = True;
		ActionsOnOpen(False);
	Else
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Refresh(Command)
	
	RefillTables();
	
EndProcedure

&AtClient
Procedure Sign(Command)
	
	EDKindsArray = New Array;
	For Each CurRow IN DocumentsTable Do
		If CurRow.Select Then
			EDKindsArray.Add(CurRow.ElectronicDocument);
		EndIf;
	EndDo;
	
	ElectronicDocumentsClient.GenerateSignSendED(Undefined, EDKindsArray);
	
EndProcedure

&AtClient
Procedure SignAll(Command)
	
	If Not IsDocumentsForSigning() Then
		Return;
	EndIf;
	
	// All documents to be signed up by selected certificate
	SignatureCertificate = ?(Items.CertificatesTable.CurrentData = Undefined,
		CertificatesTable[0].Certificate, Items.CertificatesTable.CurrentData.Certificate);
	
	FilterParameters = New Structure("Certificate", SignatureCertificate);
	DocumentsRows = SummaryTable.FindRows(FilterParameters);
	
	ArrayOfSignatureDocument = New Array;
	For Each TableElement IN DocumentsRows Do
		ArrayOfSignatureDocument.Add(TableElement.ElectronicDocument);
	EndDo;
	
	ElectronicDocumentsClient.GenerateSignSendED(ArrayOfSignatureDocument);
	
EndProcedure

&AtClient
Procedure ReturnToCertificatesList(Command)
	
	GoToPage(False);
	
EndProcedure

&AtClient
Procedure GoToDocumentsList(Command)
	
	SignatureCertificate = ?(Items.CertificatesTable.CurrentData = Undefined,
		CertificatesTable[0].Certificate, Items.CertificatesTable.CurrentData.Certificate);
		
	If Not IsDocumentsForSigning() Then
		Return;
	EndIf;
	
	DocumentsFillListCertificate();
	GoToPage(True);
	
EndProcedure

&AtClient
Procedure CancelSelected(Command)
	
	RowArray = Items.DocumentsTable.SelectedRows;
	For Each LineNumber IN RowArray Do
		TableRow = DocumentsTable.FindByID(LineNumber);
		If TableRow <> Undefined Then
			TableRow.Select = True;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure UncheckSelectionFromAllRows(Command)
	
	For Each CurDocument IN DocumentsTable Do
		If CurDocument.Select Then
			CurDocument.Select = False;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region FieldsFormEventsHandlers

&AtClient
Procedure CounterpartyOnChange(Item)
	
	RefillTables();
	
EndProcedure

&AtClient
Procedure DocumentsTableSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	ElectronicDocumentsServiceClient.OpenEDForViewing(Items.DocumentsTable.CurrentData.ElectronicDocument);
	
EndProcedure

&AtClient
Procedure CertificatesTableSelection(Item, SelectedRow, Field, StandardProcessing)
	
	SignatureCertificate = Items.CertificatesTable.CurrentData.Certificate;
	If Not IsDocumentsForSigning() Then
		Return;
	EndIf;
	
	DocumentsFillListCertificate();
	GoToPage(True);
	
EndProcedure

&AtClient
Procedure EDKindOnChange(Item)
	
	RefillTables();
	
EndProcedure

&AtClient
Procedure EDDirectionOnChange(Item)
	
	RefillTables();
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	ExecuteCOAtServer = ElectronicDocumentsServiceCallServer.PerformCryptoOperationsAtServer();
	If ExecuteCOAtServer Then
		ActionsOnOpen(ExecuteCOAtServer);
	Else
		Enabled = False;
		Handler = New NotifyDescription("AfterInstallExpansionForCryptographyWork", ThisObject);
		QuestionText = NStr("en='For working with EP
		|it is required to install the work extension with cryptography.';ru='Для работы с ЭП необходимо установить
		|расширение работы с криптографией.'");
		DigitalSignatureClient.SetExtension(False, Handler, QuestionText);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseEDExchange") Then
		MessageText = ElectronicDocumentsServiceCallServer.MessageTextAboutSystemSettingRequirement("WorkWithED");
		CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
	EndIf;
	
	If Not ElectronicDocumentsServiceCallServer.GetFunctionalOptionValue("UseDigitalSignatures") Then
		MessageText = ElectronicDocumentsServiceCallServer.MessageTextAboutSystemSettingRequirement("SigningOfED");
		CommonUseClientServer.MessageToUser(MessageText, , , , Cancel);
	EndIf;
	
	Items.APMPages.PagesRepresentation = FormPagesRepresentation.None;
	
	EDActualKinds = ElectronicDocumentsReUse.GetEDActualKinds();
	SubstractionArray = New Array;
	SubstractionArray.Add(Enums.EDKinds.QueryStatement);
	SubstractionArray.Add(Enums.EDKinds.BankStatement);
	CommonUseClientServer.ReduceArray(EDActualKinds, SubstractionArray);
	Items.EDKind.ChoiceList.LoadValues(EDActualKinds);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshStateED" Then
		RefillTables();
	EndIf;
	
EndProcedure

#EndRegion

#Region AsynchronousDialogsHandlers

&AtClient
Procedure SignSendNotification(Result, AdditionalParameters) Export
	
	ProfilesAndCertificatesParametersMatch = Result.ProfilesAndCertificatesParametersMatch;
	
	DigitallySignedCnt = AdditionalParameters.DigitallySignedCnt;
	EDKindsArray = AdditionalParameters.EDKindsArray;
	
	NotifyDescription = New NotifyDescription("AfterSendingEDP", ThisObject, DigitallySignedCnt);
	ElectronicDocumentsServiceClient.PrepareAndSendPED(EDKindsArray, False, ProfilesAndCertificatesParametersMatch, ,
		NotifyDescription);
	
EndProcedure

&AtClient
Procedure AfterSendingEDP(Result, AdditionalParameters) Export
	
	DigitallySignedCnt = 0;
	PreparedCnt = 0;
	SentCnt = 0;
	If TypeOf(Result) = Type("Structure") Then
		If Not(Result.Property("PreparedCnt", PreparedCnt)
				AND TypeOf(PreparedCnt) = Type("Number")) Then
			//
			PreparedCnt = 0;
		EndIf;
		If Not(Result.Property("SentCnt", SentCnt)
				AND TypeOf(SentCnt) = Type("Number")) Then
			//
			SentCnt = 0;
		EndIf;
	EndIf;
	If TypeOf(AdditionalParameters) = Type("Number") Then
		DigitallySignedCnt = AdditionalParameters;
	EndIf;
	
	NotifyUser(DigitallySignedCnt, PreparedCnt, SentCnt);
	
EndProcedure

#EndRegion













