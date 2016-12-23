&AtClient
Var ClientParameters Export;

&AtClient
Var DataDescription, ObjectForm, CurrentPresentationsList;

&AtClient
Var DataDisplayUpdated;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If ValueIsFilled(Parameters.DataTitle) Then
		Items.DataPresentation.Title = Parameters.DataTitle;
	Else
		Items.DataPresentation.TitleLocation = FormItemTitleLocation.None;
	EndIf;
	
	DataPresentation = Parameters.DataPresentation;
	Items.DataPresentation.Hyperlink = Parameters.DataPresentationOpens;
	
	If Not ValueIsFilled(DataPresentation) Then
		Items.DataPresentation.Visible = False;
	EndIf;
	
	If Not Parameters.ShowComment Then
		Items.Signatures.Header = False;
		Items.SignatureComment.Visible = False;
	EndIf;
	
	CryptoManagerAtServerErrorDescription = New Structure;
	CommonSettings = DigitalSignatureClientServer.CommonSettings();
	
	If CommonSettings.VerifyDigitalSignaturesAtServer
	 Or CommonSettings.CreateDigitalSignaturesAtServer Then
		
		DigitalSignatureService.CryptoManager("",
			False, CryptoManagerAtServerErrorDescription);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ClientParameters = Undefined Then
		Cancel = True;
	Else
		DataDescription             = ClientParameters.DataDescription;
		ObjectForm               = ClientParameters.Form;
		CurrentPresentationsList = ClientParameters.CurrentPresentationsList;
		AttachIdleHandler("AfterOpening", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DataPresentationClick(Item, StandardProcessing)
	
	DigitalSignatureServiceClient.DataPresentationClick(ThisObject,
		Item, StandardProcessing, CurrentPresentationsList);
	
EndProcedure

#EndRegion

#Region SignatureFormTableEventsHandlers

&AtClient
Procedure SignaturesBeforeAdding(Item, Cancel, Copy, Parent, Group, Parameter)
	
	Cancel = True;
	
	If DataDisplayUpdated = True Then
		SelectFile(True);
	EndIf;
	
EndProcedure

&AtClient
Procedure SignaturesFilePathStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectFile();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	If Signatures.Count() = 0 Then
		ShowMessageBox(, NStr("en='No signature file is selected';ru='Не выбрано ни одного файла подписи'"));
		Return;
	EndIf;
	
	If Not DataDescription.Property("Object") Then
		DataDescription.Insert("Signatures", SignaturesArray());
		Close(True);
		Return;
	EndIf;
	
	If TypeOf(DataDescription.Object) <> Type("NotifyDescription") Then
		FormID = Undefined;
		If TypeOf(ObjectForm) = Type("ManagedForm") Then
			FormID = ObjectForm.UUID;
		ElsIf TypeOf(ObjectForm) = Type("UUID") Then
			FormID = ObjectForm;
		EndIf;
		ObjectVersioning = Undefined;
		DataDescription.Property("ObjectVersioning", ObjectVersioning);
		SignaturesArray = Undefined;
		AddSignature(DataDescription.Object, ObjectVersioning, SignaturesArray);
		DataDescription.Insert("Signatures", SignaturesArray);
		NotifyChanged(DataDescription.Object);
	EndIf;
	
	DataDescription.Insert("Signatures", SignaturesArray());
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("DataDescription", DataDescription);
	ExecuteParameters.Insert("Notification", New NotifyDescription("OKEnd", ThisObject));
	
	Try
		ExecuteNotifyProcessing(DataDescription.Object, ExecuteParameters);
	Except
		ErrorInfo = ErrorInfo();
		OKEnd(New Structure("ErrorDescription", BriefErrorDescription(ErrorInfo)), );
	EndTry;
	
EndProcedure

// Continue the procedure OK.
&AtClient
Procedure OKEnd(Result, Context) Export
	
	If Result.Property("ErrorDescription") Then
		DataDescription.Delete("Signatures");
		
		Error = New Structure("ErrorDescription",
			NStr("en='An error occurred writing a signature:';ru='При записи подписи возникла ошибка:'") + Chars.LF + Result.ErrorDescription);
		
		DigitalSignatureServiceClient.ShowRequestToApplicationError(
			NStr("en='Unable to add digital signature from file';ru='Не удалось добавить электронную подпись из файла'"), "", Error, New Structure);
		Return;
	EndIf;
	
	If ValueIsFilled(DataPresentation) Then
		DigitalSignatureClient.InformAboutSigningAnObject(
			DigitalSignatureServiceClient.FullDataPresentation(ThisObject),, True);
	EndIf;
	
	Close(True);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure AfterOpening()
	
	DataDisplayUpdated = True;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SignatureFilePath.Name);
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Signatures.PathToFile");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	Item.Appearance.SetParameterValue("MarkIncomplete", True);
	
