#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var ErrorMessageString Export;
Var ErrorMessageStringEL Export;

Var ErrorMessages; // Matching with the predefined errors messages of the data processors.
Var ObjectName;		// metadata object name

Var ExchangeMessageTemporaryFile; // exchange message temporary file for import/export data.
Var TemporaryDirectoryOfExchangeMessages; // Temporary directory for the exchange messages.

Var MessageSubject;		// template of the message subject
Var mBodyMessageIsSimple;	// Message body text with an attachment - file XML.
Var mBodyMessageIsCompressed;		// Message body text with an attachment - compressed file.
Var mBodyMessageIsBatched;	// Message body text with an attachment - compressed file, in which there is set of files.

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export service procedures and functions.

// Creates a temporary directory in the temporary files directory of the operating system user.
// 
// Parameters:
//  No.
// 
//  Returns:
//  Boolean - True - managed to execute a function, False - an error occurred.
// 
Function ExecuteActionsBeforeMessageProcessing() Export
	
	MessagesInitialization();
	
	Return CreateTemporaryDirectoryOfExchangeMessages();
	
EndFunction

// Sends the exchange message to the specified resource from the temporary exchange message directory.
// 
// Parameters:
//  No.
// 
//  Returns:
//  Boolean - True - managed to execute a function, False - an error occurred.
// 
Function SendMessage() Export
	
	MessagesInitialization();
	
	Try
		Result = SendExchangeMessage();
	Except
		Result = False;
	EndTry;
	
	Return Result;
	
EndFunction

// Receives an exchange message from the specified resource and puts it into the temporary exchange message directory.
// 
// Parameters:
//  No.
// 
//  Returns:
//  Boolean - True - managed to execute a function, False - an error occurred.
// 
Function GetMessage() Export
	
	MessagesInitialization();
	
	Try
		Result = GetExchangeMessage();
	Except
		Result = False;
	EndTry;
	
	Return Result;
	
EndFunction

// Deletes the temporary exchange message directory after executing data export or import.
// 
// Parameters:
//  No.
// 
//  Returns:
//  Boolean - True
//
Function ExecuteActionsAfterMessageProcessing() Export
	
	MessagesInitialization();
	
	DeleteTemporaryDirectoryOfExchangeMessages();
	
	Return True;
	
EndFunction

// Checking whether the specified resource contains an exchange message.
// 
// Parameters:
//  No.
// 
//  Returns:
//  Boolean - True - there is an exchange message on the specified resource; False - no.
//
Function ExchangeMessageFileExists() Export
	
	MessagesInitialization();
	
	ColumnArray = New Array;
	ColumnArray.Add("Subject");
	
	ImportParameters = New Structure;
	ImportParameters.Insert("Columns", ColumnArray);
	ImportParameters.Insert("GetHeaders", True);
	
	Try
		MessageSet = EmailOperations.ImportEMails(EMAILAccount, ImportParameters);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetMessageAboutError(103);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	For Each Email IN MessageSet Do
		
		If Upper(TrimAll(Email.Subject)) = Upper(TrimAll(MessageSubject)) Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

// Initializes the data processor properties with initial values and constants.
//
// Parameters:
//  No.
// 
Procedure Initialization() Export
	
	MessagesInitialization();
	
	MessageSubject = "Exchange message (%1)"; // String can not be localized.
	MessageSubject = StringFunctionsClientServer.SubstituteParametersInString(MessageSubject, MessageFileTemplateName);
	
	mBodyMessageIsSimple	= NStr("en='Data exchange message';ru='Сообщение обмена данными'");
	mBodyMessageIsCompressed	= NStr("en='Compressed data exchange message';ru='Сжатое сообщение обмена данными'");
	mBodyMessageIsBatched	= NStr("en='Package message of the data exchange';ru='Пакетное сообщение обмена данными'");
	
EndProcedure

// Checks whether the connection to the specified resource can be established.
// 
// Parameters:
//  No.
// 
//  Returns:
//  Boolean - True - connection can be established; False - no.
//
Function ConnectionIsDone() Export
	
	MessagesInitialization();
	
	If Not ValueIsFilled(EMAILAccount) Then
		GetMessageAboutError(101);
		Return False;
	EndIf;
	
	ErrorInfo = "";
	AdditionalMessage = "";
	EmailOperationsService.CheckPossibilityOfSendingAndReceivingOfEmails(EMAILAccount, Undefined, ErrorInfo, AdditionalMessage);
	
	If ValueIsFilled(ErrorInfo) Then
		GetMessageAboutError(107);
		SupplementErrorMessage(ErrorInfo);
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Functions-properties

