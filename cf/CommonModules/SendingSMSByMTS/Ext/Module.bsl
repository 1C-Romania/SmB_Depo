////////////////////////////////////////////////////////////////////////////////
// Subsystem "Sending SMS"
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Sends SMS via the MTS web service, returns message identifier.
//
// Parameters:
//  RecipientNumbers  - Array  - recipient numbers in the +7XXXXXXXXXX format (string);
//  Text             - String - message text, no longer than 1000 characters;
//  SenderName 	    - String - name of the sender that will be displayed instead of the incoming SMS number;
//  Login            - String - sms sending service user login;
//  Password         - String - sms sending service user password.
//
// Returns:
//  Structure: SentMessages - Array of structures: SenderNumber.
//                                                  MessageID.
//             ErrorDescription    - String - user presentation of an error,
//                                   if the string is empty, then there is no error.
Function SendSMS(RecipientNumbers, Text, SenderName, Login, Val Password) Export
	Result = New Structure("SentMessages,ErrorDescription", New Array, "");
	
	Password = CalculateStringHashByAlgorythmMD5(Password);
	
	WebService = ConnectWebService();
	
	For Each Item IN RecipientNumbers Do
		RecipientNumber = FormatNumber(Item);
		If Not IsBlankString(RecipientNumber) Then
			Try
				MessageID = WebService.SendMessage(RecipientNumber, Left(Text, 1000), SenderName, Login, Password);
				Result.SentMessages.Add(New Structure("RecipientNumber,MessageID",	
																  "+" +  RecipientNumber, Format(MessageID, "NG=")));
			Except
				WriteLogEvent(
					NStr("en='SMS sending';ru='Отправка SMS'", CommonUseClientServer.MainLanguageCode()),
					EventLogLevel.Error,
					,
					,
					DetailErrorDescription(ErrorInfo()));
				Result.ErrorDescription = Result.ErrorDescription 
										 + StringFunctionsClientServer.SubstituteParametersInString(NStr("en='SMS to the number %1 has not been sent';ru='SMS на номер %1 не отправлено'"), Item)
										 + ": " + BriefErrorDescription(ErrorInfo())
										 + Chars.LF;
			EndTry;
		EndIf;
	EndDo;
	
	Result.ErrorDescription = TrimR(Result.ErrorDescription);
	
	Return Result;
EndFunction

// Returns the text presentation of the message delivery status.
//
// Parameters:
//  MessageID - String - ID assigned when sending the sms;
//  Login     - String - sms sending service user login;
//  Password  - String - sms sending service user password.
//
// Returns:
//  String - Delivery status. See the description of the SendingSMS function.DeliveryStatus.
Function DeliveryStatus(MessageID, Login, Val Password) Export
	Password = CalculateStringHashByAlgorythmMD5(Password);
	WebService = ConnectWebService();
	ArrayOfDeliveryInfo = WebService.GetMessageStatus(MessageID, Login, Password);
	For Each DeliveryInfo IN ArrayOfDeliveryInfo.DeliveryInfo Do
		Return SMSDeliveryStatus(DeliveryInfo.DeliveryStatus);
	EndDo;
	Return "Error";
EndFunction

Function FormatNumber(Number)
	Result = "";
	AllowedChars = "1234567890";
	For Position = 1 To StrLen(Number) Do
		Char = Mid(Number,Position,1);
		If Find(AllowedChars, Char) > 0 Then
			Result = Result + Char;
		EndIf;
	EndDo;
	Return Result;	
EndFunction

Function SMSDeliveryStatus(StatusAsString)
	StatusesCorrespondence = New Map;
	StatusesCorrespondence.Insert("Pending", "HaveNotSent");
	StatusesCorrespondence.Insert("Sending", "Dispatched");
	StatusesCorrespondence.Insert("Sent", "Sent");
	StatusesCorrespondence.Insert("NotSent", "NotSent");
	StatusesCorrespondence.Insert("Delivered", "Delivered");
	StatusesCorrespondence.Insert("NotDelivered", "NotDelivered");
	
	Result = StatusesCorrespondence[StatusAsString];
	Return ?(Result = Undefined, "Error", Result);
EndFunction

Function ConnectWebService()
	Return CommonUse.WSProxy(
		"",
		"", 
		"MTS_x0020_Communicator_x0020_M2M_x0020_XML_x0020_API", 
		"MTS_x0020_Communicator_x0020_M2M_x0020_XML_x0020_APISoap12", 
		"",
		"",
		60,
		False);
EndFunction

Function CalculateStringHashByAlgorythmMD5(Val String)
	DataHashing = New DataHashing(HashFunction.MD5);
	DataHashing.Append(String);
	Return StrReplace(DataHashing.HashSum, " ", "");
EndFunction

// Returns the list of permissions for sending the SMS with the help of all available providers.
//
// Returns:
//  Array.
//
Function permissions() Export
	Protocol = "HTTP";
	Address = "";
	Port = Undefined;
	Definition = NStr("en='Sending the SMS via MTS.';ru='Отправка SMS через МТС.'");
	
	permissions = New Array;
	permissions.Add(
		WorkInSafeMode.PermissionForWebsiteUse(Protocol, Address, Port, Definition)
	);
	
	Return permissions;
EndFunction

#EndRegion
