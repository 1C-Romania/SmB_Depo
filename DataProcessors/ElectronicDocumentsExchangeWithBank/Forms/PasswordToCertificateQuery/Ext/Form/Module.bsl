
#Region CommonUseProceduresAndFunctions

&AtServer
Procedure SetEnabledVisible()
	
	If Parameters.WriteToIB OR TypeOf(SelectedCertificate) = Type("String") Then
		Items.SelectedCertificate.Enabled = False;
		Items.RememberPasswordDuringSession.Enabled = False;
	EndIf;
	
	If ValueIsFilled(SelectedCertificate) Then
		Items.SelectedCertificate.ReadOnly = True;
	EndIf;
	
	If TableED.Count() > 1 Then
		Items.ObjectsForProcessings.Title = NStr("en='List';ru='Списком'");
	EndIf;
	
	Items.ObjectsForProcessings.Visible = (TableED.Count() > 0);
	
EndProcedure

&AtClient
Function PasswordReturnParameters()
	
	ChoiceResult = New Structure;
	
	ChoiceResult.Insert("SelectedCertificate", SelectedCertificate);
	ChoiceResult.Insert("User",        User);
	ChoiceResult.Insert("UserPassword",  UserPassword);
	ChoiceResult.Insert("Comment",         "");
	
	Return ChoiceResult;
	
EndFunction

&AtClient
Procedure ChoiceProcessingCertificate()
	
	If Not ValueIsFilled(SelectedCertificate) Then
		Return;
	EndIf;
	
	Password = Undefined;
	ForSessionPeriod = False;
	PasswordReceived = ElectronicDocumentsServiceClient.CertificatePasswordReceived(SelectedCertificate,
		Password, ForSessionPeriod);
	UserPassword = Password;
	RememberPasswordDuringSession = ForSessionPeriod;
	Items.RememberPasswordDuringSession.Enabled = ForSessionPeriod OR Not PasswordReceived;
	Items.UserPassword.Enabled = Not PasswordReceived;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandDone(Command)
	
	// The block check on the occupancy certificate of the DS.
	If Items.Pages.CurrentPage = Items.EnterCertificatePassword
		AND Not ValueIsFilled(SelectedCertificate) Then
		MessageText = ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "Signature certificate");
		CommonUseClientServer.MessageToUser(MessageText, , "SelectedCertificate");
		Return;
	ElsIf Items.Pages.CurrentPage = Items.EnterLoginAndPassword AND IsBlankString(User) Then
		MessageText = ElectronicDocumentsClientServer.GetMessageText("Field", "Filling", "User");
		CommonUseClientServer.MessageToUser(MessageText, , "User");
		Return;
	EndIf;
	
	HandlePasswordReceipt();
	
EndProcedure

#EndRegion

#Region FieldsFormEventsHandlers