// Time of the exchange message file change.
//
// Returns:
//  String - time of the exchange message file change.
//
Function ExchangeMessageFileDate() Export
	
	Result = Undefined;
	
	If TypeOf(ExchangeMessageTemporaryFile) = Type("File") Then
		
		If ExchangeMessageTemporaryFile.Exist() Then
			
			Result = ExchangeMessageTemporaryFile.GetModificationTime();
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Full name of the exchange message file.
//
// Returns:
//  String - full name of the exchange message file.
//
Function ExchangeMessageFileName() Export
	
	Name = "";
	
	If TypeOf(ExchangeMessageTemporaryFile) = Type("File") Then
		
		Name = ExchangeMessageTemporaryFile.FullName;
		
	EndIf;
	
	Return Name;
	
EndFunction

// Full name of the exchange message directory.
//
// Returns:
//  String - full name of the exchange message directory.
//
Function ExchangeMessageDirectoryName() Export
	
	Name = "";
	
	If TypeOf(TemporaryDirectoryOfExchangeMessages) = Type("File") Then
		
		Name = TemporaryDirectoryOfExchangeMessages.FullName;
		
	EndIf;
	
	Return Name;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Local service procedures and functions.

Function CreateTemporaryDirectoryOfExchangeMessages()
	
	// Create the temporary directory for the exchange messages.
	Try
		TempDirectoryName = DataExchangeServer.CreateTemporaryDirectoryOfExchangeMessages();
	Except
		GetMessageAboutError(4);
		SupplementErrorMessage(BriefErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	TemporaryDirectoryOfExchangeMessages = New File(TempDirectoryName);
	
	MessageFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName(), MessageFileTemplateName + ".xml");
	
	ExchangeMessageTemporaryFile = New File(MessageFileName);
	
	Return True;
EndFunction

Function DeleteTemporaryDirectoryOfExchangeMessages()
	
	Try
		If Not IsBlankString(ExchangeMessageDirectoryName()) Then
			DeleteFiles(ExchangeMessageDirectoryName());
			TemporaryDirectoryOfExchangeMessages = Undefined;
		EndIf;
	Except
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