EndProcedure

&AtClient
Procedure SelectFile(AddNewRow = False)
	
	Context = New Structure;
	Context.Insert("AddNewRow", AddNewRow);
	
	BeginAttachingFileSystemExtension(New NotifyDescription(
		"SelectFileAfterConnectionFileOperationsExtension", ThisObject, Context));
	
EndProcedure

// Continue the SelectFile procedure.
&AtClient
Procedure SelectFileAfterConnectionFileOperationsExtension(Attached, Context) Export
	
	If Not Attached Then
		ContinuationProcessor = New NotifyDescription(
			"SelectFileOnFilePostBegin", ThisObject, Context);
		
		BeginPutFile(ContinuationProcessor, , , , UUID);
		Return;
	EndIf;
	
	Dialog = New FileDialog(FileDialogMode.Open);
	Dialog.Multiselect = False;
	Dialog.Title = NStr("en='Select digital signature file';ru='Выберите файл электронной подписи'");
	Dialog.Filter = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Signature files (*.%1)|*.%1|All files(*.*)|*.*';ru='Файлы подписи (*.%1)|*.%1|Все файлы(*.*)|*.*'"),
		DigitalSignatureClientServer.PersonalSettings().ExtensionForSignatureFiles);
	
	If Not Context.AddNewRow Then
		Dialog.FullFileName = Items.Signatures.CurrentData.PathToFile;
	EndIf;
	
	BeginPuttingFiles(New NotifyDescription(
		"SelectFileAfterFilesPost", ThisObject, Context), , Dialog, False, UUID);
	
EndProcedure

// Continue the SelectFile procedure.
&AtClient
Procedure SelectFileAfterFilesPost(PlacedFiles, Context) Export
	
	If Not ValueIsFilled(PlacedFiles) Then
		Return;
	EndIf;
	
	Context.Insert("Address", PlacedFiles[0].Location);
	
	NameContent = CommonUseClientServer.SplitFullFileName(PlacedFiles[0].Name);
	Context.Insert("FileName", NameContent.Name);
	
	SelectFileAfterFilePost(Context);
	
EndProcedure

// Continue the SelectFile procedure.
&AtClient
Procedure SelectFileOnFilePostBegin(Result, Address, SelectedFileName, Context) Export
	
	If Result <> True Then
		Return;
	EndIf;
	
	Context.Insert("Address", Address);
	Context.Insert("FileName", SelectedFileName);
	
	SelectFileAfterFilePost(Context);
	
EndProcedure

// Continue the SelectFile procedure.
&AtClient
Procedure SelectFileAfterFilePost(Context)
	
	Context.Insert("ErrorOnServer", New Structure);
	Context.Insert("SignatureData",   Undefined);
	
	Success = AddRowAtServer(Context.Address, Context.FileName, Context.AddNewRow,
		Context.ErrorOnServer, Context.SignatureData);
	
	If Success Then
		Return;
	EndIf;
	
	DigitalSignatureServiceClient.CreateCryptoManager(New NotifyDescription(
			"SelectFileAfterCreatingCryptographyManager", ThisObject, Context),
		"", Undefined);
	
EndProcedure

// Continue the SelectFile procedure.
&AtClient
Procedure SelectFileAfterCreatingCryptographyManager(CryptoManager, Context) Export
	
	If TypeOf(CryptoManager) <> Type("CryptoManager") Then
		ShowError(CryptoManager, Context.ErrorOnServer);
		Return;
	EndIf;
	
	CryptoManager.StartGettingCertificatesFromSignature(New NotifyDescription(
		"SelectFileAfterReceivingCertificatesFromSignature", ThisObject, Context,
		"SelectFileAfterObtainingCertificatesFromSignaturesError", ThisObject), Context.SignatureData);
	
EndProcedure

// Continue the SelectFile procedure.
&AtClient
Procedure SelectFileAfterObtainingCertificatesFromSignaturesError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	
	ErrorOnClient = New Structure("ErrorDescription", StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='An error occurred when getting certificates from a signature file: %1';ru='При получении сертификатов из файла подписи произошла ошибка: %1'"),
		BriefErrorDescription(ErrorInfo)));
	
	ShowError(ErrorOnClient, Context.ErrorOnServer);
	
EndProcedure

