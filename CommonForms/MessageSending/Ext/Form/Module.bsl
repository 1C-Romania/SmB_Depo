&AtClient
Var NormalizedPostalAddress;

#Region FormEventsHandlers

// Fills the form fields according to the passed in the form parameters.
//
// Following parameters can be passed to the form:
// UserAccount*  - CatalogRef.EmailAccounts, list - 
//               ref to the account that will be used when sending a message,
//               or the list of accounts (for selection).
// Attachments   - Map - attachments in the email, where
//                 key       - is value
//                 attachment file name - binary data of file.
// Subject       - String - email subject.
// Body          - String - email body.
// Whom          - map/string - recipients of letter, 
//                 if the type is match, then the
//                 key   - String - recipient name
//                 value - String - email address in the addr@server format.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	EmailSubject = Parameters.Subject;
	EmailBody = Parameters.Body;
	ReplyTo = Parameters.ReplyTo;
	
	If TypeOf(Parameters.Attachments) = Type("ValueList") Or TypeOf(Parameters.Attachments) = Type("Array") Then
		For Each Attachment IN Parameters.Attachments Do
			AttachmentDescription = Attachments.Add();
			If TypeOf(Parameters.Attachments) = Type("ValueList") Then
				AttachmentDescription.Presentation = Attachment.Presentation;
				If TypeOf(Attachment.Value) = Type("BinaryData") Then
					AttachmentDescription.AddressInTemporaryStorage = PutToTempStorage(Attachment.Value, UUID);
				Else
					If IsTempStorageURL(Attachment.Value) Then
						AttachmentDescription.AddressInTemporaryStorage = PutToTempStorage(GetFromTempStorage(Attachment.Value), UUID);
					Else
						AttachmentDescription.PathToFile = Attachment.Value;
					EndIf;
				EndIf;
			Else // ValueType(Parameters.Attachments) = "structure array"
				FillPropertyValues(AttachmentDescription, Attachment);
				If Not IsBlankString(AttachmentDescription.AddressInTemporaryStorage) Then
					AttachmentDescription.AddressInTemporaryStorage = PutToTempStorage(
						GetFromTempStorage(AttachmentDescription.AddressInTemporaryStorage), UUID);
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	// Data processor of the complex form parameters (composite type).
	// UserAccount, Whom
	
	If Not ValueIsFilled(Parameters.UserAccount) Then
		// User account is not passed - select the first available.
		AvailableAccounts = EmailOperations.AvailableAccounts(True);
		If AvailableAccounts.Count() = 0 Then
			MessageText = NStr("en = 'Available email accounts are not found, contact your system administrator.'");
			CommonUseClientServer.MessageToUser(MessageText,,,,Cancel);
			Return;
		EndIf;
		
		UserAccount = AvailableAccounts[0].Ref;
		
	ElsIf TypeOf(Parameters.UserAccount) = Type("CatalogRef.EmailAccounts") Then
		UserAccount = Parameters.UserAccount;
		AccountSpecified = True;
	ElsIf TypeOf(Parameters.UserAccount) = Type("ValueList") Then
		AccountsSet = Parameters.UserAccount;
		
		If AccountsSet.Count() = 0 Then
			MessageText = NStr("en = 'Email accounts for sending the message are not specified, contact your system administrator.'");
			CommonUseClientServer.MessageToUser(MessageText,,,, Cancel);
			Return;
		EndIf;
		
		For Each ItemAccount IN AccountsSet Do
			Items.UserAccount.ChoiceList.Add(
										ItemAccount.Value,
										ItemAccount.Presentation);
			If ItemAccount.Value.UseForReceiving Then
				ReplyToByEmailAccounts.Add(ItemAccount.Value,
														GetMailAddressByAccount(ItemAccount.Value));
			EndIf;
		EndDo;
		
		Items.UserAccount.ChoiceList.SortByPresentation();
		UserAccount = AccountsSet[0].Value;
		
		// For the passed accounts list select them from the selection list.
		Items.UserAccount.DropListButton = True;
		
		AccountSpecified = True;
		
		If Items.UserAccount.ChoiceList.Count() <= 1 Then
			Items.UserAccount.Visible = False;
		EndIf;
	EndIf;
	
	If TypeOf(Parameters.Whom) = Type("ValueList") Then
		RecipientEmailAddress = "";
		For Each ItemEmail IN Parameters.Whom Do
			If ValueIsFilled(ItemEmail.Presentation) Then 
				RecipientEmailAddress = RecipientEmailAddress
										+ ItemEmail.Presentation
										+ " <"
										+ ItemEmail.Value
										+ ">; "
			Else
				RecipientEmailAddress = RecipientEmailAddress 
										+ ItemEmail.Value
										+ "; ";
			EndIf;
		EndDo;
	ElsIf TypeOf(Parameters.Whom) = Type("String") Then
		RecipientEmailAddress = Parameters.Whom;
	ElsIf TypeOf(Parameters.Whom) = Type("Array") Then
		For Each StructureRecipient IN Parameters.Whom Do
			ArrayOFAddresses = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(StructureRecipient.Address, ";");
			For Each Address IN ArrayOFAddresses Do
				If IsBlankString(Address) Then 
					Continue;
				EndIf;
				RecipientEmailAddress = RecipientEmailAddress + StructureRecipient.Presentation + " <" + TrimAll(Address) + ">; ";
			EndDo;
		EndDo;
	EndIf;
	
	// Get the list of addresses that the user used previously.
	ReplyToList = CommonUse.CommonSettingsStorageImport(
		"NewLetterEditing", 
		"ReplyToList");
	
	If ReplyToList <> Undefined AND ReplyToList.Count() > 0 Then
		For Each ReplyToItem IN ReplyToList Do
			Items.ReplyTo.ChoiceList.Add(ReplyToItem.Value, ReplyToItem.Presentation);
		EndDo;
		
		Items.ReplyTo.DropListButton = True;
	EndIf;
	
	If ValueIsFilled(ReplyTo) Then
		AutomaticReplyAddressSubstitution = False;
	Else
		If UserAccount.UseForReceiving Then
			// Set mail address by default.
			If ValueIsFilled(UserAccount.UserName) Then 
				ReplyTo = UserAccount.UserName + " <" + UserAccount.EmailAddress + ">";
			Else
				ReplyTo = UserAccount.EmailAddress;
			EndIf;
		EndIf;
		
		AutomaticReplyAddressSubstitution = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ImportAttachmentsFromFiles();
	RefreshAttachmentPresentation();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure UserAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	If AccountSpecified Then
		// If the account was passed as the
		// parameter, do not allow to select another one.
		StandardProcessing = False;
	EndIf;
	
