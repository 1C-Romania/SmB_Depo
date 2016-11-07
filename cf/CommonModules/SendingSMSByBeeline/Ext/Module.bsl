////////////////////////////////////////////////////////////////////////////////
// Subsystem "Sending SMS"
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Sends SMS via the MTS web service, returns message identifier.
//
// Parameters:
//  RecipientNumbers - Array - recipient numbers in the +7XXXXXXXXXX format;
//  Text 			  - String - message text no longer than 480 characters;
//  SenderName  - String - name of the sender that will be displayed instead of the incoming SMS number;
//  Login			  - String - sms sending service user login;
//  Password		 - String - sms sending service user password.
//
// Returns:
//  Structure: SentMessages      - Array of structures: SenderNumber.
//                                                  MessageID.
//             ErrorDescription  - String - user's view of an error,
//                                          if the row is empty, then there is no error.
Function SendSMS(RecipientNumbers, Text, SenderName, Login, Password) Export
	
	Result = New Structure("SentMessages,ErrorDescription", New Array, "");
	
	// Preparation of the recipients string.
	RecipientsString = RecipientsArrayAsString(RecipientNumbers);
	
	// Check on filling the mandatory parameters.
	If IsBlankString(RecipientsString) Or IsBlankString(Text) Then
		Result.ErrorDescription = NStr("en='Incorrect message parameters';ru='Неверные параметры сообщения'");
		Return Result;
	EndIf;
	
	// Preparation of the query parameters.
	QueryParameters = New Structure;
	QueryParameters.Insert("user",	 Login);
	QueryParameters.Insert("pass",	 Password);
	QueryParameters.Insert("gzip",	 "none");
	QueryParameters.Insert("action",	 "post_sms");
	QueryParameters.Insert("message", Text);
	QueryParameters.Insert("target",	 RecipientsString);
	QueryParameters.Insert("sender",	 SenderName);
	
	// query sending
	FileNameResponse = ExecuteQuery(QueryParameters);
	If IsBlankString(FileNameResponse) Then
		Result.ErrorDescription = Result.ErrorDescription + NStr("en='Connection is not set';ru='Соединение не установлено'");
		Return Result;
	EndIf;		
	
	// Processing of the query result (receiving the message identifiers).
	AnswerStructure = New XMLReader;
	AnswerStructure.OpenFile(FileNameResponse);
	ErrorDescription = "";
	While AnswerStructure.Read() Do 
		If AnswerStructure.NodeType = XMLNodeType.StartElement Then
			If AnswerStructure.Name = "sms" Then 
				MessageID = "";
				RecipientNumber = "";
				While AnswerStructure.ReadAttribute() Do 
					If AnswerStructure.Name = "id" Then 
						MessageID = AnswerStructure.Value;
					ElsIf AnswerStructure.Name = "phone" Then
						RecipientNumber = AnswerStructure.Value;
					EndIf;
				EndDo;
				If Not IsBlankString(RecipientNumber) Then
					SentMessage = New Structure("RecipientNumber,MessageID",
														 RecipientNumber,MessageID);
					Result.SentMessages.Add(SentMessage);
				EndIf;
			ElsIf AnswerStructure.Name = "error" Then
				AnswerStructure.Read();
				ErrorDescription = ErrorDescription + AnswerStructure.Value + Chars.LF;
			EndIf;
		EndIf;
	EndDo;
	AnswerStructure.Close();
	DeleteFiles(FileNameResponse);
	
	Result.ErrorDescription = TrimR(ErrorDescription);
	
	Return Result;
	
EndFunction

// Returns the text presentation of the message delivery status.
//
// Parameters:
//  MessageID - String - ID assigned when sending the sms;
//  Login			- String - sms sending service user login;
//  Password	- String - sms sending service user password.
//
// Returns:
//  String - Delivery status See the description of the SendingSMS function.DeliveryStatus.
Function DeliveryStatus(MessageID, Login, Password) Export
	
	// Preparation of the query parameters.
	QueryParameters = New Structure;
	QueryParameters.Insert("user",	 Login);
	QueryParameters.Insert("pass",	 Password);
	QueryParameters.Insert("gzip",	 "none");
	QueryParameters.Insert("action",	 "status");
	QueryParameters.Insert("sms_id",	 MessageID);
	
	// query sending
	FileNameResponse = ExecuteQuery(QueryParameters);
	If IsBlankString(FileNameResponse) Then
		Return "Error";
	EndIf;
	
	// Processing of the query result.
	SMSSTS_CODE = "";
	CurrentSMS_ID = "";
	AnswerStructure = New XMLReader;
	AnswerStructure.OpenFile(FileNameResponse);
	While AnswerStructure.Read() Do 
		If AnswerStructure.NodeType = XMLNodeType.StartElement Then
			If AnswerStructure.Name = "MESSAGE" Then 
				While AnswerStructure.ReadAttribute() Do 
					If AnswerStructure.Name = "SMS_ID" Then 
						CurrentSMS_ID = AnswerStructure.Value;
					EndIf;
				EndDo;
			ElsIf AnswerStructure.Name = "SMSSTC_CODE" AND MessageID = CurrentSMS_ID Then
				AnswerStructure.Read();
				SMSSTS_CODE = AnswerStructure.Value;
			EndIf;
		EndIf;
	EndDo;
	AnswerStructure.Close();
	DeleteFiles(FileNameResponse);
	
	Return SMSDeliveryStatus(SMSSTS_CODE); 
	
