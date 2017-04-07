&AtClient
Var InternalData, DataDescription, ObjectForm, ProcessingAfterWarning, CurrentPresentationsList;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If ValueIsFilled(Parameters.CertificatesSet) Then
		SpecifiedCertificatesSet = True;
		FillEncryptionCertificatesFromSet(Parameters.CertificatesSet);
	EndIf;
	
	DigitalSignatureService.ConfigureSigningEncryptionDecryptionForm(ThisObject, True);
	
	If SpecifiedCertificatesSet AND Not Parameters.ChangeSet Then
		Items.Certificate.Visible = False;
		Items.GroupEncryptionCertificates.Title = Items.GroupSpecifiedCertificatesSet.Title;
		Items.EncryptionCertificates.ReadOnly = True;
		Items.EncryptionCertificatesSelect.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) = Upper("Record_DigitalSignaturesAndEncryptionKeyCertificates") Then
		AttachIdleHandler("OnChangeCertificatesList", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DataPresentationClick(Item, StandardProcessing)
	
	DigitalSignatureServiceClient.DataPresentationClick(ThisObject,
		Item, StandardProcessing, CurrentPresentationsList);
	
EndProcedure

&AtClient
Procedure CertificateOnChange(Item)
	
	DigitalSignatureServiceClient.GetCertificatePrintsAtClient(
		New NotifyDescription("CertificateOnChangeEnd", ThisObject));
	
EndProcedure

// Continue the procedure CertificateOnChange.
&AtClient
Procedure CertificateOnChangeEnd(CertificateThumbprintsAtClient, Context) Export
	
	CertificateOnChangeAtServer(CertificateThumbprintsAtClient);
	
EndProcedure

&AtClient
Procedure CertificateStartChoice(Item, ChoiceData, StandardProcessing)
	
	DigitalSignatureClient.CertificateStartChoiceWithConfirmation(Item,
		Certificate, StandardProcessing, True);
	
EndProcedure

&AtClient
Procedure CertificateOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	If ValueIsFilled(Certificate) Then
		DigitalSignatureClient.OpenCertificate(Certificate);
	EndIf;
	
EndProcedure

&AtClient
Procedure CertificateChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	Certificate = ValueSelected;
	
	DigitalSignatureServiceClient.GetCertificatePrintsAtClient(
		New NotifyDescription("CertificateChoiceProcessingEnd", ThisObject));
	
EndProcedure

// Continue the procedure CertificateChoiceProcessing.
&AtClient
Procedure CertificateChoiceProcessingEnd(CertificateThumbprintsAtClient, NotSpecified) Export
	
	CertificateOnChangeAtServer(CertificateThumbprintsAtClient);
	
EndProcedure

&AtClient
Procedure CertificateAutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	DigitalSignatureServiceClient.CertificatePickFromChoiceList(ThisObject, Text, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure CertificateTextEntryEnd(Item, Text, ChoiceData, Parameters, StandardProcessing)
	
	DigitalSignatureServiceClient.CertificatePickFromChoiceList(ThisObject, Text, ChoiceData, StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersEncryptionCertificates

&AtClient
Procedure EncryptionCertificatesChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If TypeOf(ValueSelected) <> Type("Array") Then
		Return;
	EndIf;
	
	For Each Value IN ValueSelected Do
		Filter = New Structure("Certificate", Value);
		Rows = EncryptionCertificates.FindRows(Filter);
		If Rows.Count() > 0 Then
			Continue;
		EndIf;
		EncryptionCertificates.Add().Certificate = Value;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Pick(Command)
	
	OpenForm("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.PickCertificateForEncryption",
		, Items.EncryptionCertificates);
	
EndProcedure

&AtClient
Procedure OpenCertificate(Command)
	
	If Items.EncryptionVariants.CurrentPage = Items.PickFromCatalog Then
		CurrentData = Items.EncryptionCertificates.CurrentData;
	Else
		CurrentData = Items.CertificatesSet.CurrentData;
	EndIf;
	
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	If Items.EncryptionVariants.CurrentPage = Items.PickFromCatalog Then
		DigitalSignatureClient.OpenCertificate(CurrentData.Certificate);
	Else
		DigitalSignatureClient.OpenCertificate(CurrentData.DataAddress);
	EndIf;
	
EndProcedure

&AtClient
Procedure Encrypt(Command)
	
	If Not SpecifiedCertificatesSet
	   AND Not CheckFilling() Then
		
		Return;
	EndIf;
	
	EncryptData(New NotifyDescription("EncryptEnd", ThisObject));
	
EndProcedure

// Continue the procedure Encrypt.
&AtClient
Procedure EncryptEnd(Result, Context) Export
	
	If Result = True Then
		Close(True);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillEncryptionCertificatesFromSet(CertificatesSetDescription)
	
	If CommonUse.IsReference(TypeOf(CertificatesSetDescription)) Then
		Query = New Query;
		Query.SetParameter("Ref", CertificatesSetDescription);
		Query.Text =
		"SELECT
		|	SpeadsheetPartEncryptionCertificates.Certificate AS Certificate
		|FROM
		|	&Table AS SpeadsheetPartEncryptionCertificates
		|WHERE
		|	SpeadsheetPartEncryptionCertificates.Ref = &Refs";
		Query.Text = StrReplace(Query.Text, "&Table",
			Metadata.FindByType(TypeOf(CertificatesSetDescription)).FullName() + ".EncryptionCertificates");
		CertificatesArray = New Array;
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			CertificatesArray.Add(Selection.Certificate.Get());
		EndDo;
	Else
		If TypeOf(CertificatesSetDescription) = TypeOf("String") Then
			CertificatesArray = GetFromTempStorage(CertificatesSetDescription);
		Else
			CertificatesArray = CertificatesSetDescription;
		EndIf;
		AddedCertificates = New Map;
		For Each Certificate IN CertificatesArray Do
			If TypeOf(Certificate) = TypeOf("CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates") Then
				If AddedCertificates.Get(Certificate) = Undefined Then
					AddedCertificates.Insert(Certificate, True);
					EncryptionCertificates.Add().Certificate = Certificate;
				EndIf;
			Else
				EncryptionCertificates.Clear();
				Break;
			EndIf;
		EndDo;
		If EncryptionCertificates.Count() > 0
		 Or CertificatesArray.Count() = 0 Then
			Return;
		EndIf;
	EndIf;
	
	CertificatesTable = New ValueTable;
	CertificatesTable.Columns.Add("Ref");
	CertificatesTable.Columns.Add("Imprint");
	CertificatesTable.Columns.Add("Presentation");
	CertificatesTable.Columns.Add("IssuedToWhom");
	CertificatesTable.Columns.Add("Data");
	
	Refs = New Array;
	Prints = New Array;
	For Each CertificateDescription IN CertificatesArray Do
		NewRow = CertificatesTable.Add();
		If TypeOf(CertificateDescription) = Type("BinaryData") Then
			CryptoCertificate = New CryptoCertificate(CertificateDescription);
			CertificateStructure = DigitalSignatureClientServer.FillCertificateStructure(CryptoCertificate);
			NewRow.Presentation = CertificateStructure.Presentation;
			NewRow.IssuedToWhom     = CertificateStructure.IssuedToWhom;
			NewRow.Imprint     = CertificateStructure.Imprint;
			NewRow.Data        = CertificateDescription;
			Prints.Add(CertificateStructure.Imprint);
		Else
			NewRow.Ref = CertificateDescription;
			Refs.Add(CertificateDescription);
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("Ref", Refs);
	Query.SetParameter("Prints", Prints);
	Query.Text =
	"SELECT
	|	Certificates.Ref AS Ref,
	|	Certificates.Imprint,
	|	Certificates.Description AS Presentation,
	|	Certificates.CertificateData
	|FROM
	|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
	|WHERE
	|	Not(NOT Certificates.Ref IN (&Refs)
	|				AND Not Certificates.Imprint IN (&Prints))";
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Rows = CertificatesTable.FindRows(New Structure("Ref", Selection.Ref));
		For Each String IN Rows Do
			CertificateData = Selection.CertificateData.Get();
			If TypeOf(CertificateData) <> Type("BinaryData") Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='""%1"" certificate data was not found in the catalog';ru='Данные сертификата ""%1"" не найдены в справочнике'"), Selection.Presentation);
			EndIf;
			Try
				CryptoCertificate = New CryptoCertificate(CertificateData);
			Except
				ErrorInfo = ErrorInfo();
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='""% 1"" certificate data in the catalog is
		|not correct by reason of: %2';ru='Данные сертификата ""%1"" в справочнике
		|не корректны по причине: %2'"),
					Selection.Presentation,
					BriefErrorDescription(ErrorInfo));
			EndTry;
			CertificateStructure= DigitalSignatureClientServer.FillCertificateStructure(CryptoCertificate);
			String.Imprint     = Selection.Imprint;
			String.Presentation = Selection.Presentation;
			String.IssuedToWhom     = CertificateStructure.IssuedToWhom;
			String.Data        = CertificateData;
		EndDo;
		Rows = CertificatesTable.FindRows(New Structure("Imprint", Selection.Imprint));
		For Each String IN Rows Do
			String.Ref        = Selection.Ref;
			String.Presentation = Selection.Presentation;
		EndDo;
	EndDo;
	
	// Deletion of duplicates.
	AllPrints = New Map;
	IndexOf = CertificatesTable.Count() - 1;
	While IndexOf >= 0 Do
		String = CertificatesTable[IndexOf];
		If AllPrints.Get(String.Imprint) = Undefined Then
			AllPrints.Insert(String.Imprint, True);
		Else
			CertificatesTable.Delete(IndexOf);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	Filter = New Structure("Ref", Undefined);
	AllCertificatesInCatalog = CertificatesTable.FindRows(Filter).Count() = 0;
	
	If AllCertificatesInCatalog Then
		For Each String IN CertificatesTable Do
			EncryptionCertificates.Add().Certificate = String.Ref;
		EndDo;
	Else
		CertificatesProperties = New Array;
		For Each String IN CertificatesTable Do
			NewRow = CertificatesSet.Add();
			FillPropertyValues(NewRow, String);
			NewRow.DataAddress = PutToTempStorage(String.Data, UUID);
			Properties = New Structure;
			Properties.Insert("Imprint",     String.Imprint);
			Properties.Insert("Presentation", String.IssuedToWhom);
			Properties.Insert("Certificate",    String.Data);
			CertificatesProperties.Add(Properties);
		EndDo;
		
		CertificatesPropertiesAddress = PutToTempStorage(CertificatesProperties, UUID);
		Items.EncryptionVariants.CurrentPage = Items.SpecifiedCertificatesSet;
	EndIf;
	
EndProcedure

&AtClient
Procedure ContinueOpen(Notification, CommonInternalData, ClientParameters) Export
	
	DataDescription             = ClientParameters.DataDescription;
	ObjectForm               = ClientParameters.Form;
	CurrentPresentationsList = ClientParameters.CurrentPresentationsList;
	
	InternalData = CommonInternalData;
	Context = New Structure("Notification", Notification);
	Notification = New NotifyDescription("ContinueOpen", ThisObject);
	
	DigitalSignatureServiceClient.ContinueOpenBeginning(New NotifyDescription(
		"ContinueOpeningAfterStart", ThisObject, Context), ThisObject, ClientParameters, True);
	
EndProcedure

// Continue the procedure ContinueOpening.
&AtClient
Procedure ContinueOpeningAfterStart(Result, Context) Export
	
	If Result <> True Then
		ExecuteNotifyProcessing(Context.Notification);
		Return;
	EndIf;
	
	If WithoutConfirmation Then
		ProcessingAfterWarning = Undefined;
		EncryptData(New NotifyDescription("ContinueOpeningAfterDataEncryption", ThisObject, Context));
		Return;
	EndIf;
	
	Open();
	
	ExecuteNotifyProcessing(Context.Notification);
	
EndProcedure

// Continue the procedure ContinueOpening.
&AtClient
Procedure ContinueOpeningAfterDataEncryption(Result, Context) Export
	
	If Result = True Then
		ExecuteNotifyProcessing(Context.Notification, True);
	Else
		ExecuteNotifyProcessing(Context.Notification);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteEncryption(ClientParameters, CompletionProcessing) Export
	
	DigitalSignatureServiceClient.UpdateFormBeforeUsingAgain(ThisObject, ClientParameters);
	
	DataDescription             = ClientParameters.DataDescription;
	ObjectForm               = ClientParameters.Form;
	CurrentPresentationsList = ClientParameters.CurrentPresentationsList;
	
	ProcessingAfterWarning = CompletionProcessing;
	ContinuationProcessor = New NotifyDescription("ExecuteEncryption", ThisObject);
	
	Context = New Structure("CompletionProcessing", CompletionProcessing);
	EncryptData(New NotifyDescription("PerformEncryptionEnd", ThisObject, Context));
	
EndProcedure

// Continue the procedure ExecuteEncryption.
&AtClient
Procedure PerformEncryptionEnd(Result, Context) Export
	
	If Result = True Then
		ExecuteNotifyProcessing(Context.CompletionProcessing, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangeCertificatesList()
	
	DigitalSignatureServiceClient.GetCertificatePrintsAtClient(
		New NotifyDescription("OnChangeCertificatesListEnd", ThisObject));
	
EndProcedure

// Continue the procedure OnChangeCertificatesList.
&AtClient
Procedure OnChangeCertificatesListEnd(CertificateThumbprintsAtClient, Context) Export
	
	CertificateOnChangeAtServer(CertificateThumbprintsAtClient, True);
	
EndProcedure

&AtServer
Procedure CertificateOnChangeAtServer(CertificateThumbprintsAtClient, CheckLink = False)
	
	If CheckLink
	   AND ValueIsFilled(Certificate)
	   AND CommonUse.ObjectAttributeValue(Certificate, "Ref") <> Certificate Then
		
		Certificate = Undefined;
	EndIf;
	
	DigitalSignatureService.CertificateOnChangeAtServer(ThisObject, CertificateThumbprintsAtClient, True);
	
EndProcedure

&AtClient
Procedure EncryptData(Notification)
	
	Context = New Structure;
	Context.Insert("Notification", Notification);
	Context.Insert("ErrorOnClient", New Structure);
	Context.Insert("ErrorOnServer", New Structure);
	
	If ValueIsFilled(Certificate) Then
		If CertificateValidUntil < CommonUseClient.SessionDate() Then
			Context.ErrorOnClient.Insert("ErrorDescription",
				NStr("en='Selected personal certificate has expired.
		|Select another certificate.';ru='У выбранного личного сертификата истек срок действия.
		|Выберите другой сертификат.'"));
			ShowError(Context.ErrorOnClient, Context.ErrorOnServer);
			ExecuteNotifyProcessing(Context.Notification, False);
			Return;
		EndIf;
		
		If Not ValueIsFilled(CertificateApplication) Then
			Context.ErrorOnClient.Insert("ErrorDescription",
				NStr("en='Selected personal certificate has no indication of the application for closed key.
		|Select another certificate.';ru='У выбранного личного сертификата не указана программа для закрытого ключа.
		|Выберите другой сертификат.'"));
			ShowError(Context.ErrorOnClient, Context.ErrorOnServer);
			ExecuteNotifyProcessing(Context.Notification, False);
			Return;
		EndIf;
	EndIf;
	
	Context.Insert("FormID", UUID);
	If TypeOf(ObjectForm) = Type("ManagedForm") Then
		Context.FormID = ObjectForm.UUID;
	ElsIf TypeOf(ObjectForm) = Type("UUID") Then
		Context.FormID = ObjectForm;
	EndIf;
	
	If CertificatesSet.Count() = 0 Then
		Refs = New Array;
		ExcludePersonalCertificate = False;
		If Items.Certificate.Visible AND ValueIsFilled(Certificate) Then
			Refs.Add(Certificate);
			ExcludePersonalCertificate = True;
		EndIf;
		For Each String IN EncryptionCertificates Do
			If Not ExcludePersonalCertificate Or String.Certificate <> Certificate Then
				Refs.Add(String.Certificate);
			EndIf;
		EndDo;
		DataDescription.Insert("EncryptionCertificates",
			CertificatesProperties(Refs, Context.FormID));
	Else
		DataDescription.Insert("EncryptionCertificates", CertificatesPropertiesAddress);
	EndIf;
	
	ExecuteParameters = New Structure;
	ExecuteParameters.Insert("DataDescription",     DataDescription);
	ExecuteParameters.Insert("Form",              ThisObject);
	ExecuteParameters.Insert("FormID", Context.FormID);
	Context.Insert("ExecuteParameters", ExecuteParameters);
	
	If DigitalSignatureClientServer.CommonSettings().CreateDigitalSignaturesAtServer Then
		If ValueIsFilled(CertificateAtServerErrorDescription) Then
			Result = New Structure("Error", CertificateAtServerErrorDescription);
			CertificateAtServerErrorDescription = New Structure;
			EncryptDataAfterCompletionOnServerSide(Result, Context);
		Else
			// Attempt to encrypt on server.
			DigitalSignatureServiceClient.ExecuteOnSide(New NotifyDescription(
					"EncryptDataAfterCompletionOnServerSide", ThisObject, Context),
				"Encryption", "OnServerSide", Context.ExecuteParameters);
		EndIf;
	Else
		EncryptDataAfterCompletionOnServerSide(Undefined, Context);
	EndIf;
	
EndProcedure

// Continue the procedure EncryptData.
&AtClient
Procedure EncryptDataAfterCompletionOnServerSide(Result, Context) Export
	
	If Result <> Undefined Then
		EncryptDataAfterCompletion(Result);
	EndIf;
	
	If Result <> Undefined AND Not Result.Property("Error") Then
		EncryptDataAfterCompletionOnClientSide(New Structure, Context);
	Else
		If Result <> Undefined Then
			Context.ErrorOnServer = Result.Error;
		EndIf;
		
		// Attempt to sign at client.
		DigitalSignatureServiceClient.ExecuteOnSide(New NotifyDescription(
				"EncryptDataAfterCompletionOnClientSide", ThisObject, Context),
			"Encryption", "OnClientSide", Context.ExecuteParameters);
	EndIf;
	
EndProcedure

// Continue the procedure EncryptData.
&AtClient
Procedure EncryptDataAfterCompletionOnClientSide(Result, Context) Export
	
	EncryptDataAfterCompletion(Result);
	
	If Result.Property("Error") Then
		Context.ErrorOnClient = Result.Error;
		ShowError(Context.ErrorOnClient, Context.ErrorOnServer);
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	If Not WriteEncryptionCertificates(Context.FormID, Context.ErrorOnClient) Then
		ShowError(Context.ErrorOnClient, Context.ErrorOnServer);
		ExecuteNotifyProcessing(Context.Notification, False);
		Return;
	EndIf;
	
	If ValueIsFilled(DataPresentation)
	   AND (NOT DataDescription.Property("NotifyAboutCompletion")
	      Or DataDescription.NotifyAboutCompletion <> False) Then
		
		DigitalSignatureClient.InformAboutObjectEncryption(
			DigitalSignatureServiceClient.FullDataPresentation(ThisObject),
			CurrentPresentationsList.Count() > 1);
	EndIf;
	
	If DataDescription.Property("OperationContext") Then
		DataDescription.OperationContext = ThisObject;
	EndIf;
	
	If NotifyAboutExpiration Then
		FormParameters = New Structure("Certificate", Certificate);
		OpenForm("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.UpcomingExpirationDateNotification",
			FormParameters);
	EndIf;
	
	ExecuteNotifyProcessing(Context.Notification, True);
	
EndProcedure

// Continue the procedure EncryptData.
&AtClient
Procedure EncryptDataAfterCompletion(Result)
	
	If Result.Property("ThereAreProcessedDataItems") Then
		// After start of encryption certificates can
		// not be changed. Otherwise data set will be processed differently.
		Items.Certificate.ReadOnly = True;
		Items.EncryptionCertificates.ReadOnly = True;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CertificatesProperties(Val Refs, Val FormID)
	
	Query = New Query;
	Query.SetParameter("Ref", Refs);
	Query.Text =
	"SELECT
	|	Certificates.Ref AS Ref,
	|	Certificates.Description AS Description,
	|	Certificates.Application,
	|	Certificates.CertificateData
	|FROM
	|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
	|WHERE
	|	Certificates.Ref IN(&Refs)";
	
	Selection = Query.Execute().Select();
	CertificatesProperties = New Array;
	
	While Selection.Next() Do
		
		CertificateData = Selection.CertificateData.Get();
		If TypeOf(CertificateData) <> Type("BinaryData") Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='""%1"" certificate data was not found in the catalog';ru='Данные сертификата ""%1"" не найдены в справочнике'"), Selection.Description);
		EndIf;
		
		Try
			CryptoCertificate = New CryptoCertificate(CertificateData);
		Except
			ErrorInfo = ErrorInfo();
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='""% 1"" certificate data in the catalog is
		|not correct by reason of: %2';ru='Данные сертификата ""%1"" в справочнике
		|не корректны по причине: %2'"),
				Selection.Description,
				BriefErrorDescription(ErrorInfo));
		EndTry;
		CertificateProperties = DigitalSignatureClientServer.FillCertificateStructure(CryptoCertificate);
		
		Properties = New Structure;
		Properties.Insert("Imprint",     CertificateProperties.Imprint);
		Properties.Insert("Presentation", CertificateProperties.IssuedToWhom);
		Properties.Insert("Certificate",    CertificateData);
		
		CertificatesProperties.Add(Properties);
	EndDo;
	
	Return PutToTempStorage(CertificatesProperties, FormID);
	
EndFunction


&AtClient
Function WriteEncryptionCertificates(FormID, Error)
	
	ObjectsDescription = New Array;
	If DataDescription.Property("Data") Then
		AddObjectDescription(ObjectsDescription, DataDescription);
	Else
		For Each DataItem IN DataDescription.DataSet Do
			AddObjectDescription(ObjectsDescription, DataDescription);
		EndDo;
	EndIf;
	
	CertificatesAddress = DataDescription.EncryptionCertificates;
	
	Error = New Structure;
	WriteEncryptionCertificatesAtServer(ObjectsDescription, CertificatesAddress, FormID, Error);
	
	Return Not ValueIsFilled(Error);
	
EndFunction

&AtClient
Procedure AddObjectDescription(ObjectsDescription, DataItem)
	
	If Not DataItem.Property("Object") Then
		Return;
	EndIf;
	
	ObjectVersioning = Undefined;
	DataItem.Property("ObjectVersioning", ObjectVersioning);
	
	ObjectDescription = New Structure;
	ObjectDescription.Insert("Ref", DataItem.Object);
	ObjectDescription.Insert("Version", ObjectVersioning);
	
	ObjectsDescription.Add(ObjectDescription);
	
EndProcedure

&AtServerNoContext
Procedure WriteEncryptionCertificatesAtServer(ObjectsDescription, CertificatesAddress, FormID, Error)
	
	CertificatesProperties = GetFromTempStorage(CertificatesAddress);
	
	BeginTransaction();
	Try
		For Each ObjectDescription IN ObjectsDescription Do
			DigitalSignature.WriteEncryptionCertificates(ObjectDescription.Ref,
				CertificatesProperties, FormID, ObjectDescription.Version);
		EndDo;
		CommitTransaction();
	Except
		ErrorInfo = ErrorInfo();
		RollbackTransaction();
		Error.Insert("ErrorDescription", NStr("en='An error occurred when writing the encryption certificates:';ru='При записи сертификатов шифрования возникла ошибка:'")
			+ Chars.LF + BriefErrorDescription(ErrorInfo));
	EndTry;
	
EndProcedure


&AtClient
Procedure ShowError(ErrorOnClient, ErrorOnServer)
	
	If Not IsOpen() AND ProcessingAfterWarning = Undefined Then
		Open();
	EndIf;
	
	DigitalSignatureServiceClient.ShowRequestToApplicationError(
		NStr("en='Failed to encrypt data';ru='Не удалось зашифровать данные'"), "",
		ErrorOnClient, ErrorOnServer, , ProcessingAfterWarning);
	
EndProcedure

#EndRegion