EndProcedure

// Substitutes the reply address if the flag of automatic reply substitution is set.
//
&AtClient
Procedure AccountChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If AutomaticReplyAddressSubstitution Then
		If ReplyToByEmailAccounts.FindByValue(ValueSelected) <> Undefined Then
			ReplyTo = ReplyToByEmailAccounts.FindByValue(ValueSelected).Presentation;
		Else
			ReplyTo = GetMailAddressByAccount(ValueSelected);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region AttachementFormTableItemsEventsHandlers

// Deletes an attachment from the list and
// also calls the update function of the attachments presentation table.
//
&AtClient
Procedure AttachmentsBeforeDelete(Item, Cancel)
	
	AttachmentDescription = Item.CurrentData[Item.CurrentItem.Name];
	
	For Each Attachment IN Attachments Do
		If Attachment.Presentation = AttachmentDescription Then
			Attachments.Delete(Attachment);
		EndIf;
	EndDo;
	
	RefreshAttachmentPresentation();
	
EndProcedure

&AtClient
Procedure AttachmentsBeforeAdd(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	AddFileInAttachments();
	
EndProcedure

&AtClient
Procedure AttachmentsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	OpenAttachment();
	
EndProcedure

&AtClient
Procedure AttachmentsDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure AttachmentsDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) = Type("File") Then
		NotifyDescription = New NotifyDescription("AttachmentsDragAndDropEnd", ThisObject, New Structure("Name", DragParameters.Value.Name));
		BeginPutFile(NOTifyDescription, , DragParameters.Value.FullName, False);
	EndIf;
	
EndProcedure