&AtClient
Procedure SelectedCertificateOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key", SelectedCertificate);
	FormParameters.Insert("ReadOnly", True);
	OpenForm("Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form.ItemForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure SelectedCertificateOnChange(Item)
	
	ChoiceProcessingCertificate();
	RefreshDataRepresentation();
	
EndProcedure

&AtClient
Procedure UserPasswordTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	#If Not WebClient Then
	UserPassword = Text;
	#EndIf
	
EndProcedure

&AtClient
Procedure AuthorizationPasswordTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	#If Not WebClient Then
		UserPassword = Text;
	#EndIf

EndProcedure

&AtClient
Procedure ObjectsForProcessingsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If TableED.Count() > 1 Then
		StructuresArray = New Array;
		For Each DataRow IN TableED Do
			ParametersStructure = New Structure;
			ParametersStructure.Insert("ElectronicDocument",DataRow.ElectronicDocument);
			ParametersStructure.Insert("EDOwner",         DataRow.EDOwner);
			ParametersStructure.Insert("EDDirection",      PredefinedValue("Enum.EDDirections.Outgoing"));
			StructuresArray.Add(ParametersStructure);
		EndDo;
		EDViewForm = OpenForm("DataProcessor.ElectronicDocuments.Form.ExportedDocumentsListForm",
			New Structure("EDStructure", StructuresArray), ThisObject);
		
	ElsIf TypeOf(TableED[0].EDOwner) = Type("DocumentRef.EDPackage") Then
		
		FormParameters = New Structure;
		FormParameters.Insert("Key",          TableED[0].EDOwner);
		FormParameters.Insert("ReadOnly", True);
		OpenForm("Document.EDPackage.Form.DocumentForm", FormParameters);
	ElsIf TypeOf(TableED[0].EDOwner) = Type("DocumentRef.RandomED") Then
		
		// Open an attachment by the standard mechanism
		FileData = ElectronicDocumentsServiceCallServer.GetFileData(TableED[0].ElectronicDocument,
			UUID);
		AttachedFilesClient.OpenFile(FileData, False);
	Else
		FormParameters = New Structure;
		FormParameters.Insert("ElectronicDocument", TableED[0].ElectronicDocument);
		FormParameters.Insert("EDOwner",          TableED[0].EDOwner);
		OpenForm("DataProcessor.ElectronicDocuments.Form.EDViewImportForm", FormParameters, ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure RememberPasswordDuringSessionOnChange(Item)
	
	If Not Items.UserPassword.Enabled Then
		Items.UserPassword.Enabled = Items.RememberPasswordDuringSession.Enabled
			AND Not RememberPasswordDuringSession;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	OperationKind = Parameters.OperationKind;
	
	If OperationKind = NStr("en='Authentication at the bank server';ru='Аутентификация на сервере банка'") Then
		Title = NStr("en='Enter the authentication data';ru='Введите данные аутентификации'");
		Items.Pages.CurrentPage = Items.EnterLoginAndPassword;
		If TypeOf(Parameters.Map) = Type("Map") AND Parameters.Map.Count() > 0 Then
			For Each KeyAndValue IN Parameters.Map Do
				EDAgreement = KeyAndValue.Key;
			EndDo;
		Else
			Return;
		EndIf;
		
		User = CommonUse.ObjectAttributeValue(EDAgreement, "User");
		
	Else
		If TypeOf(Parameters.Map) = Type("Map") AND Parameters.Map.Count() > 0 Then
			StorageAddress = PutToTempStorage(Parameters.Map, UUID);
			For Each KeyAndValue IN Parameters.Map Do
				Items.SelectedCertificate.ChoiceList.Add(KeyAndValue.Key);
			EndDo;
			If Parameters.Map.Count() > 1 Then
				Items.SelectedCertificate.ListChoiceMode = True;
			Else
				SelectedCertificate = Items.SelectedCertificate.ChoiceList[0].Value;
			EndIf;
		Else
			Return;
		EndIf;
	EndIf;
		
	If TypeOf(Parameters.ObjectsForProcessings) = Type("Array") AND Parameters.ObjectsForProcessings.Count() > 0 Then
		If Parameters.ObjectsForProcessings.Count() = 1 Then
			ElectronicDocument = Parameters.ObjectsForProcessings[0];
			TemplateHyperlink = NStr("en='%1 # %2 date %3';ru='%1 № %2 от %3'");
			EDOwner = Undefined;
			If TypeOf(ElectronicDocument) = Type("DocumentRef.EDPackage") Then
				AttributesStructure = CommonUse.ObjectAttributesValues(ElectronicDocument, "Number, Date");
				HyperlinkText = StringFunctionsClientServer.PlaceParametersIntoString(TemplateHyperlink,
					String(TypeOf(ElectronicDocument)),
					AttributesStructure.Number, Format(AttributesStructure.Date, "DLF=D"));
				AttributesStructure.Insert("EDOwner", ElectronicDocument);
				NewRow = TableED.Add();
				NewRow.ElectronicDocument = ElectronicDocument;
				NewRow.EDOwner          = ElectronicDocument;
			ElsIf TypeOf(ElectronicDocument) = Type("CatalogRef.EDAttachedFiles") Then
				AttributesStructure = CommonUse.ObjectAttributesValues(ElectronicDocument,
					"EDKind, SenderDocumentNumber, SenderDocumentDate, Company,
					|FileOwner, FileDescription, BasicUnitName, Extension");
				If TypeOf(AttributesStructure.FileOwner) = Type("CatalogRef.EDUsageAgreements") Then
					If AttributesStructure.EDKind = Enums.EDKinds.ProductsDirectory Then
						TemplateHyperlink = NStr("en='%1 %2 from %3';ru='%1 %2 от %3'");
						HyperlinkText = StringFunctionsClientServer.PlaceParametersIntoString(TemplateHyperlink,
							AttributesStructure.EDKind, AttributesStructure.Company,
							Format(AttributesStructure.SenderDocumentDate, "DLF=D"));
					ElsIf AttributesStructure.EDKind = Enums.EDKinds.QueryStatement Then
						HyperlinkText = String(ElectronicDocument);
					Else
						HyperlinkText = StringFunctionsClientServer.PlaceParametersIntoString(TemplateHyperlink,
							AttributesStructure.EDKind, AttributesStructure.SenderDocumentNumber,
							Format(AttributesStructure.SenderDocumentDate, "DLF=D"));
					EndIf;
				ElsIf AttributesStructure.EDKind = Enums.EDKinds.RandomED Then
					HyperlinkText = ?(ValueIsFilled(AttributesStructure.FileDescription),
						AttributesStructure.FileDescription, AttributesStructure.Description) + "." + AttributesStructure.Extension;
				ElsIf ElectronicDocumentsServiceCallServer.ThisIsServiceDocument(ElectronicDocument) Then
					OperationKind = NStr("en='Service electronic documents signing';ru='Подписание служебных электронных документов'");
					
					TemplateHyperlink = NStr("en='%1';ru='%1'");
					HyperlinkText = StringFunctionsClientServer.PlaceParametersIntoString(TemplateHyperlink,
						AttributesStructure.EDKind);
				Else
					OwnerAttributes = CommonUse.ObjectAttributesValues(AttributesStructure.FileOwner, "Number, Date");
					HyperlinkText = StringFunctionsClientServer.PlaceParametersIntoString(TemplateHyperlink,
						String(TypeOf(AttributesStructure.FileOwner)),
						OwnerAttributes.Number, Format(OwnerAttributes.Date, "DLF=D"));
				EndIf;
				NewRow = TableED.Add();
				NewRow.ElectronicDocument = ElectronicDocument;
				NewRow.EDOwner          = AttributesStructure.FileOwner;
			EndIf;
		Else
			Map = CommonUse.ObjectAttributeValues(Parameters.ObjectsForProcessings, "FileOwner");
			For Each KeyAndValue IN Map Do
				NewRow = TableED.Add();
				NewRow.ElectronicDocument = KeyAndValue.Key;
				NewRow.EDOwner          = KeyAndValue.Value.FileOwner;
			EndDo;
			TemplateHyperlink = NStr("en='Electronic documents (%1)';ru='Электронные документы (%1)'");
			HyperlinkText = StringFunctionsClientServer.PlaceParametersIntoString(TemplateHyperlink,
				Parameters.ObjectsForProcessings.Count());
		EndIf;
		
		HyperlinkText = CommonUseClientServer.ReplaceProhibitedCharsInFileName(HyperlinkText);
		LabelObjectsForProcessings = HyperlinkText;
	EndIf;
	
	WindowOptionsKey = ?(TableED.Count() > 0, "WithObjects", "WithoutObjects");
	SetEnabledVisible();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Items.SelectedCertificate.ChoiceList.Count() = 1 Then
		ChoiceProcessingCertificate();
	EndIf;
	RefreshDataRepresentation();
	
	If ValueIsFilled(User) Then
		CurrentItem = Items.AuthorizationPassword;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure HandlePasswordReceipt()
	
	If Items.Pages.CurrentPage = Items.EnterCertificatePassword Then
		RetainedKey = SelectedCertificate;
		ValueToStore = UserPassword;
	Else
		RetainedKey = EDAgreement;
		DataAuthorization = New Structure("User, UserPassword", User, UserPassword);
		ValueToStore = DataAuthorization;
	EndIf;
	
	If RememberPasswordDuringSession Then
		ElectronicDocumentsServiceClient.AddPasswordToGlobalVariable(RetainedKey, ValueToStore);
	Else
		ElectronicDocumentsServiceClient.DeletePasswordFromGlobalVariable(RetainedKey);
	EndIf;
	
	Close(PasswordReturnParameters());
	
EndProcedure

#EndRegion

#Region AsynchronousProceduresAndFunctions

&AtClient
Procedure SetBlankPasswordDescription(Response, AdditionalParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;

	HandlePasswordReceipt();

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
