////////////////////////////////////////////////////////////////////////////////
// Subsystem "Sending SMS"
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Sends SMS via configured service provider, returns message identifier.
//
// Parameters:
//  RecipientNumbers     - Array   - an array of number strings of the recipients in the format +7XXXXXXXXXX;
//  Text                - String  - message text, the maximum length can be different depending on the operator;
//  SenderName          - String  - the sender name that will be shown instead of numbers for recipients.
//  TranslateToTranslit - Boolean - True if it is required to transliterate the message text before sending.
//
// Returns:
//  Structure:
//    * SentMessages - Array - structure array:
//      ** RecipientNumber - String.
//      ** MessageID - String.
//    * ErrorDescription - String - user's view of an error,
//                                  if the row is empty, then there is no error.
Function SendSMS(RecipientNumbers, Val Text, SenderName = "", TranslateToTranslit = False) Export
	
	Result = New Structure("SentMessages,ErrorDescription", New Array, "");
	
	If TranslateToTranslit Then
		Text = StringFunctionsClientServer.StringInLatin(Text);
	EndIf;
	
	If Not SMSSendSettingFinished() Then
		Result.ErrorDescription = NStr("en='Incorrect settings of the provider for SMS sending.';ru='Неверно заданы настройки провайдера для отправки SMS.'");
		Return Result;
	EndIf;
	
	SendingSMSSettings = SendingSMSSettings();
	
	If SendingSMSSettings.Provider = Enums.SMSProviders.MTS Then // MTS
		Result = SendingSMSByMTS.SendSMS(RecipientNumbers, Text, SenderName,
			SendingSMSSettings.Login, SendingSMSSettings.Password);
	ElsIf SendingSMSSettings.Provider = Enums.SMSProviders.Beeline Then // Beeline
		Result = SendingSMSByBeeline.SendSMS(RecipientNumbers, Text, SenderName,
			SendingSMSSettings.Login, SendingSMSSettings.Password);
	ElsIf ValueIsFilled(SendingSMSSettings.Provider) Then // Another
		SendingParameters = New Structure;
		SendingParameters.Insert("RecipientNumbers", RecipientNumbers);
		SendingParameters.Insert("Text", Text);
		SendingParameters.Insert("SenderName", SenderName);
		SendingParameters.Insert("Login", SendingSMSSettings.Login);
		SendingParameters.Insert("Password", SendingSMSSettings.Password);
		SendingParameters.Insert("Provider", SendingSMSSettings.Provider);
		
		SendingSMSOverridable.SendSMS(SendingParameters, Result);
	EndIf;
	
	Return Result;
	
EndFunction

// Requests message delivery status from service supplier.
//
// Parameters:
//  MessageID - String - the ID assigned when sending SMS;
//
// Returns:
//  String - message delivery status which was returned by service provider:
//           "DidNotSend"   - message wasn't processed yet by service provider (in queue);
//           "BeingSent"    - message stands in a queue on sending at provider;
//           "Sent"         - message is sent, confirmation on delivery is expected;
//           "NotSent"      - message is not sent (account is locked, operator's network is overloaded);
//           "Delivered"    - message is delivered to the addressee;
//           "NotDelivered" - failed to deliver the message (subscriber is
//                              not available, delivery confirmation from the subscriber waiting time expired);
//           "Error"        - failed to receive the status from service provider (status is unknown).
//
Function DeliveryStatus(MessageID) Export
	
	If IsBlankString(MessageID) Then
		Return "HaveNotSent";
	EndIf;
	
	Result = Undefined;
	SendingSMSSettings = SendingSMSSettings();
	
	If SendingSMSSettings.Provider = Enums.SMSProviders.MTS Then
		Result = SendingSMSByMTS.DeliveryStatus(MessageID,
												  SendingSMSSettings.Login,
												  SendingSMSSettings.Password);
	ElsIf SendingSMSSettings.Provider = Enums.SMSProviders.Beeline Then
		Result = SendingSMSByBeeline.DeliveryStatus(MessageID,
													 SendingSMSSettings.Login,
													 SendingSMSSettings.Password);
	ElsIf ValueIsFilled(SendingSMSSettings.Provider) Then
		SendingSMSOverridable.DeliveryStatus(MessageID, SendingSMSSettings.Provider,
			SendingSMSSettings.Login, SendingSMSSettings.Password, Result);
	Else // provider isn't selected
		Result = "Error";
	EndIf;
	
	Return Result;
	
EndFunction

// Checks the correctness of saved settings of SMS sending.
Function SMSSendSettingFinished() Export
	
	Result = True;
	
	SendingSMSSettings = SendingSMSSettings();
	Provider = SendingSMSSettings.Provider;
	If Provider = Enums.SMSProviders.MTS Or Provider = Enums.SMSProviders.Beeline Then
		Result = Not IsBlankString(SendingSMSSettings.Login) AND Not IsBlankString(SendingSMSSettings.Password);
	ElsIf ValueIsFilled(SendingSMSSettings.Provider) Then
		Cancel = False;
		SendingSMSOverridable.WhenTestingSendSMSSettings(SendingSMSSettings, Cancel);
		Result = Not Cancel;
	Else
		Result = False;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["StandardSubsystems.BasicFunctionality\WhenFillingOutPermitsForAccessToExternalResources"].Add(
		"SendingSMS");
		
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Fills out a list of queries for external permissions
// that must be provided when creating an infobase or updating a application.
//
// Parameters:
//  PermissionsQueries - Array - list of values returned by the function.
//                      WorkInSafeMode.QueryOnExternalResourcesUse().
//
Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	PermissionsQueries.Add(
		WorkInSafeMode.QueryOnExternalResourcesUse(SendingSMSByBeeline.permissions()));
	
	PermissionsQueries.Add(
		WorkInSafeMode.QueryOnExternalResourcesUse(SendingSMSByMTS.permissions()));
	
	PermissionsQueries.Add(
		WorkInSafeMode.QueryOnExternalResourcesUse(AdditionalPermissions()));
	
EndProcedure

Function AdditionalPermissions()
	permissions = New Array;
	SendingSMSOverridable.OnReceiptPermissions(permissions);
	
	Return permissions;
EndFunction

Function SendingSMSSettings()
	Result = New Structure;
	Result.Insert("Login", Constants.LoginForSendingSMS.Get());
	Result.Insert("Password", Constants.PasswordForSendingSMS.Get());
	Result.Insert("Provider", Constants.SMSProvider.Get());
	
	Return Result;
EndFunction

#EndRegion
