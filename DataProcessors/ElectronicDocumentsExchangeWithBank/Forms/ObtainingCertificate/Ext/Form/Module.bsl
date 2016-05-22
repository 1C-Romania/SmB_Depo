&AtClient
Var KeysAndCertificatesCorrespondence;

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	StorageIdentifier = Parameters.StorageIdentifier;
	If Not ValueIsFilled(StorageIdentifier) Then
		Cancel = True;
	EndIf;
	
	BankApplication = CommonUse.ObjectAttributeValue(Parameters.EDAgreement, "BankApplication");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
		ExternalAttachableModule = ElectronicDocumentsServiceClient.ExternalConnectedModuleThroughAdditionalDataProcessor(Parameters.EDAgreement);
	Else
		ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
		ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
			ExchangeWithBanksSubsystemsParameters.Get(ElectronicDocumentsServiceClient.iBankName2ComponentName()), Undefined);
	EndIf;

	Try
		CertificatesOnDevice = ExternalAttachableModule.CertificatesInStorage(StorageIdentifier);
		If BankApplication = PredefinedValue("Enum.BankApplications.iBank2") Then
			CertificatesOnDevice = ElectronicDocumentsServiceClient.DeSerializedData(CertificatesOnDevice);
		EndIf
	Except
		ErrorTemplate = NStr("en = 'Bank certificates receiving error.
									|Error code:
									|%1 %2'");
		If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
			ErrorDetails = ExternalAttachableModule.ErrorDetails();
		Else
			ErrorDetails = ElectronicDocumentsServiceClient.InformationAboutErroriBank2();
		EndIf;
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en = 'Receiving bank certificates'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
			Operation, DetailErrorDescription, MessageText, 1);
		Cancel = True;
		Return;
	EndTry;
	
	If CertificatesOnDevice.Count() = 0 Then
		MessageText = NStr("en = 'Certificates are not found in the storage.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Cancel = True;
		Return;
	EndIf;
	
	KeysAndCertificatesCorrespondence = New Map;
	
	If CertificatesOnDevice.Count() = 1 Then
		
		If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
			CertificateData = ElectronicDocumentsServiceClient.CertificateDataThroughAdditionalDataProcessor(
												ExternalAttachableModule, CertificatesOnDevice[0]);
		Else
			CertificateData = ElectronicDocumentsServiceClient.iBank2CertificateData(
																CertificatesOnDevice[0]);
		EndIf;
		If CertificateData = Undefined Then
			Close();
			Return;
		EndIf;
		Key = CertificateData.Alias;
		KeysAndCertificatesCorrespondence.Insert(Key, CertificatesOnDevice[0]);
		Items.Key.ReadOnly = True;
		CurrentItem = Items.Password;
	Else
		For Each XMLCertificate IN CertificatesOnDevice Do
			Error = False;
			If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
				CertificateData = ElectronicDocumentsServiceClient.CertificateDataThroughAdditionalDataProcessor(
																	ExternalAttachableModule, XMLCertificate);
			Else
				CertificateData = ElectronicDocumentsServiceClient.iBank2CertificateData(XMLCertificate);
			EndIf;
			If CertificateData = Undefined Then
				Continue;
			EndIf;
			Items.Key.ChoiceList.Add(CertificateData.Alias);
			KeysAndCertificatesCorrespondence.Insert(CertificateData.Alias, XMLCertificate);
		EndDo;
		Items.Key.ChoiceList.SortByValue();
		If Items.Key.ChoiceList.Count() = 0 Then
			Cancel = True;
			Return;
		EndIf;
		CurrentItem = Items.Key;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Done(Command)
	
	If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
		ExternalAttachableModule = ElectronicDocumentsServiceClient.ExternalConnectedModuleThroughAdditionalDataProcessor(Parameters.EDAgreement);
		If ExternalAttachableModule = Undefined Then
			Return;
		EndIf;
	EndIf;
	
	XMLCertificate = KeysAndCertificatesCorrespondence.Get(Key);
	
	If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
		PasswordIsSet = ElectronicDocumentsServiceClient.SetCertificatePasswordThroughAdditionalDataProcessor(
																		ExternalAttachableModule, XMLCertificate, Password);
	Else
		PasswordIsSet = ElectronicDocumentsServiceClient.SetiBank2CertificatePassword(XMLCertificate, Password);
	EndIf;
	
	If Not PasswordIsSet Then
		Return;
	EndIf;
	
	CertificateReceivingParameters = New Structure;
	
	CertificateReceivingParameters.Insert("ProcedureName", "ContinueReceivingCertificate");
	CertificateReceivingParameters.Insert("ExternalAttachableModule", ExternalAttachableModule);
	CertificateReceivingParameters.Insert("Module", ThisObject);
	CertificateReceivingParameters.Insert("XMLCertificate", XMLCertificate);
	
	ConnectionEstablished = False;
	If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
		ElectronicDocumentsServiceClient.EstablishConnectionThroughAdditionalDataProcessor(Parameters.EDAgreement,
			ExternalAttachableModule, XMLCertificate, CertificateReceivingParameters, ConnectionEstablished);
	Else
		ElectronicDocumentsServiceClient.EstablishConnectioniBank2(Parameters.EDAgreement, XMLCertificate,
														CertificateReceivingParameters, ConnectionEstablished);
	EndIf;
	
	If Not ConnectionEstablished Then
		Return;
	EndIf;
	
	ContinueReceivingCertificate(ConnectionEstablished, CertificateReceivingParameters)
		
EndProcedure

&AtClient
Procedure ContinueReceivingCertificate(Authentication, Parameters) Export
	
	If Not Authentication = True Then
		Return;
	EndIf;
	
	XMLCertificate = Parameters.XMLCertificate;
	If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
		ExternalAttachableModule = Parameters.ExternalAttachableModule;
	Else
		ExchangeWithBanksSubsystemsParameters = ApplicationParameters["ExchangeWithBanks.Parameters"];
		ExternalAttachableModule = ?(TypeOf(ExchangeWithBanksSubsystemsParameters) = Type("Map"),
			ExchangeWithBanksSubsystemsParameters.Get(ElectronicDocumentsServiceClient.iBankName2ComponentName()), Undefined);
	EndIf;
	
	Try
		XMLCertificate = ExternalAttachableModule.ComplementCertificate(XMLCertificate);
	Except
		ErrorTemplate = NStr("en = 'Certificate data addition error.
								|Error code:
								|%1 %2'");
		If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
			ErrorDetails = ExternalAttachableModule.ErrorDetails();
		Else
			ErrorDetails = ElectronicDocumentsServiceClient.InformationAboutErroriBank2();
		EndIf;
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
							ErrorTemplate, ErrorDetails.Code, ErrorDetails.Message);
		Operation = NStr("en = 'Receiving additional certificate data'");
		DetailErrorDescription = DetailErrorDescription(ErrorInfo());
		ElectronicDocumentsServiceCallServer.ProcessExceptionByEDOnServer(
							Operation, DetailErrorDescription, MessageText, 1);
		Return;
	EndTry;
	
	NotifyChoice(XMLCertificate);
	
EndProcedure