Function SendExchangeMessage()
	
	Result = True;
	
	Extension = ?(CompressOutgoingMessageFile(), ".zip", ".xml");
	
	OutgoingMessageFileName = MessageFileTemplateName + Extension;
	
	If CompressOutgoingMessageFile() Then
		
		// Getting the name for the temporary archive file.
		ArchiveTempFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName(), MessageFileTemplateName + ".zip");
		
		Try
			
			Archiver = New ZipFileWriter(ArchiveTempFileName, ExchangeMessageArchivePassword, NStr("en='Exchange message file';ru='Файл сообщения обмена'"));
			Archiver.Add(ExchangeMessageFileName());
			Archiver.Write();
			
		Except
			
			Result = False;
			GetMessageAboutError(3);
			SupplementErrorMessage(BriefErrorDescription(ErrorInfo()));
			
		EndTry;
		
		Archiver = Undefined;
		
		If Result Then
			
			// Check on the maximum allowable size of the exchange message.
			If DataExchangeServer.ExchangeMessageSizeExceedsValidSize(ArchiveTempFileName, MaximumValidMessageSize()) Then
				GetMessageAboutError(108);
				Result = False;
			EndIf;
			
		EndIf;
		
		If Result Then
			
			Result = SendMessageByEMail(
									mBodyMessageIsCompressed,
									OutgoingMessageFileName,
									ArchiveTempFileName);
			
		EndIf;
		
	Else
		
		If Result Then
			
			// Check on the maximum allowable size of the exchange message.
			If DataExchangeServer.ExchangeMessageSizeExceedsValidSize(ExchangeMessageFileName(), MaximumValidMessageSize()) Then
				GetMessageAboutError(108);
				Result = False;
			EndIf;
			
		EndIf;
		
		If Result Then
			
			Result = SendMessageByEMail(
									mBodyMessageIsSimple,
									OutgoingMessageFileName,
									ExchangeMessageFileName());
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function GetExchangeMessage()
	
	ExchangeMessageTable = New ValueTable;
	ExchangeMessageTable.Columns.Add("ID", New TypeDescription("Array"));
	ExchangeMessageTable.Columns.Add("PostDating", New TypeDescription("Date"));
	
	ColumnArray = New Array;
	
	ColumnArray.Add("ID");
	ColumnArray.Add("PostDating");
	ColumnArray.Add("Subject");
	
	ImportParameters = New Structure;
	ImportParameters.Insert("Columns", ColumnArray);
	ImportParameters.Insert("GetHeaders", True);
	
	Try
		MessageSet = EmailOperations.ImportEMails(EMAILAccount, ImportParameters);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetMessageAboutError(103);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	For Each Email IN MessageSet Do
		
		If Upper(TrimAll(Email.Subject)) <> Upper(TrimAll(MessageSubject)) Then
			Continue;
		EndIf;
		
		NewRow = ExchangeMessageTable.Add();
		FillPropertyValues(NewRow, Email);
		
	EndDo;
	
	If ExchangeMessageTable.Count() = 0 Then
		
		GetMessageAboutError(104);
		
		MessageString = NStr("en='Emails with title ""%1"" are not found';ru='Не обнаружены письма с заголовком: ""%1""'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, MessageSubject);
		SupplementErrorMessage(MessageString);
		
		Return False;
		
	Else
		
		ExchangeMessageTable.Sort("PostDating Desc");
		
		ColumnArray = New Array;
		ColumnArray.Add("Attachments");
		
		ImportParameters = New Structure;
		ImportParameters.Insert("Columns", ColumnArray);
		ImportParameters.Insert("HeadersIDs", ExchangeMessageTable[0].ID);
		
		Try
			MessageSet = EmailOperations.ImportEMails(EMAILAccount, ImportParameters);
		Except
			ErrorText = DetailErrorDescription(ErrorInfo());
			GetMessageAboutError(105);
			SupplementErrorMessage(ErrorText);
			Return False;
		EndTry;
		
		BinaryData = MessageSet[0].Attachments.Get(MessageFileTemplateName+".zip");
		
		If BinaryData <> Undefined Then
			FilePacked = True;
		Else
			BinaryData = MessageSet[0].Attachments.Get(MessageFileTemplateName+".xml");
			FilePacked = False;
		EndIf;
			
		If BinaryData = Undefined Then
			GetMessageAboutError(109);
			Return False;
		EndIf;
		
		If FilePacked Then
			
			// Getting the name for the temporary archive file.
			ArchiveTempFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName(), MessageFileTemplateName + ".zip");
			
			Try
				BinaryData.Write(ArchiveTempFileName);
			Except
				ErrorText = DetailErrorDescription(ErrorInfo());
				GetMessageAboutError(106);
				SupplementErrorMessage(ErrorText);
				Return False;
			EndTry;
			
			// Unpacking the temporary archive file.
			UnpackedSuccessfully = DataExchangeServer.UnpackZIPFile(ArchiveTempFileName, ExchangeMessageDirectoryName(), ExchangeMessageArchivePassword);
			
			If Not UnpackedSuccessfully Then
				GetMessageAboutError(2);
				Return False;
			EndIf;
			
			// Check whether there is a message file.
			File = New File(ExchangeMessageFileName());
			
			If Not File.Exist() Then
				
				GetMessageAboutError(5);
				Return False;
				
			EndIf;
			
		Else
			
			Try
				BinaryData.Write(ExchangeMessageFileName());
			Except
				ErrorText = DetailErrorDescription(ErrorInfo());
				GetMessageAboutError(106);
				SupplementErrorMessage(ErrorText);
				Return False;
			EndTry;
			
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

Procedure GetMessageAboutError(MessageNo)
	
	SetStatusBarMessageAboutError(ErrorMessages[MessageNo]);
	
EndProcedure

Procedure SetStatusBarMessageAboutError(Val Message)
	
	If Message = Undefined Then
		Message = NStr("en='Internal error';ru='Внутренняя ошибка'");
	EndIf;
	
	ErrorMessageString   = Message;
	ErrorMessageStringEL = ObjectName + ": " + Message;
	
EndProcedure

