////////////////////////////////////////////////////////////////////////////////
// ElectronicDocumentsClientServer: e-documents exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// Gets a text presentation of the e-document version.
//
// Parameters:
//  RefToOwner - Ref to an IB object which e-document version state it is required to get.
//
Function GetTextOfEDState(RefToOwner, Form = Undefined) Export
	
	Hyperlink = False;
	EDStateText = ElectronicDocumentsServiceCallServer.EDStateText(RefToOwner, Hyperlink);
	
	If Not Form = Undefined Then
		ParametersStructure = New Structure();
		ParametersStructure.Insert("EDStateText", EDStateText);
		ParametersStructure.Insert("OperationKind", "HyperlinkSetting");
		ParametersStructure.Insert("ParameterValue", Hyperlink);
		#If  ThickClientOrdinaryApplication Then
			ElectronicDocumentsOverridable.ChangeFormItemsProperties(Form, ParametersStructure);
		#Else
			ElectronicDocumentsServiceCallServer.ChangeFormItemsProperties(Form, ParametersStructure);
		#EndIf
	EndIf;
	
	Return EDStateText;
	
EndFunction

// Generates a message
// text by filling in parameter values in message templates.
//
// Parameters
//  FieldKind       - String - It can take values:
//                    Field, Column, List 
//  MessageKind     - String - It can take values:
//                    Filling, Correctness 
//  Parameter1      - String - field name 
//  Parameter2      - String - String number 
//  Parameter3      - String - list name 
//  Parameter4      - String - message text of incorrect filling
//
// Returns:
//   String - message text
//
Function GetMessageText(FieldKind = "Field", MessageKind = "Filling",
	Parameter1 = "", Parameter2 = "",	Parameter3 = "", Parameter4 = "") Export

	MessageText = "";

	If Upper(FieldKind) = "Field" Then
		If Upper(MessageKind) = "FillType" Then
			Pattern = NStr("en='Field ""%1"" is not filled.';ru='Поле ""%1"" не заполнено.'");
		ElsIf Upper(MessageKind) = "CORRECTNESS" Then
			Pattern = NStr("en='%1 field is filled in incorrectly.
		|
		|%4';ru='Поле ""%1"" заполнено некорректно.
		|
		|%4'");
		EndIf;
	ElsIf Upper(FieldKind) = "Column" Then
		If Upper(MessageKind) = "FillType" Then
			Pattern = NStr("en='Empty column ""%1"" of row %2 in list ""%3"".';ru='Не заполнена колонка ""%1"" в строке %2 списка ""%3"".'");
		ElsIf Upper(MessageKind) = "CORRECTNESS" Then
			Pattern = NStr("en='Column %1 is filled in incorrectly in %2 row of %3 list.
		|
		|%4';ru='Некорректно заполнена колонка ""%1"" в строке %2 списка ""%3"".
		|
		|%4'");
		EndIf;
	ElsIf Upper(FieldKind) = "LIST" Then
		If Upper(MessageKind) = "FillType" Then
			Pattern = NStr("en='No row is entered in list ""%3"".';ru='Не введено ни одной строки в список ""%3"".'");
		ElsIf Upper(MessageKind) = "CORRECTNESS" Then
			Pattern = NStr("en='List %3 is filled in incorrectly.
		|
		|%4';ru='Некорректно заполнен список ""%3"".
		|
		|%4'");
		EndIf;
	EndIf;

	Return StringFunctionsClientServer.SubstituteParametersInString(Pattern, Parameter1, Parameter2, Parameter3, Parameter4);

EndFunction

// Defines a filter of a dynamic list depending on the compatibility mode availability
//
// Parameters:
//  List    - DynamicList - list for which it is required to detect a filter
//
// Returns:
//   Filter - required filter
//
Function DynamicFilterList(List) Export

	If CommonUseClientServer.IsPlatform83WithOutCompatibilityMode() Then
		Return List.SettingsComposer.Settings.Filter;
	Else
		Return List.Filter;
	EndIf;

EndFunction

// Generates and outputs the message that can be connected to form managing item.
//
//  Parameters
//  MessageTextToUser - String - message type.
//  TargetID - UUID - to which form a message should be associated with
//
Procedure MessageToUser(MessageToUserText, TargetID) Export
	
	Message = New UserMessage;
	Message.Text = MessageToUserText;
	Message.TargetID = TargetID;
	Message.Message();
	
EndProcedure

// Checks whether required attributes of settings of EDF with banks are filled out
//
// Parameters:
//  Object  - CatalogObject.EDUsageAgreements - EDF setting being checked
//
// Returns:
//   Boolean   - True - all required attributes are filled out
//
Function FilledAttributesSettingsEDFWithBanks(Object, IsTest = False) Export
	
	Cancel = False;
	
	StatusUsed = PredefinedValue("Enum.EDAgreementsStatuses.Acts");
	If Not IsTest AND Object.AgreementStatus <> StatusUsed Then
		Return True;
	EndIf;
		
	If IsTest AND Object.AgreementStatus <> StatusUsed Then
		MessageText = NStr("en='This EDF setting is only active for status %1';ru='Данная настройка ЭДО будет активна только в статусе %1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, StatusUsed);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
	If Not ValueIsFilled(Object.Company) Then
		MessageText = GetMessageText("Field", "Filling", "Company");
		CommonUseClientServer.MessageToUser(MessageText, , "Company", "Object", Cancel);
	EndIf;
		
	If Not ValueIsFilled(Object.Counterparty) Then
		MessageText = GetMessageText("Field", "Filling", "Bank");
		CommonUseClientServer.MessageToUser(MessageText, , "Counterparty", "Object", Cancel);
	EndIf;
		
	If (Object.BankApplication = PredefinedValue("Enum.BankApplications.SberbankOnline")
			OR Object.BankApplication = PredefinedValue("Enum.BankApplications.AsynchronousExchange"))
		AND (NOT ValueIsFilled(Object.CompanyID)
			OR Object.CompanyID = "00000000-0000-0000-0000-000000000000") Then
		MessageText = GetMessageText("Field", "Filling", "Company ID");
		CommonUseClientServer.MessageToUser(MessageText, , "CompanyID", "Object", Cancel);
	EndIf;
	
	If Object.BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor")
		AND Not ValueIsFilled(Object.AdditionalInformationProcessor) Then
		MessageText = GetMessageText("Field", "Filling", "Additional data processors");
		CommonUseClientServer.MessageToUser(MessageText, , "AdditionalInformationProcessor", "Object", Cancel);
	EndIf;
	
	If Object.BankApplication = PredefinedValue("Enum.BankApplications.AlphaBankOnline")
		OR Object.BankApplication = PredefinedValue("Enum.BankApplications.AsynchronousExchange") Then
		If Not ValueIsFilled(Object.ServerAddress) Then
			MessageText = GetMessageText("Field", "Filling", "Bank server address");
			CommonUseClientServer.MessageToUser(MessageText, , "ServerAddress", "Object", Cancel);
		EndIf;
		If Object.BankApplication = PredefinedValue("Enum.BankApplications.AlphaBankOnline") Then
			If Not ValueIsFilled(Object.OutgoingDocumentsResource) Then
				MessageText = GetMessageText("Field", "Filling", "Resource for sending");
				CommonUseClientServer.MessageToUser(MessageText, , "OutgoingDocumentsResource", "Object", Cancel);
			EndIf;
			If Not ValueIsFilled(Object.IncomingDocumentsResource) Then
				MessageText = GetMessageText("Field", "Filling", "Resource for receiving");
				CommonUseClientServer.MessageToUser(MessageText, , "IncomingDocumentsResource", "Object", Cancel);
			EndIf;
		EndIf;
	EndIf;
		
	If (Object.BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor")
			OR Object.CryptographyIsUsed) AND Object.CompanySignatureCertificates.Count() = 0 Then
		MessageText = GetMessageText("List", "Filling", , , "ES key certificates");
		CommonUseClientServer.MessageToUser(MessageText, , "CompanySignatureCertificates", "Object", Cancel);
	EndIf;
	
	Return Not Cancel;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROGRAMMING INTERFACE

// Determines whether a particular action from the action list is required.
// 
// Parameters:
//  ActionList - String, list of actions that should be performed with the object 
//  Action - String, a particular action that should be found in the action list
// 
// Returns:
//  Boolean - If an action is found - returns True, otherwise, False
//
Function IsAction(ActionList, Action) Export
	
	If Find(ActionList, Action) > 0 Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with service ED

// The procedure performs actions on service ED (notification of receipt, notification of specification):
// generate, approve, sign, send.
//
// Parameters:
//  EDKindsArray - array - contains refs to ED based on which it
//    is required to generate service ED (e-documents, owners of processed service ED).
//  EDKind - Enum - ED kind to be processed (possible values are Notification of
//    receipt and notification of specification).
//  TextNotifications - String - notification text entered by the user who
//    rejected ED (makes sense only if EDKind = SpecificationNotification).
//  AdditParameters - structure - structure of additional parameters
//
Procedure GenerateSignAndSendServiceED(EDKindsArray,
	EDKind, TextNotifications = "", AdditParameters = Undefined, NotifyDescription = Undefined) Export
	
	GeneratedCnt = 0;
	ConfirmedCnt   = 0;
	DigitallySignedCnt    = 0;
	PreparedCnt = 0;
	SentCnt   = 0;
	// Match structure contains the following matches: agreements and signature certificates, agreements
	// and authorization certificates, certificates and parameter structure of these certificates (the certificate parameter
	// structure contains the following: ref to the certificate, flag "remember certificate password", certificate password, flag "revoked",
	// thumbprint, certificate file, and also if the certificate is used for authorization, it contains either a decrypted marker or an encrypted marker or both).
	ImmediateEDSending = Undefined;
	ServerAuthorizationPerform = Undefined;
	PerformCryptoOperationsAtServer = Undefined;
	ElectronicDocumentsServiceCallServer.VariablesInitialise(PerformCryptoOperationsAtServer,
		ServerAuthorizationPerform, ImmediateEDSending);
	If EDKindsArray.Count() > 0 AND EDKind = PredefinedValue("Enum.EDKinds.NotificationAboutReception") Then
		ElectronicDocumentsServiceCallServer.DeleteNonProcessingEDFromArray(EDKindsArray);
		PerformCryptoOperationsAtServer = ServerAuthorizationPerform;
	EndIf;
	ExecuteAlert = (NOTifyDescription <> Undefined);
	If EDKindsArray.Count() > 0 Then
		ServiceEDArray = ElectronicDocumentsServiceCallServer.GenerateServiceED(EDKindsArray, EDKind, TextNotifications);
		If ValueIsFilled(ServiceEDArray) Then
			StCertificateStructuresArrays = New Structure;
			Actions = "SignSend";
			#If Client Then
				ElectronicDocumentsServiceClient.ProcessED(New Array,
					Actions, AdditParameters, ServiceEDArray, NotifyDescription);
				ExecuteAlert = False;
			#Else
				MapStructure = Undefined;
				AgreementsAndArrayEDStMap = ElectronicDocumentsServiceCallServer.PerformActionsByED(New Array,
					New Array, Actions, AdditParameters, ServiceEDArray, MapStructure);
			#EndIf
		EndIf;
	EndIf;
	If ExecuteAlert AND TypeOf(NOTifyDescription) = Type("NotifyDescription") Then
		#If Client Then
			ExecuteNotifyProcessing(NOTifyDescription);
		#EndIf
	EndIf;
	
EndProcedure