// Continue the SelectFile procedure.
&AtClient
Procedure SelectFileAfterReceivingCertificatesFromSignature(Certificates, Context) Export
	
	If Certificates.Count() = 0 Then
		ErrorOnClient = New Structure("ErrorDescription",
			NStr("en='File contains no signatures of any certificate';ru='В файле подписи нет ни одного сертификата.'"));
		
		ShowError(ErrorOnClient, Context.ErrorOnServer);
		Return;
	EndIf;
	
	Context.Insert("Certificate", Certificates[0]);
	
	Context.Certificate.BeginUnloading(New NotifyDescription(
		"SelectFileAfterCertificateExport", ThisObject, Context));
	
EndProcedure

// Continue the SelectFile procedure.
&AtClient
Procedure SelectFileAfterCertificateExport(CertificateData, Context) Export
	
	SignatureProperties = SignatureProperties(Context.Certificate,
		CertificateData, Context.SignatureData, Context.FileName);
	
	AddLine(ThisObject, Context.AddNewRow, SignatureProperties, Context.FileName);
	
EndProcedure


&AtServer
Function AddRowAtServer(Address, FileName, AddNewRow, ErrorOnServer, SignatureData)
	
	SignatureData = GetFromTempStorage(Address);
	CommonSettings = DigitalSignatureClientServer.CommonSettings();
	
	If Not CommonSettings.VerifyDigitalSignaturesAtServer
	   AND Not CommonSettings.CreateDigitalSignaturesAtServer Then
		
		Return False;
	EndIf;
	
	CryptoManager = DigitalSignatureService.CryptoManager("", False, ErrorOnServer);
	If CryptoManager = Undefined Then
		Return False;
	EndIf;
	
	Try
		Certificates = CryptoManager.GetCertificatesFromSignature(SignatureData);
	Except
		ErrorInfo = ErrorInfo();
		ErrorOnServer.Insert("ErrorDescription", StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='An error occurred when getting certificates from a signature file: %1';ru='При получении сертификатов из файла подписи произошла ошибка: %1'"),
			BriefErrorDescription(ErrorInfo)));
		Return False;
	EndTry;
	
	If Certificates.Count() = 0 Then
		ErrorOnServer.Insert("ErrorDescription", NStr("en='File contains no signatures of any certificate';ru='В файле подписи нет ни одного сертификата.'"));
		Return False;
	EndIf;
	
	SignatureProperties = SignatureProperties(Certificates[0], Certificates[0].Unload(), SignatureData, FileName);
	
	AddLine(ThisObject, AddNewRow, SignatureProperties, FileName);
	
	Return True;
	
EndFunction

&AtClientAtServerNoContext
Procedure AddLine(Form, AddNewRow, SignatureProperties, FileName)
	
	If AddNewRow Then
		CurrentData = Form.Signatures.Add();
	Else
		CurrentData = Form.Signatures.FindByID(Form.Items.Signatures.CurrentRow);
	EndIf;
	
	CurrentData.PathToFile = FileName;
	CurrentData.SignaturePropertiesAddress = PutToTempStorage(SignatureProperties, Form.UUID);
	
EndProcedure

&AtClientAtServerNoContext
Function SignatureProperties(Certificate, CertificateData, SignatureData, FileName)
	
	CertificateProperties = DigitalSignatureClientServer.FillCertificateStructure(Certificate);
	CertificateProperties.Insert("BinaryData", CertificateData);
	
	SignatureProperties = DigitalSignatureServiceClientServer.SignatureProperties(SignatureData,
		CertificateProperties, "", FileName);
	
	Return SignatureProperties;
	
EndFunction

&AtServer
Function SignaturesArray()
	
	SignaturesArray = New Array;
	
	For Each String IN Signatures Do
		
		SignatureProperties = GetFromTempStorage(String.SignaturePropertiesAddress);
		SignatureProperties.Insert("Comment", String.Comment);
		
		SignaturesArray.Add(PutToTempStorage(SignatureProperties, UUID));
	EndDo;
	
	Return SignaturesArray;
	
EndFunction

&AtServer
Procedure AddSignature(ObjectReference, ObjectVersioning, SignaturesArray)
	
	SignaturesArray = SignaturesArray();
	
	DigitalSignature.AddSignature(ObjectReference,
		SignaturesArray, UUID, ObjectVersioning);
	
EndProcedure

&AtClient
Procedure ShowError(ErrorOnClient, ErrorOnServer)
	
	DigitalSignatureServiceClient.ShowRequestToApplicationError(
		NStr("en='Unable to get signature from file';ru='Не удалось получить подпись из файла'"), "", ErrorOnClient, ErrorOnServer);
	
EndProcedure

#EndRegion














