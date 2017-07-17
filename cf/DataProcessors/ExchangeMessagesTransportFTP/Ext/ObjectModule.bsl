#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var ErrorMessageString Export;
Var ErrorMessageStringEL Export;

Var ErrorMessages; // Matching with the predefined errors messages of the data processors.
Var ObjectName;		// metadata object name
Var FTPServerName;		// FTP server address - name or ip address.
Var FolderAtFTPServer;// Directory on the server for storage/receiving exchange message.

Var ExchangeMessageTemporaryFile; // Temporary file of exchange message to import/export data.
Var TemporaryDirectoryOfExchangeMessages; // Temporary directory for the exchange messages.

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
	
	Try
		FTPConnection = GetFTPConnection();
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetMessageAboutError(102);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Try
		FoundFileArray = FTPConnection.FindFiles(FolderAtFTPServer, MessageFileTemplateName + ".*", False);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetMessageAboutError(104);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Return FoundFileArray.Count() > 0;
	
EndFunction

// Initializes the data processor properties with initial values and constants.
//
// Parameters:
//  No.
// 
Procedure Initialization() Export
	
	MessagesInitialization();
	
	ServerNameAndDirectoryAtServer = SplitFTPResourceForServerAndDirectory(TrimAll(FTPConnectionPath));
	FTPServerName			= ServerNameAndDirectoryAtServer.ServerName;
	FolderAtFTPServer	= ServerNameAndDirectoryAtServer.DirectoryName;
	
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
	
	// Return value of the function.
	Result = True;
	
	MessagesInitialization();
	
	If IsBlankString(FTPConnectionPath) Then
		
		GetMessageAboutError(101);
		Return False;
		
	EndIf;
	
	// Create file in temporary directory.
	TempConnectionCheckFileName = GetTempFileName("tmp");
	FileNameForTarget = DataExchangeServer.FileNameOfVerificationOfConnection();
	
	TextWriter = New TextWriter(TempConnectionCheckFileName);
	TextWriter.WriteLine(FileNameForTarget);
	TextWriter.Close();
	
	// Copy file on the external resource from the temporary directory.
	Result = RunCopyingOfFileToFTPServer(TempConnectionCheckFileName, FileNameForTarget);
	
	// Delete file on an external resource.
	If Result Then
		
		Result = RunFileDeleteAtFTPServer(FileNameForTarget, True);
		
	EndIf;
	
	// Delete file from the temporary directory.
	DeleteFiles(TempConnectionCheckFileName);
	
	Return Result;
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Functions-properties

// Function-property: time of the exchange message file change.
//
// Returns:
//  Date - time of the exchange message file change.
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

// Function-property: full name of the exchange message file.
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

