#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	For Each Record IN ThisObject Do
		
		If Record.DebugMode Then
			
			ExchangePlanID = CommonUse.MetadataObjectID(Metadata.ExchangePlans[Record.ExchangePlanName]);
			SecurityProfileName = WorkInSafeModeService.ExternalModuleConnectionMode(ExchangePlanID);
			
			If SecurityProfileName <> Undefined Then
				SetSafeMode(SecurityProfileName);
			EndIf;
			
			ThisIsFileBase = CommonUse.FileInfobase();
			
			If Record.ExportDebuggingMode Then
				
				ValidateExistenceOfFileExternalDataProcessors(Record.DataProcessorFileNameForExportDebugging, ThisIsFileBase, Cancel);
				
			EndIf;
			
			If Record.ImportDebuggingMode Then
				
				ValidateExistenceOfFileExternalDataProcessors(Record.DataProcessorFileNameForImportDebugging, ThisIsFileBase, Cancel);
				
			EndIf;
			
			If Record.DataExchangeLoggingMode Then
				
				CheckExchangeLogFileAvailability(Record.ExchangeProtocolFileName, Cancel);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure ValidateExistenceOfFileExternalDataProcessors(VerifiedFileName, ThisIsFileBase, Cancel)
	
	FileNameStructure = CommonUseClientServer.SplitFullFileName(VerifiedFileName);
	FileName = FileNameStructure.BaseName;
	CheckDirectoryName	 = FileNameStructure.Path;
	CheckDirectory = New File(CheckDirectoryName);
	FileOnDrive = New File(VerifiedFileName);
	DirectoryLocation = ? (ThisIsFileBase, NStr("en = 'on client'"), NStr("en = 'At server'"));
	
	If Not CheckDirectory.Exist() Then
		
		MessageString = NStr("en = 'Directory ""%1"" is not found %2.'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, CheckDirectoryName, DirectoryLocation);
		Cancel = True;
		
	ElsIf Not FileOnDrive.Exist() Then 
		
		MessageString = NStr("en = 'File of external data processor ""%1"" is not found %2.'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, VerifiedFileName, DirectoryLocation);
		Cancel = True;
		
	Else
		
		Return;
		
	EndIf;
	
	CommonUseClientServer.MessageToUser(MessageString,,,, Cancel);
	
EndProcedure

Procedure CheckExchangeLogFileAvailability(ExchangeProtocolFileName, Cancel)
	
	FileNameStructure = CommonUseClientServer.SplitFullFileName(ExchangeProtocolFileName);
	CheckDirectoryName = FileNameStructure.Path;
	CheckDirectory = New File(CheckDirectoryName);
	CheckFileName = "test.tmp";
	
	If Not CheckDirectory.Exist() Then
		
		MessageString = NStr("en = 'Directory of exchange protocol file ""%1"" is not found.'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, CheckDirectoryName);
		Cancel = True;
		
	ElsIf Not CreateVerificationFile(CheckDirectoryName, CheckFileName) Then
		
		MessageString = NStr("en = 'It was not succeeded to create the file in the exchange protocol folder: ""%1"".'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, CheckDirectoryName);
		Cancel = True;
		
	ElsIf Not DeleteCheckFile(CheckDirectoryName, CheckFileName) Then
		
		MessageString = NStr("en = 'It was not succeeded to delete the file in the exchange protocol folder: ""%1"".'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, CheckDirectoryName);
		Cancel = True;
		
	Else
		
		Return;
		
	EndIf;
	
	CommonUseClientServer.MessageToUser(MessageString,,,, Cancel);
	
EndProcedure

Function CreateVerificationFile(CheckDirectoryName, CheckFileName)
	
	TextDocument = New TextDocument;
	TextDocument.AddLine(NStr("en = 'Temporary checking file'"));
	
	Try
		TextDocument.Write(CheckDirectoryName + "/" + CheckFileName);
	Except
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

Function DeleteCheckFile(CheckDirectoryName, CheckFileName)
	
	Try
		DeleteFiles(CheckDirectoryName, CheckFileName);
	Except
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

#EndRegion

#EndIf