EndFunction

Function SMSDeliveryStatus(StatusAsString)
	StatusesCorrespondence = New Map;
	StatusesCorrespondence.Insert("", "HaveNotSent");
	StatusesCorrespondence.Insert("queued", "HaveNotSent");
	StatusesCorrespondence.Insert("wait", "Dispatched");
	StatusesCorrespondence.Insert("accepted", "Sent");
	StatusesCorrespondence.Insert("delivered", "Delivered");
	StatusesCorrespondence.Insert("failed", "NotDelivered");
	
	Result = StatusesCorrespondence[Lower(StatusAsString)];
	Return ?(Result = Undefined, "Error", Result);
EndFunction

Function ExecuteQuery(QueryParameters)
	
	Result = "";
	
	QueryFileName = GenerateFileForPOSTQuery(QueryParameters);
	FileNameResponse = GetTempFileName("xml");
	
	// generating the header
	Title = New Map;
	Title.Insert("Content-Type", "application/x-www-form-urlencoded");
	Title.Insert("Content-Length", XMLString(FileSize(QueryFileName)));
	
	// Sending query and receiving response.
	Try
		Join = New HTTPConnection("beeline.amega-inform.en", , , , GetFilesFromInternetClientServer.GetProxy("http"), 60);
		Join.Post(QueryFileName, "/sendsms/", FileNameResponse, Title);
		Result = FileNameResponse;
	Except
		WriteLogEvent(
			NStr("en='SMS sending';ru='Отправка SMS'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,
			,
			,
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	DeleteFiles(QueryFileName);
	
	Return Result;
	
EndFunction

Function GenerateFileForPOSTQuery(QueryParameters)
	QueryString = "";
	For Each Parameter IN QueryParameters Do
		If Not IsBlankString(QueryString) Then
			QueryString = QueryString + "&";
		EndIf;
		QueryString = QueryString + Parameter.Key + "=" + EncodeString(Parameter.Value, StringEncodingMethod.URLEncoding);
	EndDo;
	
	QueryFileName = GetTempFileName("txt");
	
	QueryFile = New TextWriter(QueryFileName, TextEncoding.ANSI);
	QueryFile.Write(QueryString);
	QueryFile.Close();
	
	Return QueryFileName;
EndFunction

Function FileSize(FileName)
    File = New File(FileName);
    Return File.Size();
EndFunction

Function RecipientsArrayAsString(Array)
	Result = "";
	For Each Item IN Array Do
		Number = FormatNumber(Item);
		If Not IsBlankString(Number) Then 
			If Not IsBlankString(Result) Then
				Result = Result + ",";
			EndIf;
			Result = Result + Number;
		EndIf;
	EndDo;
	Return Result;
EndFunction

Function FormatNumber(Number)
	Result = "";
	AllowedChars = "+1234567890";
	For Position = 1 To StrLen(Number) Do
		Char = Mid(Number,Position,1);
		If Find(AllowedChars, Char) > 0 Then
			Result = Result + Char;
		EndIf;
	EndDo;
	Return Result;	
EndFunction

// Returns the list of permissions for sending the SMS with the help of all available providers.
//
// Returns:
//  Array.
//
Function permissions() Export
	
	Protocol = "HTTP";
	Address = "beeline.amega-inform.en";
	Port = Undefined;
	Definition = NStr("en='Sending SMS by Beeline.';ru='Отправка SMS через Билайн.'");
	
	permissions = New Array;
	permissions.Add(
		WorkInSafeMode.PermissionForWebsiteUse(Protocol, Address, Port, Definition));
	
	Return permissions;
EndFunction

#EndRegion