Procedure SupplementErrorMessage(Message)
	
	ErrorMessageStringEL = ErrorMessageStringEL + Chars.LF + Message;
	
EndProcedure

// Overridable function returns the
// maximum allowable message size that can be sent.
// 
Function MaximumValidMessageSize()
	
	Return EMAILMaximumValidMessageSize;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Functions-properties

// Flag of the outgoing message file compression.
// 
Function CompressOutgoingMessageFile()
	
	Return EMAILCompressOutgoingMessageFile;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Initialization

Procedure MessagesInitialization()
	
	ErrorMessageString   = "";
	ErrorMessageStringEL = "";
	
EndProcedure

Procedure ErrorMessagesInitialization()
	
	ErrorMessages = New Map;
	
	// Common error codes
	ErrorMessages.Insert(001, NStr("en='Exchange emails are not found.';ru='Не обнаружены сообщения обмена.'"));
	ErrorMessages.Insert(002, NStr("en='An error occurred when unpacking a compressed message file.';ru='Ошибка при распаковке сжатого файла сообщения.'"));
	ErrorMessages.Insert(003, NStr("en='An error occurred when compressing the exchange message file.';ru='Ошибка при сжатии файла сообщения обмена.'"));
	ErrorMessages.Insert(004, NStr("ru = ""Error when creating temporary directory'."));
	ErrorMessages.Insert(005, NStr("en='Archive does not include exchange message file.';ru='Архив не содержит файл сообщения обмена.'"));
	ErrorMessages.Insert(006, NStr("en='Exchange message was not sent: allowed message size exceeded.';ru='Сообщение обмена не отправлено: превышен допустимый размер сообщения.'"));
	
	// Errors codes, that are dependent on the transport kind.
	ErrorMessages.Insert(101, NStr("en='Initialization error: email account of the exchange message transport is not specified.';ru='Ошибка инициализации: не указана учетная запись электронной почты транспорта сообщений обмена.'"));
	ErrorMessages.Insert(102, NStr("en='An error occurred when sending the email.';ru='Ошибка при отправке сообщения электронной почты.'"));
	ErrorMessages.Insert(103, NStr("en='An error occurred when getting message titles from the email server.';ru='Ошибка при получении заголовков сообщений с сервера электронной почты.'"));
	ErrorMessages.Insert(104, NStr("en='Exchange emails are not found on email server.';ru='Не обнаружены сообщения обмена на почтовом сервере.'"));
	ErrorMessages.Insert(105, NStr("en='An error occurred when receiving a message from the email server.';ru='Ошибка при получении сообщения с сервера электронной почты.'"));
	ErrorMessages.Insert(106, NStr("en='An error occurred when writing the exchange message file to the disk.';ru='Ошибка при записи файла сообщения обмена на диск.'"));
	ErrorMessages.Insert(107, NStr("en='Account parameter check is completed with errors.';ru='Проверка параметров учетной записи завершилась с ошибками.'"));
	ErrorMessages.Insert(108, NStr("en='Exchange message size exceeds the allowable limit.';ru='Превышен допустимый размер сообщения обмена.'"));
	ErrorMessages.Insert(109, NStr("en='Error: a file with message is not found in the mail message.';ru='Ошибка: в почтовом сообщении не найден файл с сообщением.'"));
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Working with E-MAIL

Function SendMessageByEMail(Body, OutgoingMessageFileName, PathToFile)
	
	Attachments = New Map;
	Attachments.Insert(OutgoingMessageFileName,
						New BinaryData(PathToFile));
	
	MessageParameters = New Structure;
	MessageParameters.Insert("Whom", EMAILAccount.EmailAddress);
	MessageParameters.Insert("Subject", MessageSubject);
	MessageParameters.Insert("Body", Body);
	MessageParameters.Insert("Attachments", Attachments);
	
	Try
		EmailOperations.SendE_Mail(EMAILAccount, MessageParameters);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetMessageAboutError(102);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Operators of the main application.

MessagesInitialization();
ErrorMessagesInitialization();

TemporaryDirectoryOfExchangeMessages = Undefined;
ExchangeMessageTemporaryFile    = Undefined;

ObjectName = NStr("en='Data processor: %1';ru='Обработка: %1'");
ObjectName = StringFunctionsClientServer.SubstituteParametersInString(ObjectName, Metadata().Name);

#EndRegion

#EndIf