&AtClient
Procedure ResponseAddressTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	If AutomaticReplyAddressSubstitution Then
		If Not ValueIsFilled(ReplyTo)
		 OR Not ValueIsFilled(Text) Then
			AutomaticReplyAddressSubstitution = False;
		Else
			AddressMap1 = CommonUseClientServer.ParseStringWithPostalAddresses(ReplyTo);
			Try
				AddressMap2 = CommonUseClientServer.ParseStringWithPostalAddresses(Text);
			Except
				ErrorInfo = BriefErrorDescription(ErrorInfo());
				CommonUseClientServer.MessageToUser(ErrorInfo, , "ReplyTo");
				StandardProcessing = False;
				Return;
			EndTry;
				
			If Not EMAILAddressesAreTheSame(AddressMap1, AddressMap2) Then
				AutomaticReplyAddressSubstitution = False;
			EndIf;
		EndIf;
	EndIf;
	
	ReplyTo = GetGivenMailingAddressInFormat(Text);
	
EndProcedure

// Remove the auto substitution flag of the reply address.
//
&AtClient
Procedure ResponseAddressChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AutomaticReplyAddressSubstitution = False;
	
EndProcedure

&AtClient
Procedure ResponseAddressClear(Item, StandardProcessing)

	StandardProcessing = False;
	ActualizeAddressResponseInListStored(ReplyTo, False);
	
	For Each ReplyToItem IN Items.ReplyTo.ChoiceList Do
		If ReplyToItem.Value = ReplyTo
		   AND ReplyToItem.Presentation = ReplyTo Then
			Items.ReplyTo.ChoiceList.Delete(ReplyToItem);
		EndIf;
	EndDo;
	
	ReplyTo = "";
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OpenFile(Command)
	OpenAttachment();
EndProcedure

&AtClient
Procedure SendMail()
	
	ClearMessages();
	
	Try
		NormalizedPostalAddress = CommonUseClientServer.ParseStringWithPostalAddresses(RecipientEmailAddress);
	Except
		CommonUseClientServer.MessageToUser(
				BriefErrorDescription(ErrorInfo()), ,
				RecipientEmailAddress);
		Return;
	EndTry;
	
	If ValueIsFilled(ReplyTo) Then
		Try
			CommonUseClientServer.ParseStringWithPostalAddresses(ReplyTo);
		Except
			CommonUseClientServer.MessageToUser(
					BriefErrorDescription(ErrorInfo()), ,
					"ReplyTo");
			Return;
		EndTry;
	EndIf;
	
	ContinueSendingEmailsWithPassword();
	
EndProcedure

&AtClient
Procedure AttachFileExecute()
	
	AddFileInAttachments();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// FORM AND FORM ITEM EVENT HANDLER SECTION
//

&AtServerNoContext
Function SendE_Mail(Val UserAccount, Val EmailParameters)
	
	Return EmailOperations.SendE_Mail(UserAccount, EmailParameters);
	
EndFunction

&AtServerNoContext
Function GetMailAddressByAccount(Val UserAccount)
	
	Return TrimAll(UserAccount.UserName)
			+ ? (IsBlankString(TrimAll(UserAccount.UserName)),
					UserAccount.EmailAddress,
					" <" + UserAccount.EmailAddress + ">");
	
EndFunction

&AtClient
Procedure OpenAttachment()
	
	SelectedAttachment = SelectedAttachment();
	If SelectedAttachment = Undefined Then
		Return;
	EndIf;
	
	#If WebClient Then
		GetFile(SelectedAttachment.AddressInTemporaryStorage, SelectedAttachment.Presentation, True);
	#Else
		TempFolderName = GetTempFileName();
		CreateDirectory(TempFolderName);
		
		TempFileName = CommonUseClientServer.AddFinalPathSeparator(TempFolderName) + SelectedAttachment.Presentation;
		
		BinaryData = GetFromTempStorage(SelectedAttachment.AddressInTemporaryStorage);
		BinaryData.Write(TempFileName);
		
		File = New File(TempFileName);
		File.SetReadOnly(True);
		If File.Extension = ".mxl" Then
			SpreadsheetDocument = GetSpreadsheetDocumentByBinaryData(SelectedAttachment.AddressInTemporaryStorage);
			OpenParameters = New Structure;
			OpenParameters.Insert("DocumentName", SelectedAttachment.Presentation);
			OpenParameters.Insert("SpreadsheetDocument", SpreadsheetDocument);
			OpenParameters.Insert("PathToFile", TempFileName);
			OpenForm("CommonForm.EditSpreadsheetDocument", OpenParameters, ThisObject);
		Else
			RunApp(TempFileName);
		EndIf;
	#EndIf
	
