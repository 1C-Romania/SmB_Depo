
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("ED") Then
		Return;
	EndIf;
	
	Parameters.Property("CurrentComment", Comment);
	
	ObjectsForProcessings = New Array;
	If TypeOf(Parameters.ED) <> Type("Array") Then
		ObjectsForProcessings.Add(Parameters.ED);
	Else
		ObjectsForProcessings = Parameters.ED;
	EndIf;
	StorageAddress = PutToTempStorage(ObjectsForProcessings, UUID);
	
	If ObjectsForProcessings.Count() > 1 Then
		Items.ObjectsForProcessings.Title = NStr("en='List';ru='Списком'");
	EndIf;
	
	If Parameters.Property("Responsible") Then
		User = Parameters.Responsible;
	EndIf;
	If ObjectsForProcessings.Count() = 1 Then
		ElectronicDocument = ObjectsForProcessings[0];
		HyperlinkText = ElectronicDocumentsService.GetEDPresentation(ElectronicDocument);
	Else
		HyperlinkText = NStr("en='Electronic documents (%1)';ru='Электронные документы (%1)'");
		HyperlinkText = StrReplace(HyperlinkText, "%1", ObjectsForProcessings.Count());
	EndIf;
	
	HyperlinkText = CommonUseClientServer.ReplaceProhibitedCharsInFileName(HyperlinkText);
	LabelObjectsForProcessings = HyperlinkText;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref
	|FROM
	|	Catalog.EDAttachedFiles AS EDAttachedFiles
	|		INNER JOIN Catalog.EDFProfileSettings.CompanySignatureCertificates AS EDFProfileSettingsCompanySignatureCertificates
	|			INNER JOIN Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS DigitalSignaturesAndEncryptionKeyCertificates
	|				INNER JOIN Catalog.Users AS Users
	|				ON DigitalSignaturesAndEncryptionKeyCertificates.User = Users.Ref
	|			ON EDFProfileSettingsCompanySignatureCertificates.Certificate = DigitalSignaturesAndEncryptionKeyCertificates.Ref
	|		ON EDAttachedFiles.EDFProfileSettings = EDFProfileSettingsCompanySignatureCertificates.Ref
	|WHERE
	|	EDAttachedFiles.Ref IN(&EDKindsArray)";
	
	Query.SetParameter("EDKindsArray", ObjectsForProcessings);
	QueryResult = Query.Execute();
	CertificatesUsers = QueryResult.Unload().UnloadColumn("Ref");
	
	If ValueIsFilled(CertificatesUsers) Then
		Items.User.ChoiceList.LoadValues(CertificatesUsers);
		Items.User.DropListButton = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FieldsFormEventsHandlers

&AtClient
Procedure ObjectsForProcessingsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	EDKindsArray = GetFromTempStorage(StorageAddress);
	If EDKindsArray.Count() > 1 Then
		EDViewForm = OpenForm("DataProcessor.ElectronicDocuments.Form.ExportedDocumentsListForm",
			New Structure("EDRefsArray", EDKindsArray), ThisForm);
	Else
		ShowValue(, EDKindsArray[0]);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	If Not ValueIsFilled(User) Then
		ClearMessages();
		CommonUseClientServer.MessageToUser(NStr("en='Responsible person is not specified.';ru='Не указан ответственный.'"),, "User");
		Return;
	EndIf;
	TotallyED = 0;
	Result = RedirectED(TotallyED);
	ElectronicDocumentsServiceClient.NotifyUserAboutResponsibleChange(User, TotallyED, Result);
	Notify("RefreshStateED");
	Close(Result > 0);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close(False);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function RedirectED(TotallyED)
	
	EDKindsArray = GetFromTempStorage(StorageAddress);
	TotallyED = EDKindsArray.Count();
	ProcessedEDCount = 0;
	ElectronicDocumentsServiceCallServer.SetResponsibleED(EDKindsArray,
		User, ProcessedEDCount, Comment);
	
	Return ProcessedEDCount;
	
EndFunction

#EndRegion
