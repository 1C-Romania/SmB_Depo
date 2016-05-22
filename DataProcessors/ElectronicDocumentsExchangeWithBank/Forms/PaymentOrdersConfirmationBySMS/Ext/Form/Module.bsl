#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	ElectronicDocument = Parameters.ElectronicDocument;
	
	AdditInformationAboutED = ElectronicDocumentsService.GetFileData(ElectronicDocument);
	If Not (AdditInformationAboutED.Property("FileBinaryDataRef")
				AND ValueIsFilled(AdditInformationAboutED.FileBinaryDataRef)) Then
			
		Cancel = True;
		Return;
	EndIf;
		
	EDData = GetFromTempStorage(AdditInformationAboutED.FileBinaryDataRef);

	FileName = GetTempFileName("xml");
			
	If FileName = Undefined Then
		ErrorText = NStr("en = 'Failed to read electronic document. Verify the work directory setting'");
		CommonUseClientServer.MessageToUser(ErrorText);
		Cancel = True;
		Return;
	EndIf;
	
	EDData.Write(FileName);
	
	DataStructure = ElectronicDocumentsInternal.GenerateParseTree(
									FileName, ElectronicDocument.EDDirection);
	DeleteFiles(FileName);
	If DataStructure = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	AmountAsNumber = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
						DataStructure.ParseTree, DataStructure.ObjectString, "Amount");
	Amount = Format(AmountAsNumber, "NFD=2") + " rub.";
	Recipient = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
					DataStructure.ParseTree, DataStructure.ObjectString, "RecipientDescription");
	BIN = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
					DataStructure.ParseTree, DataStructure.ObjectString, "PayeeBankBIC");
	AccountNo = ElectronicDocumentsInternal.GetParsedTreeStringAttributeValue(
					DataStructure.ParseTree, DataStructure.ObjectString, "PayeeBankAcc");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	SessionID = Parameters.Session.ID;
	
	If Parameters.BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
		AttachableModule = ElectronicDocumentsServiceClient.ExternalConnectedModuleThroughAdditionalDataProcessor(Parameters.EDAgreement);
	Else
		ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
		AttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
			ExchangeWithBanksSubsystemsParameters.Get(ElectronicDocumentsServiceClient.iBankName2ComponentName()), Undefined);
	EndIf;
	
	Try
		If Parameters.BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
			AttachableModule.SendConfirmationCodeBySMS(Parameters.Certificate, Parameters.Session);
		Else
			XMLSession = ElectronicDocumentsServiceClient.SerializedData(Parameters.Session);
			AttachableModule.SendConfirmationCodeBySMS(XMLSession);
		EndIf;
	Except
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ErrorTemplate = NStr("en = 'Error when sending confirmation code of payment order.
									|Error code:
									|%1 %2'");
		If Parameters.BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
			ErrorDetails = AttachableModule.ErrorDetails();
		Else
			ErrorDetails = ElectronicDocumentsServiceClient.InformationAboutErroriBank2();
		EndIf;
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en = 'Sending confirmation code of payment order'");
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
							Operation, DetailErrorDescription, MessageText, 1);
		Cancel = True;
	EndTry;

EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ElectronicDocumentFileOwnerClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure;
	FormParameters.Insert("ElectronicDocument", ElectronicDocument);
	OpenForm("DataProcessor.ElectronicDocuments.Form.EDViewImportForm", FormParameters, ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandConfirm(Command)

	If IsBlankString(Password) Then
		MessageText = NStr("en = 'Enter confirmation code to continue.'");
		CommonUseClientServer.MessageToUser(MessageText, , "Password");
		Return;
	EndIf;

	Close(Password);

EndProcedure

#EndRegion