// Function-property: full name of the exchange message directory.
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
			
			// Copy the file archive on the FTP server to exchange directory with information.
			If Not RunCopyingOfFileToFTPServer(ArchiveTempFileName, OutgoingMessageFileName) Then
				Result = False;
			EndIf;
			
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
			
			// Copy the file archive on the FTP server to exchange directory with information.
			If Not RunCopyingOfFileToFTPServer(ExchangeMessageFileName(), OutgoingMessageFileName) Then
				Result = False;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function GetExchangeMessage()
	
	ExchangeMessageFileTable = New ValueTable;
	ExchangeMessageFileTable.Columns.Add("File");
	ExchangeMessageFileTable.Columns.Add("ModifiedAt");
	
	Try
		FTPConnection = GetFTPConnection();
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetMessageAboutError(102);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Try
		FoundFileArray = FTPConnection.FindFiles(FolderAtFTPServer, MessageFileTemplateName + ".*", False);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetMessageAboutError(104);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	For Each CurrentFile IN FoundFileArray Do
		
		// Check the needed extension.
		If ((Upper(CurrentFile.Extension) <> ".ZIP")
			AND (Upper(CurrentFile.Extension) <> ".XML")) Then
			
			Continue;
			
		// Checking that it is a file, not a directory.
		ElsIf (CurrentFile.IsFile() = False) Then
			
			Continue;
			
		// Checking that the file size is greater than 0.
		ElsIf (CurrentFile.Size() = 0) Then
			
			Continue;
			
		EndIf;
		
		// File is the required exchange message; Adding the file to the table.
		TableRow = ExchangeMessageFileTable.Add();
		TableRow.File           = CurrentFile;
		TableRow.ModifiedAt = CurrentFile.GetModificationTime();
		
	EndDo;
	
	If ExchangeMessageFileTable.Count() = 0 Then
		
		GetMessageAboutError(1);
		
		MessageString = NStr("en='Data exchange directory on server: ""%1""';ru='Каталог обмена информацией на сервере: ""%1""'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, FolderAtFTPServer);
		SupplementErrorMessage(MessageString);
		
		MessageString = NStr("en='Exchange message file name: ""%1"" or ""%2""';ru='Имя файла сообщения обмена: ""%1"" или ""%2""'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, MessageFileTemplateName + ".xml", MessageFileTemplateName + ".zip");
		SupplementErrorMessage(MessageString);
		
		Return False;
		
	Else
		
		ExchangeMessageFileTable.Sort("ModifiedAt Desc");
		
		// get the table of the "fresh" the exchange message file.
		IncomingMessageFile = ExchangeMessageFileTable[0].File;
		
		FilePacked = (Upper(IncomingMessageFile.Extension) = ".ZIP");
		
		If FilePacked Then
			
			// Getting the name for the temporary archive file.
			ArchiveTempFileName = CommonUseClientServer.GetFullFileName(ExchangeMessageDirectoryName(), MessageFileTemplateName + ".zip");
			
			Try
				FTPConnection.Get(IncomingMessageFile.FullName, ArchiveTempFileName);
			Except
				ErrorText = DetailErrorDescription(ErrorInfo());
				GetMessageAboutError(105);
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
				FTPConnection.Get(IncomingMessageFile.FullName, ExchangeMessageFileName());
			Except
				ErrorText = DetailErrorDescription(ErrorInfo());
				GetMessageAboutError(105);
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
	
	Return FTPConnectionMaximumValidMessageSize;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Functions-properties

Function CompressOutgoingMessageFile()
	
	Return FTPCompressOutgoingMessageFile;
	
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
	ErrorMessages.Insert(001, NStr("en='Information exchange directory does not contain a message file with data.';ru='В каталоге обмена информацией не был обнаружен файл сообщения с данными.'"));
	ErrorMessages.Insert(002, NStr("en='An error occurred when unpacking a compressed message file.';ru='Ошибка при распаковке сжатого файла сообщения.'"));
	ErrorMessages.Insert(003, NStr("en='An error occurred when compressing the exchange message file.';ru='Ошибка при сжатии файла сообщения обмена.'"));
	ErrorMessages.Insert(004, NStr("en='An error occurred when creating a temporary directory.';ru='Ошибка при создании временного каталога.'"));
	ErrorMessages.Insert(005, NStr("en='Archive does not include exchange message file.';ru='Архив не содержит файл сообщения обмена.'"));
	
	// Errors codes, that are dependent on the transport kind.
	ErrorMessages.Insert(101, NStr("en='Path on the server is not specified.';ru='Не задан путь на сервере.'"));
	ErrorMessages.Insert(102, NStr("en='An error occurred when initializing connection to the FTP server.';ru='Ошибка инициализации подключения к FTP-серверу.'"));
	ErrorMessages.Insert(103, NStr("en='An error occurred when connecting to the FTP server, check the path  correctness and access rights to the resource.';ru='Ошибка подключения к FTP-серверу, проверьте правильность задания пути и права доступа к ресурсу.'"));
	ErrorMessages.Insert(104, NStr("en='An error occurred when searching for files on FTP server.';ru='Ошибка при поиске файлов на FTP-сервере.'"));
	ErrorMessages.Insert(105, NStr("en='An error occurred when receiving the file from FTP server.';ru='Ошибка при получении файла с FTP-сервера.'"));
	ErrorMessages.Insert(106, NStr("en='An error occurred when removing file on FTP server, check access rights to the resource.';ru='Ошибка удаления файла на FTP-сервере, проверьте права доступа к ресурсу.'"));
	
	ErrorMessages.Insert(108, NStr("en='Exchange message size exceeds the allowable limit.';ru='Превышен допустимый размер сообщения обмена.'"));
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Work with FTP

Function GetFTPConnection()
	
	FTPSettings = DataExchangeServer.FTPConnectionSettings();
	FTPSettings.Server               = FTPServerName;
	FTPSettings.Port                 = FTPConnectionPort;
	FTPSettings.UserName             = FTPConnectionUser;
	FTPSettings.UserPassword         = FTPConnectionPassword;
	FTPSettings.PassiveConnection    = FTPConnectionPassiveConnection;
	FTPSettings.SecureConnection     = DataExchangeServer.SecureConnection(FTPConnectionPath);
	
	Return DataExchangeServer.FTPConnection(FTPSettings);
	
EndFunction

Function RunCopyingOfFileToFTPServer(Val SourceFileName, TargetFileName)
	
	Var DirectoryAtServer;
	
	ServerAndDirectoryAtServer = SplitFTPResourceForServerAndDirectory(TrimAll(FTPConnectionPath));
	DirectoryAtServer = ServerAndDirectoryAtServer.DirectoryName;
	
	Try
		FTPConnection = GetFTPConnection();
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetMessageAboutError(102);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Try
		FTPConnection.Write(SourceFileName, DirectoryAtServer + TargetFileName);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetMessageAboutError(103);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Try
		FilesArray = FTPConnection.FindFiles(DirectoryAtServer, TargetFileName, False);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetMessageAboutError(104);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Return FilesArray.Count() > 0;
	
EndFunction

Function RunFileDeleteAtFTPServer(Val FileName, ConnectionVerification = False)
	
	Var DirectoryAtServer;
	
	ServerAndDirectoryAtServer = SplitFTPResourceForServerAndDirectory(TrimAll(FTPConnectionPath));
	DirectoryAtServer = ServerAndDirectoryAtServer.DirectoryName;
	
	Try
		FTPConnection = GetFTPConnection();
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetMessageAboutError(102);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Try
		FTPConnection.Delete(DirectoryAtServer + FileName);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetMessageAboutError(106);
		SupplementErrorMessage(ErrorText);
		
		If ConnectionVerification Then
			
			ErrorInfo = NStr("en='Failed to check connection by test file ""%1"".
		|Perhaps, the specified directory does not exist or is not available.
		|It is also recommended to see the FTP-server documentation to set up the support of the Cyrillic names files.';ru='Не удалось проверить подключение с помощью тестового файла ""%1"".
		|Возможно, заданный каталог не существует или не доступен.
		|Рекомендуется также обратиться к документации по FTP-серверу для настройки поддержки имен файлов с кириллицей.'");
			ErrorInfo = StringFunctionsClientServer.SubstituteParametersInString(ErrorInfo, DataExchangeServer.FileNameOfVerificationOfConnection());
			SupplementErrorMessage(ErrorInfo);
			
		EndIf;
		
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

Function SplitFTPResourceForServerAndDirectory(Val FullPath)
	
	Result = New Structure("ServerName, DirectoryName");
	
	FTPParameters = DataExchangeServer.FTPServerNameAndPath(FullPath);
	
	Result.ServerName  = FTPParameters.Server;
	Result.DirectoryName = FTPParameters.Path;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Operators of the main application.

MessagesInitialization();
ErrorMessagesInitialization();

TemporaryDirectoryOfExchangeMessages = Undefined;
ExchangeMessageTemporaryFile    = Undefined;

FTPServerName       = Undefined;
FolderAtFTPServer = Undefined;

ObjectName = NStr("en='Data processor: %1';ru='Обработка: %1'");
ObjectName = StringFunctionsClientServer.SubstituteParametersInString(ObjectName, Metadata().Name);

#EndRegion

#EndIf