EndProcedure

&AtClient
Function SelectedAttachment()
	
	Result = Undefined;
	If Items.Attachments.CurrentData <> Undefined Then
		AttachmentDescription = Items.Attachments.CurrentData[Items.Attachments.CurrentItem.Name];
		For Each Attachment IN Attachments Do
			If Attachment.Presentation = AttachmentDescription Then
				Result = Attachment;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function GetSpreadsheetDocumentByBinaryData(Val BinaryData)
	
	If TypeOf(BinaryData) = Type("String") Then
		// Binary data address is passed to the temporary storage.
		BinaryData = GetFromTempStorage(BinaryData);
	EndIf;
	
	FileName = GetTempFileName("mxl");
	BinaryData.Write(FileName);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.Read(FileName);
	
	Try
		DeleteFiles(FileName);
	Except
		WriteLogEvent(NStr("en = 'Tabular document receiving'", CommonUseClientServer.MainLanguageCode()), EventLogLevel.Error, , , 
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return SpreadsheetDocument;
	
EndFunction

&AtClient
Procedure AddFileInAttachments()
	DialogueParameters = New Structure;
	DialogueParameters.Insert("Mode", FileDialogMode.Open);
	DialogueParameters.Insert("Multiselect", True);
	NotifyDescription = New NotifyDescription("AddFileToAttachmentsWhenFilePlace", ThisObject);
	StandardSubsystemsClient.ShowFilePlace(NOTifyDescription, UUID, "", DialogueParameters);
EndProcedure

&AtClient
Procedure AddFileToAttachmentsWhenFilePlace(PlacedFiles, AdditionalParameters) Export
	If PlacedFiles = Undefined Or PlacedFiles.Count() = 0 Then
		Return;
	EndIf;
	AddFilesToList(PlacedFiles);
	RefreshAttachmentPresentation();
EndProcedure

&AtServer
Procedure AddFilesToList(PlacedFiles)
	
	For Each FileDescription IN PlacedFiles Do
		File = New File(FileDescription.Name);
		Attachment = Attachments.Add();
		Attachment.Presentation = File.Name;
		Attachment.AddressInTemporaryStorage = PutToTempStorage(GetFromTempStorage(FileDescription.Location), UUID);
	EndDo;
	
EndProcedure

&AtClient
Procedure RefreshAttachmentPresentation()
	
	AttachmentPresentation.Clear();
	
	IndexOf = 0;
	
	For Each Attachment IN Attachments Do
		If IndexOf = 0 Then
			PresentationRow = AttachmentPresentation.Add();
		EndIf;
		
		PresentationRow["Attachment" + String(IndexOf + 1)] = Attachment.Presentation;
		
		IndexOf = IndexOf + 1;
		If IndexOf = 2 Then 
			IndexOf = 0;
		EndIf;
	EndDo;
	
EndProcedure

// Checks letter sending option and
// if this is possible - generates sending parameters.
//
&AtClient
Function GenerateLetterParameters()
	
	EmailParameters = New Structure;
	
	If ValueIsFilled(NormalizedPostalAddress) Then
		EmailParameters.Insert("Whom", NormalizedPostalAddress);
	EndIf;
	
	If ValueIsFilled(ReplyTo) Then
		EmailParameters.Insert("ReplyTo", ReplyTo);
	EndIf;
	
	If ValueIsFilled(EmailSubject) Then
		EmailParameters.Insert("Subject", EmailSubject);
	EndIf;
	
	If ValueIsFilled(EmailBody) Then
		EmailParameters.Insert("Body", EmailBody);
	EndIf;
	
	EmailParameters.Insert("Attachments", Attachments());
	
	Return EmailParameters;
	
EndFunction

&AtClient
Function Attachments()
	
	Result = New Array;
	For Each Attachment IN Attachments Do
		AttachmentDescription = New Structure;
		AttachmentDescription.Insert("Presentation", Attachment.Presentation);
		AttachmentDescription.Insert("AddressInTemporaryStorage", Attachment.AddressInTemporaryStorage);
		AttachmentDescription.Insert("Encoding", Attachment.Encoding);
		Result.Add(AttachmentDescription);
	EndDo;
	
	Return Result;
	
EndFunction

// Adds reply address to the list of saved values.
//
&AtServerNoContext
Function SaveReplyTo(Val ReplyTo)
	
	ActualizeAddressResponseInListStored(ReplyTo);
	
EndFunction

// Adds reply address to the list of saved values.
//
&AtServerNoContext
Function ActualizeAddressResponseInListStored(Val ReplyTo,
                                                   Val AddAddressToList = True)
	
	// Get the list of addresses that the user used previously.
	ReplyToList = CommonUse.CommonSettingsStorageImport(
		"NewLetterEditing",
		"ReplyToList");
	
	If ReplyToList = Undefined Then
		ReplyToList = New ValueList();
	EndIf;
	
	For Each ItemReplyTo IN ReplyToList Do
		If ItemReplyTo.Value = ReplyTo
		   AND ItemReplyTo.Presentation = ReplyTo Then
			ReplyToList.Delete(ItemReplyTo);
		EndIf;
	EndDo;
	
	If AddAddressToList
	   AND ValueIsFilled(ReplyTo) Then
		ReplyToList.Insert(0, ReplyTo, ReplyTo);
	EndIf;
	
	CommonUse.CommonSettingsStorageSave(
		"NewLetterEditing",
		"ReplyToList",
		ReplyToList);
	
EndFunction

// Compares two email addresses.
// Parameters:
// AddressMap1 - String - the first Email address.
// AddressMap2 - String - the second Email address.
// Return value
// True or False depending on whether the email addresses are the same or not.
//
&AtClient
Function EMAILAddressesAreTheSame(AddressMap1, AddressMap2)
	
	If AddressMap1.Count() <> 1
	 Or AddressMap2.Count() <> 1 Then
		Return False;
	EndIf;
	
	If AddressMap1[0].Presentation = AddressMap2[0].Presentation
	   AND AddressMap1[0].Address         = AddressMap2[0].Address Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

&AtClient
Function GetGivenMailingAddressInFormat(Text)
	
	MailAddress = "";
	
	ArrayOFAddresses = CommonUseClientServer.ParseStringWithPostalAddresses(Text);
	
	For Each ItemAddress IN ArrayOFAddresses Do
		If ValueIsFilled(ItemAddress.Presentation) Then 
			MailAddress = MailAddress + ItemAddress.Presentation
							+ ? (IsBlankString(TrimAll(ItemAddress.Address)), "", " <" + ItemAddress.Address + ">");
		Else
			MailAddress = MailAddress + ItemAddress.Address + "; ";
		EndIf;
	EndDo;
		
	Return MailAddress;
	
EndFunction

&AtClient
Procedure ContinueSendingEmailsWithPassword()
	
	EmailParameters = GenerateLetterParameters();
	
	If EmailParameters = Undefined Then
		CommonUseClientServer.MessageToUser(NStr("en = 'Error of generating parameters of the mail message'"));
		Return;
	EndIf;
	
	SendE_Mail(UserAccount, EmailParameters);
	SaveReplyTo(ReplyTo);
	Status(NStr("en = 'Message is sent successfully'"));
	
	Close();
	
EndProcedure

&AtClient
Procedure AttachmentsDragAndDropEnd(Result, TemporaryStorageAddress, SelectedFileName, AdditionalParameters) Export
	
	Files = New Array;
	PassedFile = New TransferableFileDescription(AdditionalParameters.Name, TemporaryStorageAddress);
	Files.Add(PassedFile);
	AddFilesToList(Files);
	RefreshAttachmentPresentation();
	
EndProcedure

&AtClient
Procedure ImportAttachmentsFromFiles()
	
	For Each Attachment IN Attachments Do
		If Not IsBlankString(Attachment.PathToFile) Then
			BinaryData = New BinaryData(Attachment.PathToFile);
			Attachment.AddressInTemporaryStorage = PutToTempStorage(BinaryData, UUID);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion
